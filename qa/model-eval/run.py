#!/usr/bin/env python3
"""Run the multilingual corpus against local models served by LM Studio.

Usage:  python3 run.py MODEL [MODEL ...]
Needs:  LM Studio with its local server on port 1234 and the `lms` CLI.
Writes: results/<model>.json   raw outputs, timings, mechanical checks
        results/by-language/<lang>.md   side-by-side outputs for human review
"""
import json, os, re, secrets, subprocess, sys, time, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
URL = "http://localhost:1234/v1/chat/completions"
LMS = os.path.expanduser("~/.lmstudio/bin/lms")
THINK_VARIANTS = [
    ("default", {}),
    ("enable_thinking=false", {"chat_template_kwargs": {"enable_thinking": False}}),
]


def read(name):
    with open(os.path.join(HERE, "prompts", name), encoding="utf-8") as f:
        return f.read().strip()


def build_messages(item):
    """One compact system paragraph, text as the user turn.

    Random delimiter markers around the text were tried first (design v3 §6.2) and dropped:
    with gemma-4-e4b they pushed a 0.8 s correction to 9-19 s of thinking.
    """
    if item["op"] == "translate":
        system = read("translate.txt").replace("{TARGET}", item["target"])
    else:
        task = read(item["op"] + ".txt").replace("{TONE}", item.get("tone", ""))
        system = task + " " + read("_common.txt")
    system = system.replace("{PROTECTED}", "")
    return [{"role": "system", "content": system},
            {"role": "user", "content": item["text"]}], ()


def call(model, messages, extra, max_tokens=None):
    # No max_tokens by default: thinking shares the budget, and at 1024 the 12B model
    # returned an empty answer for 14 of 41 items (docs/MODELS.md).
    body = {"model": model, "messages": messages, "temperature": 0.2, "stream": True}
    if max_tokens:
        body["max_tokens"] = max_tokens
    body.update(extra)
    req = urllib.request.Request(URL, json.dumps(body).encode(), {"Content-Type": "application/json"})
    start = time.time()
    first = None
    content, reasoning, finish = [], [], None
    with urllib.request.urlopen(req, timeout=300) as resp:
        for raw in resp:
            line = raw.decode("utf-8", "replace").strip()
            if not line.startswith("data:"):
                continue
            data = line[5:].strip()
            if data == "[DONE]":
                break
            try:
                choice = json.loads(data)["choices"][0]
            except (ValueError, KeyError, IndexError):
                continue
            delta = choice.get("delta", {})
            if delta.get("content"):
                if first is None:
                    first = time.time() - start
                content.append(delta["content"])
            r = delta.get("reasoning_content") or delta.get("reasoning")
            if r:
                reasoning.append(r)
            finish = choice.get("finish_reason") or finish
    return {"raw": "".join(content), "reasoning_chars": len("".join(reasoning)),
            "first_token_s": round(first, 2) if first is not None else None,
            "total_s": round(time.time() - start, 2), "finish": finish}


def clean(raw, markers, original):
    """Design §6.3: drop thinking, echoed markers, and quotes the original did not have."""
    out = re.sub(r"<think>.*?</think>", "", raw, flags=re.S)
    for m in markers:
        out = out.replace(m, "")
    out = out.strip()
    pairs = [('"', '"'), ("“", "”"), ("«", "»"), ("「", "」"), ("```", "```")]
    original = original.strip()
    source_is_quoted = any(original.startswith(a) and original.endswith(b) for a, b in pairs)
    for a, b in pairs:
        inner = out[len(a):-len(b)] if out.startswith(a) and out.endswith(b) else None
        # strip only one pair that wraps the whole output, and only if the source had no quotes at all
        if inner is not None and not source_is_quoted and a not in inner and b not in inner:
            out = inner.strip()
            break
    return out


PROTECT = re.compile(
    r"`[^`]+`|\[\[[^\]]+\]\]|https?://\S+|\[\d+(?:[,–-]\s*\d+)*\]|\([A-Z][^()]*\d{4}\)"
    r"|[A-Za-z]+-\d+\w*|\d+(?:[.,]\d+)*\s?(?:×|°C|%|µ\w+|h|d)?|[¿¡«»]|[  ]")


def protected_changes(original, result):
    """Design §6.4: protected items present in the original but missing from the result."""
    missing = []
    for token in PROTECT.findall(original):
        if token not in ("\u00a0", "\u202f"):
            token = token.strip(" ")
        if token and token not in result:
            missing.append(token)
    return sorted(set(missing))


def words(text):
    return re.findall(r"[一-鿿぀-ヿ]|[^\s一-鿿぀-ヿ]+", text)


def changed_ratio(a, b):
    import difflib
    wa, wb = words(a), words(b)
    same = sum(blk.size for blk in difflib.SequenceMatcher(None, wa, wb, autojunk=False).get_matching_blocks())
    return round(1 - same / max(len(wa), 1), 2), len(wa)


def pick_thinking_variant(model):
    probe = {"op": "fix", "text": "Their are three reason why this approach work better."}
    messages, _ = build_messages(probe)
    rows = []
    for name, extra in THINK_VARIANTS:
        try:
            r = call(model, messages, extra)
            leaked = len(r["raw"]) > 200
            rows.append({"variant": name, "total_s": r["total_s"], "reasoning_chars": r["reasoning_chars"],
                         "leaked_thinking_into_answer": leaked})
        except Exception as e:  # noqa: BLE001
            rows.append({"variant": name, "error": str(e)[:120]})
    ok = [r for r in rows if "error" not in r and not r["leaked_thinking_into_answer"]]
    ok.sort(key=lambda r: (r["reasoning_chars"] > 0, r["total_s"]))
    best = ok[0]["variant"] if ok else "default"
    return best, rows


def lms(*args):
    return subprocess.run([LMS, *args], capture_output=True, text=True, timeout=600)


def run_model(model, corpus):
    lms("unload", "--all")
    t = time.time()
    loaded = lms("load", model, "--yes")
    load_s = round(time.time() - t, 1)
    if loaded.returncode != 0:
        return {"model": model, "error": (loaded.stderr or loaded.stdout)[-400:]}
    variant, probes = pick_thinking_variant(model)
    extra = dict(THINK_VARIANTS)[variant]
    results = []
    for item in corpus:
        messages, markers = build_messages(item)
        try:
            r = call(model, messages, extra)
        except Exception as e:  # noqa: BLE001
            if "refused" in str(e):          # server stopped under us: bring it back once
                lms("server", "start")
                lms("load", model, "--yes")
                try:
                    r = call(model, messages, extra)
                except Exception as e2:  # noqa: BLE001
                    results.append({"id": item["id"], "error": str(e2)[:200]})
                    continue
            else:
                results.append({"id": item["id"], "error": str(e)[:200]})
                continue
        r["output"] = clean(r.pop("raw"), markers, item["text"])
        r["id"] = item["id"]
        if item["op"] != "translate":
            r["protected_missing"] = protected_changes(item["text"], r["output"])
            r["changed_ratio"], r["n_words"] = changed_ratio(item["text"], r["output"])
        results.append(r)
        print(f"  {model} {item['id']} {r['total_s']}s", flush=True)
    ps = lms("ps").stdout
    return {"model": model, "load_s": load_s, "thinking_variant": variant,
            "thinking_probes": probes, "lms_ps": ps, "results": results}


def write_markdown(corpus, runs):
    out_dir = os.path.join(HERE, "results", "by-language")
    os.makedirs(out_dir, exist_ok=True)
    langs = sorted({c["lang"] for c in corpus})
    for lang in langs:
        lines = [f"# Model outputs: {lang}", ""]
        for item in [c for c in corpus if c["lang"] == lang]:
            head = item["op"] + (" → " + item["target"] if item["op"] == "translate" else "")
            if item.get("tone"):
                head += " (" + item["tone"] + ")"
            lines += [f"## {item['id']} · {head}", "", f"Note: {item['note']}", "",
                      "Original:", "", "> " + item["text"], ""]
            for run in runs:
                if "results" not in run:
                    continue
                r = next((x for x in run["results"] if x["id"] == item["id"]), None)
                if not r:
                    continue
                if "error" in r:
                    lines += [f"**{run['model']}**: ERROR {r['error']}", ""]
                    continue
                meta = f"{r['total_s']} s"
                if r.get("reasoning_chars"):
                    meta += f", thinking {r['reasoning_chars']} chars"
                if r.get("finish") and r["finish"] != "stop":
                    meta += f", finish={r['finish']}"
                if r.get("protected_missing"):
                    meta += ", protected items missing: " + " ".join(r["protected_missing"])
                if "changed_ratio" in r:
                    meta += f", changed {int(r['changed_ratio'] * 100)}% of {r['n_words']} words"
                lines += [f"**{run['model']}** ({meta}):", "", "> " + r["output"].replace("\n", "\n> "), ""]
        with open(os.path.join(out_dir, f"{lang}.md"), "w", encoding="utf-8") as f:
            f.write("\n".join(lines))


def main():
    with open(os.path.join(HERE, "corpus.json"), encoding="utf-8") as f:
        corpus = json.load(f)
    runs = []
    for model in sys.argv[1:]:
        print("model:", model, flush=True)
        run = run_model(model, corpus)
        runs.append(run)
        name = model.replace("/", "__")
        with open(os.path.join(HERE, "results", f"{name}.json"), "w", encoding="utf-8") as f:
            json.dump(run, f, ensure_ascii=False, indent=1)
        write_markdown(corpus, runs)
    lms("unload", "--all")
    print("done", flush=True)


if __name__ == "__main__":
    main()

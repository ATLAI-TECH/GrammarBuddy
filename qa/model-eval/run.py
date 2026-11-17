#!/usr/bin/env python3
"""Run the multilingual corpus against local models (LM Studio) or an OpenAI-compatible API.

Usage:
  python3 run.py [--repeats N] [--only ID,ID] MODEL [MODEL ...]           LM Studio
  python3 run.py --api https://api.example.com/v1 --key-env MY_KEY MODEL   any OpenAI-compatible API

LM Studio models go through its native /api/v1/chat with reasoning:"off" (design §7.2). The
script first probes each model with a long sentence (design §6.6) and only keeps "off" if it
really stops thinking and does not leak the reasoning into the answer; otherwise it falls back.

Writes: results/<model>.json            raw outputs, timings, mechanical checks, per repeat
        results/by-language/<lang>.md   side-by-side outputs for human review
        results/summary.md              one table per model
"""
import argparse, difflib, json, os, re, subprocess, sys, time, unicodedata, urllib.error, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
LMS_BASE = "http://localhost:1234"
LMS = os.path.expanduser("~/.lmstudio/bin/lms")

# 30+ words with a citation and numbers: short probes make thinking look "off" when it is not (design §6.6)
PROBE = ("Their are three reason why the flc-3 mutant flower earlier then Col-0 under long days "
         "(16 h light / 8 h dark), as previously reported [12, 15], and the effect were stronger "
         "at 22 °C than at 16 °C in all 4 independent experiments.")


def read(name):
    with open(os.path.join(HERE, "prompts", name), encoding="utf-8") as f:
        return f.read().strip()


LANG_NAMES = {"en": "English", "zh": "Simplified Chinese", "fr": "French", "de": "German", "es": "Spanish", "ja": "Japanese"}


def system_prompt(item):
    if item["op"] == "translate":
        s = read("translate.txt").replace("{TARGET}", item["target"])
    else:
        s = read(item["op"] + ".txt").replace("{TONE}", item.get("tone", "")) + " " + read("_common.txt")
        # same as the app (TextOperation.swift): name the language, polish/tone drifted into English in round 6
        lang = LANG_NAMES.get(item["lang"])
        if lang:
            s = f"The text is written in {lang}. Your reply must be in {lang}. " + s
    return s.replace("{PROTECTED}", "")


# ── transports ─────────────────────────────────────────────

def _post(url, body, headers=None):
    h = {"Content-Type": "application/json", **(headers or {})}
    return urllib.request.urlopen(urllib.request.Request(url, json.dumps(body).encode(), h), timeout=300)


def call_native(model, system, text, reasoning_off):
    body = {"model": model, "system_prompt": system, "input": text, "stream": True,
            "temperature": 0.2, "context_length": 8192, "store": False}
    if reasoning_off:
        body["reasoning"] = "off"
    start, first, content, reasoning, stats = time.time(), None, [], [], {}
    try:
        resp = _post(LMS_BASE + "/api/v1/chat", body)
    except urllib.error.HTTPError as e:
        raise RuntimeError(e.read().decode("utf-8", "replace")[:300]) from None
    with resp:
        for raw in resp:
            line = raw.decode("utf-8", "replace").strip()
            if not line.startswith("data:"):
                continue
            try:
                o = json.loads(line[5:].strip())
            except ValueError:
                continue
            t = o.get("type", "")
            if t == "message.delta":
                if first is None:
                    first = time.time() - start
                content.append(o.get("content", ""))
            elif t.startswith("reasoning") and o.get("content"):
                reasoning.append(o["content"])
            elif t == "error":
                raise RuntimeError(json.dumps(o.get("error"))[:300])
            elif t == "chat.end":
                res = o.get("result", {})
                stats = res.get("stats", {})
                if not content:
                    content = [x.get("content", "") for x in res.get("output", []) if x.get("type") == "message"]
    return {"raw": "".join(content), "reasoning_chars": len("".join(reasoning)),
            "first_token_s": round(first, 2) if first is not None else None,
            "total_s": round(time.time() - start, 2), "finish": stats.get("stop_reason"),
            "tokens_per_s": stats.get("tokens_per_second")}


def call_openai(base, key, model, system, text, extra):
    body = {"model": model, "temperature": 0.2, "stream": True,
            "messages": [{"role": "system", "content": system}, {"role": "user", "content": text}], **extra}
    start, first, content, reasoning, finish = time.time(), None, [], [], None
    try:
        resp = _post(base.rstrip("/") + "/chat/completions", body, {"Authorization": "Bearer " + key})
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"HTTP {e.code}: " + e.read().decode("utf-8", "replace")[:300]) from None
    with resp:
        for raw in resp:
            line = raw.decode("utf-8", "replace").strip()
            if not line.startswith("data:") or line[5:].strip() == "[DONE]":
                continue
            try:
                choice = json.loads(line[5:].strip())["choices"][0]
            except (ValueError, KeyError, IndexError):
                continue
            d = choice.get("delta", {})
            if d.get("content"):
                first = first if first is not None else time.time() - start
                content.append(d["content"])
            r = d.get("reasoning_content") or d.get("reasoning")
            if r:
                reasoning.append(r)
            finish = choice.get("finish_reason") or finish
    return {"raw": "".join(content), "reasoning_chars": len("".join(reasoning)),
            "first_token_s": round(first, 2) if first is not None else None,
            "total_s": round(time.time() - start, 2), "finish": finish}


# ── cleaning and checks (design §6.3–6.5) ──────────────────

PREAMBLE = re.compile(r"^(here is|here's|corrected|the corrected|revised|translation)[^\n]{0,60}:\s*\n", re.I)


def clean(raw, original):
    out = re.sub(r"<think>.*?</think>", "", raw, flags=re.S).strip()
    out = PREAMBLE.sub("", out).strip()
    pairs = [('"', '"'), ("“", "”"), ("«", "»"), ("「", "」"), ("```", "```")]
    o = original.strip()
    if not any(o.startswith(a) and o.endswith(b) for a, b in pairs):
        for a, b in pairs:
            if len(out) > len(a) + len(b) and out.startswith(a) and out.endswith(b):
                inner = out[len(a):-len(b)]
                if a not in inner and b not in inner:
                    out = inner.strip()
                    break
    # Markdown emphasis the original did not have (§6.3)
    if not re.search(r"(\*\*?|__?)\S.*?\1", original):
        out = re.sub(r"(\*\*?|__)(\S(?:.*?\S)?)\1", r"\2", out)
    return out


PROTECT = re.compile(
    r"`[^`]+`|\[\[[^\]]+\]\]|https?://\S+|\[\d+(?:[,–-]\s*\d+)*\]|\([A-Z][^()]*\d{4}\)"
    r"|[A-Za-z]+-\d+\w*|\d+(?:[.,]\d+)*\s?(?:×|°C|%|µ\w+|h|d)?|[¿¡«»]")


def protected_missing(original, result):
    miss = {t.strip() for t in PROTECT.findall(original) if t.strip() and t.strip() not in result}
    # invisible characters (round 6 FR6-03): no-break spaces and curly apostrophes must survive
    for ch, name in (("\u00a0", "NBSP"), ("\u202f", "NNBSP"), ("\u2019", "’")):
        if original.count(ch) > result.count(ch):
            miss.add(f"{name}×{original.count(ch) - result.count(ch)}")
    return sorted(miss)


CJK = r"一-鿿぀-ヿ"
FUNCTION_WORDS = set("""a an the of to in on at for and or but is are was were be been has have had do does did
that this it its as by with from le la les un une des de du et à au aux en il elle est der die das den dem des ein eine
einen und zu im am ist sind el los las una unos y que en es son del al se lo""".split())


def tokens(text):
    return re.findall(rf"[{CJK}]|[^\W\d_{CJK}]+(?:[-'][^\W\d_{CJK}]+)*", unicodedata.normalize("NFC", text))


def dropped_words(original, result):
    """§6.5 word retention for fix: content words of the original that vanished without a replacement."""
    a = [t.lower() for t in tokens(original)]
    b = [t.lower() for t in tokens(result)]
    bset = set(b)
    lost = []
    sm = difflib.SequenceMatcher(None, a, b, autojunk=False)
    for tag, i1, i2, j1, j2 in sm.get_opcodes():
        if tag == "delete" or (tag == "replace" and (i2 - i1) > (j2 - j1)):
            gone = a[i1:i2] if tag == "delete" else a[i1 + (j2 - j1):i2]
            for w in gone:
                if w in bset or w in FUNCTION_WORDS:
                    continue
                if len(w) == 1 and not re.match(rf"[{CJK}]", w):
                    continue
                lost.append(w)
    # Chinese/Japanese: a single dropped hanzi is usually a fix; two or more in a row counts (§6.5)
    cjk = [w for w in lost if re.match(rf"[{CJK}]", w)]
    latin = [w for w in lost if not re.match(rf"[{CJK}]", w)]
    return latin + (cjk if len(cjk) >= 2 else [])


def norm(s):
    return re.sub(r"\s+", " ", unicodedata.normalize("NFC", s)).strip()


def check(item, out, finish):
    c = {}
    if not out.strip():
        c["empty"] = True
    if finish and finish not in ("stop", "eosFound", "endOfText"):
        c["finish"] = finish
    if item["op"] != "translate":
        miss = protected_missing(item["text"], out)
        if miss:
            c["protected_missing"] = miss
        if len(tokens(out)) > 3 * max(len(tokens(item["text"])), 1):
            c["too_long"] = True
    if item["op"] == "fix":
        d = dropped_words(item["text"], out)
        if d:
            c["dropped_words"] = d
    if re.search(r"https?://", out) and not re.search(r"https?://", item["text"]):
        c["new_url"] = True
    if "expect" in item:
        c["matches_expect"] = norm(out) == norm(item["expect"])
    return c


# ── model handling ─────────────────────────────────────────

def lms(*args):
    return subprocess.run([LMS, *args], capture_output=True, text=True, timeout=900)


def probe_native(model):
    system = read("fix.txt") + " " + read("_common.txt")
    rows = []
    for off in (True, False):
        try:
            r = call_native(model, system.replace("{PROTECTED}", ""), PROBE, off)
            out = clean(r["raw"], PROBE)
            leaked = len(tokens(out)) > 2 * len(tokens(PROBE)) or "<think>" in r["raw"]
            # the probe sentence has known errors; returning it unchanged is a failed probe (round 6 EN6-01)
            if norm(out) == norm(PROBE) or "There are" not in out:
                leaked = True
            rows.append({"reasoning_off": off, "total_s": r["total_s"], "reasoning_chars": r["reasoning_chars"],
                         "leaked": leaked, "output": out[:400]})
        except Exception as e:  # noqa: BLE001
            rows.append({"reasoning_off": off, "error": str(e)[:200]})
    ok = [r for r in rows if "error" not in r and not r["leaked"]]
    ok.sort(key=lambda r: (r["reasoning_chars"] > 0, r["total_s"]))
    return (ok[0]["reasoning_off"] if ok else False), rows


def run_model(model, corpus, args):
    run = {"model": model, "started": time.strftime("%Y-%m-%d %H:%M"), "repeats": args.repeats}
    if args.api:
        key = os.environ.get(args.key_env or "", "")
        if not key:
            return {**run, "error": f"environment variable {args.key_env} is empty"}
        extra = json.loads(args.extra) if args.extra else {}
        do = lambda s, t: call_openai(args.api, key, model, s, t, extra)  # noqa: E731
        run["transport"] = "openai-compatible " + args.api
    else:
        lms("unload", "--all")
        t = time.time()
        loaded = lms("load", model, "--yes", "--context-length", "8192")
        run["load_s"] = round(time.time() - t, 1)
        if loaded.returncode != 0:
            return {**run, "error": (loaded.stderr or loaded.stdout)[-400:]}
        off, probes = probe_native(model)
        run.update(transport="lmstudio-native", reasoning_off=off, probes=probes)
        print(f"  probe: reasoning_off={off} {[(p.get('total_s'), p.get('reasoning_chars'), p.get('leaked')) for p in probes]}", flush=True)
        do = lambda s, t: call_native(model, s, t, off)  # noqa: E731
    results = []
    for item in corpus:
        for rep in range(args.repeats):
            try:
                r = do(system_prompt(item), item["text"])
            except Exception as e:  # noqa: BLE001
                if "refused" in str(e) and not args.api:
                    lms("server", "start")
                    try:
                        r = do(system_prompt(item), item["text"])
                    except Exception as e2:  # noqa: BLE001
                        results.append({"id": item["id"], "rep": rep, "error": str(e2)[:200]})
                        continue
                else:
                    results.append({"id": item["id"], "rep": rep, "error": str(e)[:200]})
                    continue
            r["output"] = clean(r.pop("raw"), item["text"])
            r.update(id=item["id"], rep=rep, checks=check(item, r["output"], r.get("finish")))
            results.append(r)
            print(f"  {model} {item['id']}#{rep} {r['total_s']}s think={r['reasoning_chars']} {r['checks']}", flush=True)
    if not args.api:
        run["lms_ps"] = lms("ps").stdout
        run["swap"] = subprocess.run(["sysctl", "-n", "vm.swapusage"], capture_output=True, text=True).stdout.strip()
    run["results"] = results
    return run


# ── reports ────────────────────────────────────────────────

def median(xs):
    xs = sorted(xs)
    return xs[len(xs) // 2] if xs else None


def summarize(run, corpus):
    rs = [r for r in run.get("results", []) if "error" not in r]
    errors = [r for r in run.get("results", []) if "error" in r]
    by_id = {}
    for r in rs:
        by_id.setdefault(r["id"], []).append(r["output"])
    unstable = sum(1 for outs in by_id.values() if len({norm(o) for o in outs}) > 1)
    exp = [r for r in rs if "matches_expect" in r["checks"]]
    lines = [f"## {run['model']}", "",
             f"- transport: {run.get('transport')}, reasoning_off: {run.get('reasoning_off')}, load: {run.get('load_s')} s",
             f"- calls: {len(rs)} ok, {len(errors)} errors; repeats per item: {run.get('repeats')}",
             f"- time per call: median {median([r['total_s'] for r in rs])} s, max {max([r['total_s'] for r in rs], default=None)} s; "
             f"first token median {median([r['first_token_s'] for r in rs if r['first_token_s'] is not None])} s",
             f"- calls that thought: {sum(1 for r in rs if r['reasoning_chars'])}; empty outputs: {sum(1 for r in rs if r['checks'].get('empty'))}",
             f"- items whose output differs between repeats: {unstable} of {len(by_id)}",
             f"- exact match with expected output: {sum(1 for r in exp if r['checks']['matches_expect'])} of {len(exp)} calls that have one",
             f"- flagged: protected missing {sum(1 for r in rs if 'protected_missing' in r['checks'])}, "
             f"dropped words {sum(1 for r in rs if 'dropped_words' in r['checks'])}, too long {sum(1 for r in rs if r['checks'].get('too_long'))}",
             f"- swap after run: {run.get('swap')}", ""]
    langs = sorted({c.get("review_lang", c["lang"]) for c in corpus})
    lines += ["| lang | calls | median s | thought | empty | dropped words | protected missing | expect match |", "|---|---|---|---|---|---|---|---|"]
    lang_of = {c["id"]: c.get("review_lang", c["lang"]) for c in corpus}
    for lg in langs:
        sub = [r for r in rs if lang_of.get(r["id"]) == lg]
        e = [r for r in sub if "matches_expect" in r["checks"]]
        lines.append(f"| {lg} | {len(sub)} | {median([r['total_s'] for r in sub])} | {sum(1 for r in sub if r['reasoning_chars'])} | "
                     f"{sum(1 for r in sub if r['checks'].get('empty'))} | {sum(1 for r in sub if 'dropped_words' in r['checks'])} | "
                     f"{sum(1 for r in sub if 'protected_missing' in r['checks'])} | {sum(1 for r in e if r['checks']['matches_expect'])}/{len(e)} |")
    return "\n".join(lines) + "\n"


def write_markdown(corpus, runs):
    out_dir = os.path.join(HERE, "results", "by-language")
    os.makedirs(out_dir, exist_ok=True)
    for lang in sorted({c.get("review_lang", c["lang"]) for c in corpus}):
        lines = [f"# Model outputs: {lang}", ""]
        for item in [c for c in corpus if c.get("review_lang", c["lang"]) == lang]:
            head = item["op"] + (" → " + item["target"] if item["op"] == "translate" else "")
            if item.get("tone"):
                head += " (" + item["tone"] + ")"
            lines += [f"## {item['id']} · {head}", "", f"Note: {item.get('note', '')}", "", "Original:", "", "> " + item["text"], ""]
            if "expect" in item:
                lines += ["Expected:", "", "> " + item["expect"], ""]
            for run in runs:
                for r in [x for x in run.get("results", []) if x["id"] == item["id"]]:
                    tag = f"**{run['model']}** #{r.get('rep', 0)}"
                    if "error" in r:
                        lines += [f"{tag}: ERROR {r['error']}", ""]
                        continue
                    meta = f"{r['total_s']} s"
                    if r.get("reasoning_chars"):
                        meta += f", thinking {r['reasoning_chars']} chars"
                    flags = {k: v for k, v in r["checks"].items() if k != "matches_expect"}
                    if flags:
                        meta += ", " + json.dumps(flags, ensure_ascii=False)
                    if r["checks"].get("matches_expect"):
                        meta += ", = expected"
                    lines += [f"{tag} ({meta}):", "", "> " + r["output"].replace("\n", "\n> "), ""]
        with open(os.path.join(out_dir, f"{lang}.md"), "w", encoding="utf-8") as f:
            f.write("\n".join(lines))
    with open(os.path.join(HERE, "results", "summary.md"), "w", encoding="utf-8") as f:
        f.write("# Model eval summary\n\nGenerated by run.py. Mechanical checks only; quality needs human review.\n\n")
        for run in runs:
            f.write(summarize(run, corpus) if "results" in run else f"## {run['model']}\n\nERROR: {run.get('error')}\n\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("models", nargs="+")
    ap.add_argument("--repeats", type=int, default=1)
    ap.add_argument("--only", help="comma-separated item ids")
    ap.add_argument("--api", help="OpenAI-compatible base URL, e.g. https://openrouter.ai/api/v1")
    ap.add_argument("--key-env", help="environment variable that holds the API key")
    ap.add_argument("--extra", help="JSON merged into each API request body, e.g. thinking switches")
    ap.add_argument("--report-only", action="store_true", help="rebuild the reports from results/<model>.json without running")
    args = ap.parse_args()
    with open(os.path.join(HERE, "corpus.json"), encoding="utf-8") as f:
        corpus = json.load(f)
    if args.only:
        keep = set(args.only.split(","))
        corpus = [c for c in corpus if c["id"] in keep]
    os.makedirs(os.path.join(HERE, "results"), exist_ok=True)
    if args.report_only:
        runs = []
        for model in args.models:
            with open(os.path.join(HERE, "results", model.replace("/", "__") + ".json"), encoding="utf-8") as f:
                runs.append(json.load(f))
        write_markdown(corpus, runs)
        return
    runs = []
    for model in args.models:
        print("model:", model, flush=True)
        run = run_model(model, corpus, args)
        runs.append(run)
        with open(os.path.join(HERE, "results", model.replace("/", "__") + ".json"), "w", encoding="utf-8") as f:
            json.dump(run, f, ensure_ascii=False, indent=1)
        write_markdown(corpus, runs)
    if not args.api:
        lms("unload", "--all")
    print("done", flush=True)


if __name__ == "__main__":
    main()

"""Map UTF-16 offsets of the text read from Word (content of text object of <range>) to Word
character positions, and back. Verified on Word 16.114.4 (see docs/m0/word.md, question 2).

Rule (view pinned: revisions view final, balloon revisions, show field codes false, every field show codes false):
  * every UTF-16 unit of content = 1 Word position (BMP chars, Chinese, paragraph mark \r, footnote mark \x02,
    tab, ...; an emoji outside the BMP = 2 UTF-16 units = 2 Word positions),
  * EXCEPT the end-of-cell / end-of-row mark, which reads as the 2 units "\r\x07" but is 1 Word position,
  * PLUS hidden positions that occupy Word positions but are not in content at all:
      - per field: field-begin char + field code + separator  = [code_start-1, result_start)
                   and the field-end char                     = [result_end, result_end+1)
      - text of pending deletions (revision delete)           = [rev_start, rev_end)
  Comments' anchors add nothing (no position, no char).
"""
def hidden_intervals(fields, deletions):
    """fields: list of (code_start, code_end, result_start, result_end); deletions: list of (start, end)."""
    iv = []
    for cs, ce, rs, re_ in fields:
        iv.append((cs - 1, rs))
        iv.append((re_, re_ + 1))
    iv += list(deletions)
    iv.sort()
    merged = []
    for a, b in iv:
        if merged and a <= merged[-1][1]:
            merged[-1] = (merged[-1][0], max(merged[-1][1], b))
        else:
            merged.append((a, b))
    return merged

def build_map(content, start, hidden):
    """Return list pos[i] = Word position of UTF-16 unit i of content (len = utf16 len + 1, last = end).
    content: str as returned by Word; start: start of content of the range read; hidden: merged intervals."""
    units = content.encode("utf-16-le")
    n = len(units) // 2
    cu = [int.from_bytes(units[2*i:2*i+2], "little") for i in range(n)]
    pos = []
    p = start
    hi = [h for h in hidden if h[1] > start]
    k = 0
    i = 0
    def skip(p, k):
        while k < len(hi) and hi[k][0] <= p:
            if p < hi[k][1]:
                p = hi[k][1]
            k += 1
        return p, k
    while i < n:
        p, k = skip(p, k)
        if cu[i] == 0x0D and i + 1 < n and cu[i+1] == 0x07:   # cell / row end mark: 2 units, 1 position
            pos += [p, p]; i += 2; p += 1
        else:
            pos.append(p); i += 1; p += 1
    p, k = skip(p, k)
    pos.append(p)
    return pos

def word_range(pos, i, j):
    """UTF-16 [i, j) of content -> Word (start, end)."""
    return pos[i], (pos[j-1] + 1 if j > i else pos[i])

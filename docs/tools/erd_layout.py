"""Add sizes and positions to an ER spec so draw_erd.ps1 knows where to put new tables.

Spec (JSON):
  tables:        [{"name": "DIM_X", "columns": ["X_KEY", "NAME", ...], "pk": ["X_KEY"],
                   optional "kind": "DIM|FACT|MAPPING" (default from the name: *_MAPPING, FACT_*, else DIM),
                   optional "x", "y" (points) when the table is already placed}]
                 (a table may give "lines" instead of "columns"/"pk": the header followed by one text row per column)
  relationships: [{"parent": "DIM_X", "child": "FACT_Y", "column": "X_KEY", "cardinality": "1:N"}]

Foreign keys are the child columns of "relationships"; their text row ends with "-> PARENT_TABLE".
Tables that already have x and y keep them (so a layout the user arranged in Excel is not touched);
every table gets "w" and "h". New tables are placed in layers: parents above children.

Run with the project's interpreter:  python -I docs/tools/erd_layout.py spec.json
"""
import json
import sys
from collections import defaultdict

CHAR_W, HEAD_CHAR_W, LINE_H = 5.3, 6.6, 10.4  # points, Consolas 8.5 pt rows and 10 pt bold header
PAD_W, PAD_H = 22, 18
X_GAP, Y_GAP = 60, 70
LEFT, TOP = 24, 64


def build_lines(table, fk):
    lines = [table["name"]]
    for col in table["columns"]:
        is_pk, parent = col in table.get("pk", []), fk.get((table["name"], col))
        flag = "PK,FK" if is_pk and parent else "PK" if is_pk else "FK" if parent else ""
        lines.append(flag.ljust(7) + col + (f" -> {parent}" if parent else ""))
    return lines


def default_kind(name):
    if name.endswith("_MAPPING"):
        return "MAPPING"
    return "FACT" if name.startswith("FACT_") else "DIM"


def size(table):
    rows = table["lines"][1:]
    w = max(len(table["lines"][0]) * HEAD_CHAR_W, max((len(r) for r in rows), default=0) * CHAR_W) + PAD_W
    h = 14 + len(rows) * LINE_H + PAD_H
    return round(w, 1), round(h, 1)


def layers_of(names, rels):
    parents, children = defaultdict(set), defaultdict(set)
    for r in rels:
        parents[r["child"]].add(r["parent"])
        children[r["parent"]].add(r["child"])
    layer = {}

    def depth(n, seen=()):
        if n not in layer:
            ps = [p for p in parents[n] if p not in seen]
            layer[n] = 1 + max(depth(p, seen + (n,)) for p in ps) if ps else 0
        return layer[n]

    for n in names:
        depth(n)
    for _ in range(len(names)):  # pull parents down next to their first child
        for n in names:
            if children[n]:
                layer[n] = max(layer[n], min(layer[c] for c in children[n]) - 1)
    return layer, parents, children


def main():
    path = sys.argv[1]
    spec = json.load(open(path, encoding="utf-8"))
    tables = {t["name"]: t for t in spec["tables"]}
    fk = {(r["child"], r["column"]): r["parent"] for r in spec["relationships"]}
    for t in tables.values():
        t.setdefault("kind", default_kind(t["name"]))
        if "lines" not in t:
            t["lines"] = build_lines(t, fk)
        t["w"], t["h"] = size(t)

    names = sorted(tables)
    layer, parents, children = layers_of(names, spec["relationships"])
    rows = [[n for n in names if layer[n] == i] for i in range(max(layer.values()) + 1)]
    pos = {n: i for row in rows for i, n in enumerate(row)}
    for sweep in range(6):  # barycentre ordering to reduce crossings
        for row in (rows if sweep % 2 == 0 else list(reversed(rows))):
            def bary(n):
                nb = [pos[x] for x in (parents[n] | children[n]) if x in pos]
                return sum(nb) / len(nb) if nb else pos[n]
            row.sort(key=lambda n: (bary(n), n))
            for i, n in enumerate(row):
                pos[n] = i

    row_w = [sum(tables[n]["w"] for n in row) + X_GAP * (len(row) - 1) for row in rows]
    y = TOP
    placed = set()
    for i, row in enumerate(rows):
        x = LEFT + (max(row_w) - row_w[i]) / 2
        for n in row:
            t = tables[n]
            if "x" not in t or "y" not in t:
                t["x"], t["y"] = round(x, 1), round(y, 1)
                placed.add(n)
            x += t["w"] + X_GAP
        y += max(tables[n]["h"] for n in row) + Y_GAP

    # A table with a parent more than one layer up: put it under a gap between the boxes of the layer above,
    # so the long line runs down through free space instead of behind a box.
    for n in names:
        i = layer[n]
        if n not in placed or i < 2 or not any(i - layer[p] > 1 for p in parents[n]):
            continue
        above = sorted(rows[i - 1], key=lambda m: tables[m]["x"])
        gaps = [(tables[a]["x"] + tables[a]["w"] + tables[b]["x"]) / 2 for a, b in zip(above, above[1:])]
        if not gaps:
            continue
        t = tables[n]
        centre = min(gaps, key=lambda g: abs(g - (t["x"] + t["w"] / 2)))
        new_x = centre - t["w"] / 2
        if all(m == n or new_x + t["w"] + 20 <= tables[m]["x"] or tables[m]["x"] + tables[m]["w"] + 20 <= new_x
               for m in rows[i]):
            t["x"] = round(new_x, 1)

    json.dump(spec, open(path, "w", encoding="utf-8"), indent=1)
    print(f"{len(tables)} tables, {len(spec['relationships'])} relationships, {len(rows)} layers")


if __name__ == "__main__":
    main()

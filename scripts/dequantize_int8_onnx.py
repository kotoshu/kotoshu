"""Dequantize a DynamicQuantizeLinear/MatMulInteger ONNX graph to float ops (v2).

Verified graph structure (mdeberta int8 exports):
  x --DynamicQuantizeLinear--> (a_q, a_scale, a_zp)
  w_scale initializer named <stem>_scale  (b = <stem>_quantized)
  MatMulInteger(a_q, b_q, a_zp, b_zp) -> raw(int32)
  raw --Cast--> rawf
  scales_mul = Mul(a_scale, w_scale)
  rawf, scales_mul --Mul--> y                     (single fused scale apply)

Rewrite: y = DequantizeLinear(a_q, a_scale, a_zp) @ ((b_q - b_zp) * w_scale)
i.e. DQ node + float MatMul writing straight to y; MatMulInteger, Cast,
scales_mul and the second Mul are removed. Uses only ops sound in every
ORT build (the ruby-gem x86 runtime mis-executes these int8 kernels).

Usage: python3 dequantize_int8_onnx.py IN.onnx OUT.onnx
"""
import sys
import os
import onnx
import numpy as np
from onnx import numpy_helper, helper

src, dst = sys.argv[1], sys.argv[2]
m = onnx.load(src)
g = m.graph
init = {i.name: i for i in g.initializer}
nodes = list(g.node)
dql = {n.output[0]: n for n in nodes if n.op_type == "DynamicQuantizeLinear"}
consumers = {}
for n in nodes:
    for i in n.input:
        consumers.setdefault(i, []).append(n)

kill = set()
replacements = []
for idx, n in enumerate(nodes):
    if n.op_type != "MatMulInteger":
        continue
    a_q, b_q, a_zp, b_zp = n.input[:4]
    d = dql.get(a_q)
    if d is None:
        print("skip (no DQL producer):", n.name)
        continue
    casts = [c for c in consumers.get(n.output[0], []) if c.op_type == "Cast"]
    muls = [c for c in consumers.get(n.output[0], []) if c.op_type == "Mul"]
    y_node = None
    w_scale_name = None
    # path A: MatMulInteger -> Cast -> Mul(cast, scales_mul) -> y
    if casts:
        cast = casts[0]
        kill.add(id(cast))
        for c2 in consumers.get(cast.output[0], []):
            if c2.op_type == "Mul":
                y_node = c2
        # the other Mul input is the scales_mul output
        if y_node:
            other = next((i for i in y_node.input if i != cast.output[0]), None)
            smul = next((s for s in nodes if s.op_type == "Mul" and s.output and s.output[0] == other), None)
            if smul is not None:
                for cin in smul.input:
                    if cin in init and cin.endswith("_scale"):
                        w_scale_name = cin
                kill.add(id(smul))
    # path B (no Cast): MatMulInteger -> Mul -> y  (single or fused scale)
    if y_node is None and muls:
        y_node = muls[0]
        for cin in y_node.input:
            if cin != n.output[0] and cin in init and cin.endswith("_scale"):
                w_scale_name = cin
    b = numpy_helper.to_array(init[b_q]).astype(np.float32)
    bzp = (numpy_helper.to_array(init[b_zp]).astype(np.float32)
           if b_zp in init else np.float32(0))
    wf = b - bzp
    if w_scale_name:
        wf = wf * numpy_helper.to_array(init[w_scale_name]).astype(np.float32).reshape(1, -1)
    stem = b_q.replace("_quantized", "")
    g.initializer.append(numpy_helper.from_array(
        wf.astype(np.float32), stem + "_fq"))
    y_name = y_node.output[0] if y_node is not None else n.output[0]
    if y_node is not None:
        kill.add(id(y_node))
    a_fq = a_q + f"_fq{idx}"
    dq = helper.make_node("DequantizeLinear", [a_q, d.output[1], d.output[2]],
                          [a_fq], name=n.name + "_dq")
    mm = helper.make_node("MatMul", [a_fq, stem + "_fq"], [y_name],
                          name=n.name + "_fq")
    replacements.append((n, dq, mm))

repl = {id(n): (dq, mm) for n, dq, mm in replacements}
new_nodes = []
for n in nodes:
    if id(n) in repl:
        dq, mm = repl[id(n)]
        new_nodes.extend([dq, mm])
    elif id(n) in kill:
        continue
    else:
        new_nodes.append(n)
del g.node[:]
g.node.extend(new_nodes)
# prune now-unused int8 initializers — collect inputs from ALL nodes
# INCLUDING subgraphs (If/Loop bodies reference top-level initializers)
def collect_used(graph, used):
    for n in graph.node:
        used.update(n.input)
        for attr in n.attribute:
            if attr.type == onnx.AttributeProto.GRAPH:
                collect_used(attr.g, used)
            elif attr.type == onnx.AttributeProto.GRAPHS:
                for sub in attr.graphs:
                    collect_used(sub, used)


used = set()
collect_used(g, used)
for i in list(g.initializer):
    if i.name not in used:
        g.initializer.remove(i)
# NOTE: the source export is not checker-clean (unsorted If-graph) and
# ORT runs it fine — the runtime probe is the validation, not the checker.
onnx.save(m, dst)
print(f"replaced {len(replacements)}; killed {len(kill)} nodes; "
      f"saved {dst} ({os.path.getsize(dst)/1e6:.0f}MB)")

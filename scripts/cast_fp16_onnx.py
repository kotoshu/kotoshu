"""Cast all fp32 weight initializers of an ONNX graph to fp16 storage
with Cast(fp16->fp32) nodes at each consumer — the deberta publish path.
quantize_dynamic collapses deberta-v3 taggers (per-tensor activation
int8 granularity kills the argmax margins — measured 0 edits on the ur
gate vs 6.2% for the fp32 export), so deberta ships int8-free: fp16
weight bytes halve the file while activations stay fp32 (sound ops in
every ORT build).

Usage: python3 cast_fp16_onnx.py IN.onnx OUT.onnx
"""
import sys
import os
import numpy as np
import onnx
from onnx import numpy_helper, helper

src, dst = sys.argv[1], sys.argv[2]
m = onnx.load(src)
g = m.graph

casted = 0
for init in list(g.initializer):
    arr = numpy_helper.to_array(init)
    if arr.dtype != np.float32 or arr.size < 64:
        continue
    fp16 = numpy_helper.from_array(arr.astype(np.float16), init.name + "_stored_fp16")
    cast = helper.make_node("Cast", [init.name + "_stored_fp16"],
                            [init.name], to=onnx.TensorProto.FLOAT,
                            name=init.name + "_fp16cast")
    g.initializer.remove(init)
    g.initializer.append(fp16)
    g.node.insert(0, cast)
    casted += 1

onnx.save(m, dst)
print(f"casted {casted} initializers to fp16 storage; "
      f"saved {dst} ({os.path.getsize(dst)/1e6:.0f}MB)")

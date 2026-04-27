"""smoke_basic.py — verify core import chain after applying overlay.

Exit 0 on success, 1 on failure.
"""
import sys

def expect(cond, msg):
    if not cond:
        print(f"  FAIL: {msg}")
        sys.exit(1)
    print(f"  ok   {msg}")

try:
    import torch
    print(f"== torch:         {torch.__version__}")
    expect(torch.__version__.startswith("2.10."), "torch is 2.10.x")

    import torch_mlu
    print(f"== torch_mlu:     {torch_mlu.__version__}")
    expect("torch2.10" in torch_mlu.__version__, "torch_mlu is built for torch 2.10")

    import torch_mlu_ops as tmo
    print(f"== torch_mlu_ops: {tmo.__version__}")
    expect("pt210" in tmo.__version__, "torch_mlu_ops is rebuilt for torch 2.10")

    print(f"== mlu available: {torch.mlu.is_available()}")
    expect(torch.mlu.is_available(), "torch.mlu.is_available() is True")
    print(f"== device:        {torch.mlu.get_device_name(0)}")
    print()
    print(">>> smoke_basic.py PASSED")
except Exception as e:
    print(f"  EXCEPTION: {type(e).__name__}: {e}")
    sys.exit(1)

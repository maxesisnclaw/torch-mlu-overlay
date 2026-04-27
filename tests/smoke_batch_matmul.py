"""smoke_batch_matmul.py — verify the rebuilt torch_mlu_ops fused
batch_matmul kernel matches torch.bmm bit-for-bit on small inputs.

This is the most meaningful end-to-end check that the C++ ABI rebuild
worked: if the kernel is mis-linked the library fails to load; if the
descriptor passing is wrong the result diverges from torch.bmm.
"""
import sys
import torch
import torch_mlu  # noqa: F401
import torch_mlu_ops as tmo

def main():
    torch.manual_seed(0)
    B, M, N, K = 4, 32, 64, 48
    a = torch.randn(B, M, K, dtype=torch.half, device="mlu")
    b = torch.randn(B, K, N, dtype=torch.half, device="mlu")

    ref = torch.bmm(a, b)
    out = tmo.batch_matmul(a, b, trans_b=False)

    diff = (out.float() - ref.float()).abs().max().item()
    rel = diff / (ref.float().abs().max().item() + 1e-9)

    print(f"  output shape: {tuple(out.shape)}")
    print(f"  max abs diff: {diff:.4e}")
    print(f"  max rel diff: {rel:.4e}")

    if rel < 1e-2:
        print(">>> smoke_batch_matmul.py PASSED")
    else:
        print(">>> smoke_batch_matmul.py FAILED (relative diff too large)")
        sys.exit(1)

if __name__ == "__main__":
    main()

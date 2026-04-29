# torch-mlu-overlay

> **PyTorch 2.10 overlay for Cambricon MLU370.**
> Apply on top of an existing Cambricon `torch 2.5` base image to
> get a working `torch 2.10 + torch_mlu 1.25 + torch_mlu_ops 1.3.2`
> stack.

## What this is — and is not

This is a **community-maintained overlay** that ports the Cambricon
MLU370 software stack forward to recent PyTorch releases.

- ✅ It ships **patches and scripts** (text-only diff against
  Cambricon's public source).
- ❌ It does **not** ship Cambricon binaries (`_MLUC.so`, `libcnnl.so`,
  `libcncl.so`, `cncc`, etc).
- ❌ It is **not** affiliated with or endorsed by Cambricon
  Technologies Co., Ltd.

You must already have a working Cambricon `torch 2.5` base image on
your machine (e.g. `cambricon-base/pytorch:v25.01-torch2.5.0-torchmlu1.24.1-ubuntu22.04-py310`).
The overlay applies our patches on top of that image.

See [`DISCLAIMER.md`](DISCLAIMER.md) for the full IP / provenance
statement, [`ROADMAP.md`](ROADMAP.md) for the project roadmap, and
[`KNOWN_ISSUES.md`](KNOWN_ISSUES.md) for known v0.1.0 limitations.

> 中文版见 [`README.md`](README.md)。

## Why

The latest publicly available `torch_mlu` baseline for the MLU370
platform is **`1.24.1` paired with `torch 2.5.0`**, while PyTorch
upstream has shipped `torch 2.10`. This overlay forward-ports the
MLU370 software stack to newer PyTorch releases so users on MLU370
hardware can keep up with upstream iterations.

v0.1 lifts `torch_mlu` to `torch 2.10`.

## Quick start

Inside a running Cambricon `torch 2.5` container with network access:

```bash
# 1. Download the latest release tarball
RELEASE=v0.1.0  # see https://github.com/maxesisnclaw/torch-mlu-overlay/releases
curl -L -o overlay.tar.gz \
  https://github.com/maxesisnclaw/torch-mlu-overlay/releases/download/${RELEASE}/release.tar.gz
tar xzf overlay.tar.gz && cd overlay

# 2. Apply
bash scripts/apply.sh

# 3. Verify
python tests/smoke_basic.py
python tests/smoke_batch_matmul.py
```

`apply.sh` does the following:

1. Sanity-checks that the running container is a Cambricon
   `torch_mlu 1.24.1 + torch 2.5.0` base.
2. Backs up `site-packages/torch_mlu/` and the live
   `/workspace/torch_mlu_ops-v1.3.2/` source tree.
3. `pip install torch==2.10.0+cpu` from the official PyTorch CPU index.
4. Applies our `patches/torch_mlu/*.patch` to the live `site-packages`.
5. Applies our `patches/torch_mlu_ops/*.patch` to the source tree and
   triggers `python setup.py build_ext --inplace` to rebuild
   `_C.cpython-310-x86_64-linux-gnu.so` against the new ABI.
6. Reinstalls the rebuilt `torch_mlu_ops` into `site-packages`.

Rollback: `bash scripts/rollback.sh` restores the original state from
the backup created in step 2.

## What you get after applying

| Component | Before | After |
|---|---|---|
| `torch` | 2.5.0+cpu | **2.10.0+cpu** |
| `torch_mlu` | 1.24.1-torch2.5.0 | **1.25.0-torch2.10.0** |
| `torch_mlu_ops` | 1.3.2+pt25 | **1.3.2+pt210** (rebuilt) |

### Validated workloads (v0.1.0)

| Workload | Status |
|---|---|
| `torch.mlu.is_available()` + device probe | ✅ |
| Basic ops (`torch.bmm`, `aten` suite) | ✅ 86% file-level / ~97% test-level — see [`KNOWN_ISSUES.md`](KNOWN_ISSUES.md) |
| `torch_mlu_ops.batch_matmul` vs `torch.bmm` | ✅ max diff 0 (fp16, B=4) |
| YOLOv8n inference (Ultralytics) | ✅ matches CPU detections, 5.6× speedup |
| `torch.compile` block-ptr path | 🔴 disabled in v0.1 (deferred to v0.2) |

## Where to file issues

- Patches not applying / build errors → file an issue on this repo
- New torch upstream API drift → contributions welcome (see private
  development repos linked in [`DISCLAIMER.md`](DISCLAIMER.md))
- Anything related to Cambricon hardware / driver / closed-source
  binaries → not in scope here, please contact Cambricon directly

## License

This repo (overlay scripts, CI, docs) is BSD-2-Clause. See
[`LICENSE`](LICENSE). Patch files are derivative of Cambricon's
public PyTorch-derived source (BSD-style); the patches themselves
add to or modify that source and are licensed under the same terms.

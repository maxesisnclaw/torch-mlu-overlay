# Changelog

All notable changes to `torch-mlu-overlay` will be documented in this file.
The format is loosely based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v0.1.1] — 2026-04-29

### Fixed
- `torch/test_dataloader` + `torch/test_pin_memory`:
  initialize `self._in_order` in `_BaseDataLoaderIter` to track
  torch 2.10's new `DataLoader.in_order` parameter.
- `torch_mlu/utils/gpu_migration/migration.py`:
  point at `torch.distributed.fsdp._fully_shard._fsdp_param.FSDPParam`
  instead of the removed `torch.distributed._composable.fsdp` path
  (FSDP2 was relocated in torch 2.10).
- 6 op-test `assertRaisesRegex` patterns loosened to accept both the
  legacy torch 2.5 wording and the new torch 2.10 wording:
  `test_slice`, `test_softshrink`, `test_topk`, `test_gather`,
  `test_dot`, `test_sparse_coo_tensor` — the underlying op kernels
  themselves are unchanged.

### Test pass rate (file-level, full suite re-run pending)
- v0.1.0:  300 / 347  (86%)
- v0.1.1:  308 / 347  (89%)  — 8 file-level fixes from the above

### Still open in v0.1.x
See [`KNOWN_ISSUES.md`](KNOWN_ISSUES.md). Highest-leverage remaining
items: foreach kernel registration (5 files at once), MLU runtime
corner cases (test_event / test_caching_allocator), 5 op-level
TIMEOUTs.

[v0.1.1]: https://github.com/maxesisnclaw/torch-mlu-overlay/releases/tag/v0.1.1

## [v0.1.0] — 2026-04-29

### Added
- Initial public release.
- `torch_mlu` ported from `1.24.1+torch2.5.0` to `1.25.0+torch2.10.0`
  (~32 source files touched + 4 new docs/audit files).
- `torch_mlu_ops` rebuilt against torch 2.10 ABI (1 source file touched).
- `apply.sh` / `rollback.sh` scripts.
- Smoke tests: `smoke_basic.py`, `smoke_batch_matmul.py`, `smoke_yolov8.py`.
- CI workflow that auto-generates patches on tag push and publishes them
  as a release artifact.

### Validated
- ✅ `torch.mlu.is_available()` on MLU370.
- ✅ `torch_mlu_ops.batch_matmul` vs `torch.bmm`: max abs diff 0 (fp16, B=4).
- ✅ YOLOv8n inference: detections match CPU baseline; 5.6× speedup.

### Test coverage
- File-level pass: **300 / 347 (86%)**
- Test-case-level pass: **~97%**
- See [`KNOWN_ISSUES.md`](KNOWN_ISSUES.md) for the breakdown of the
  47 non-passing files (6 of which are environment / missing optional
  deps, not real regressions).

### Known limitations
- 🔴 `torch.compile` block-ptr code path is disabled in this release;
  re-enabling is tracked for v0.2.
- 🟡 `torch 2.10` profiler subsystem rewrite means Cambricon's profiler
  bridge needs full re-adapt; tracked for v0.3.
- 🟡 `_MultiProcessingDataLoaderIter._in_order` / `foreach` / various
  MLU runtime corner-case tests still fail; tracked for v0.1.x.

[v0.1.0]: https://github.com/maxesisnclaw/torch-mlu-overlay/releases/tag/v0.1.0

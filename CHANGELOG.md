# Changelog

All notable changes to `torch-mlu-overlay` will be documented in this file.
The format is loosely based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v0.1.0] — 2026-04-27 (planned)

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

### Known limitations
- 🔴 `torch.compile` block-ptr code path is disabled in this release;
  re-enabling is tracked for v0.2.
- 🟡 Full op-coverage test suite is in-flight at release time; see
  release notes for the snapshot pass/fail grid.

[v0.1.0]: https://github.com/maxesisnclaw/torch-mlu-overlay/releases/tag/v0.1.0

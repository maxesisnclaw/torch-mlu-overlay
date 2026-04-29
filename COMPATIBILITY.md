# Compatibility matrix

## Supported configurations

| Component | Required version | Notes |
|---|---|---|
| Cambricon driver | `>= 6.2.10-1` | older drivers untested |
| CNNL | 1.28.x | 1.28.6 validated |
| CNToolkit | 3.15.x | 3.15.7 validated |
| CNCL | 1.25.0 | newer untested |
| MLU-OPS | 1.4.2 | bundled with MLU370 v1.22.1 release |
| Base container | `cambricon-base/pytorch:v25.01-torch2.5.0-torchmlu1.24.1-ubuntu22.04-py310` | other base images untested |
| Hardware | MLU370-S4 | other MLU370 variants likely OK, untested |

## After applying the overlay

| Component | Version |
|---|---|
| `torch` | `2.10.0+cpu` |
| `torch_mlu` | `1.25.0-torch2.10.0` |
| `torch_mlu_ops` | `1.3.2+pt210` (rebuilt locally) |

## Known limitations

### `torch.compile`

The `block-ptr` code path (Inductor's pointer-arithmetic Triton codegen
for vectorised loads) is **disabled** in v0.1.0. Upstream torch 2.10
restructured `BlockPtrOptions` / `BlockDescriptorOptions` substantially
and Cambricon's prior overrides no longer apply cleanly. The fall-back
non-block-ptr path is functional but slower for compile-mode workloads.
Re-enabling block-ptr is tracked for v0.2.

### Distributed (CNCL)

`process_group_cncl` has been adapted for the torch 2.10 split where
`ProcessGroupStatus` moved out of `TraceUtils.h`, but multi-MLU
distributed training has **not been re-validated** end-to-end in this
release. File an issue if you hit problems.

### `gpu_migration` / FSDP2 path

Cambricon's `torch_mlu/utils/gpu_migration/` overrides for FSDP2 have
been adapted to the new torch 2.10 module layout but **have not been
exercised** under v0.1. We expect potential issues here.

## Op-coverage snapshot (v0.1.0)

The full Cambricon op test suite was run end-to-end on this overlay:

| Category | Files | All-pass | With FAIL/ERR | TIMEOUT |
|---|---:|---:|---:|---:|
| `torch_ops` (core kernels) | 259 | 247 | 7 | 5 |
| `mlu` (runtime integration) | 12 | 6 | 6 | 0 |
| `inductor` | 4 | 2 | 1 | 1 |
| `profiler` | 11 | 3 | 8 | 0 |
| `test_foreach_op` | 5 | 0 | 5 | 0 |
| `custom_ops` | 19 | 14 | 5 | 0 |
| `torch` | 6 | 2 | 4 | 0 |
| `cpp_extension` / `multiprocessing` / `utils` / `distributed` etc. | 31 | 26 | 5 | 0 |
| **Total** | **347** | **300 (86%)** | **41** | **6** |

Test-case-level pass rate (counting individual test methods, not files)
is approximately **97%**. Of the 41 FAIL/ERR files, **6 are missing
optional dependencies** (`torchvision` / `torchaudio`)—not real
regressions; install the matching CPU wheels and they pass.

See [`KNOWN_ISSUES.md`](KNOWN_ISSUES.md) for the full breakdown of
the 47 non-passing files, root cause per file, and which release
each fix is targeted for.

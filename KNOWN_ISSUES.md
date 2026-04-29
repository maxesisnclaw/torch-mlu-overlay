# Known issues — v0.1.0

> 本文件汇总 v0.1.0 op-coverage 测试套件（347 个文件，~2,500 个测试用例）
> 跑完后未通过的 47 个文件，按性质归类。修复进度跟随
> [`ROADMAP.md`](ROADMAP.md) 演进。

## 测试结果概览

| 维度 | 数字 |
|---|---:|
| 文件数 | 347 |
| 全 PASS 文件 | 300（86.5%） |
| 含 FAIL/ERR 文件 | 41 |
| TIMEOUT 文件 | 6 |
| 测试用例总数（粗估） | ~2,500 |
| **测试用例级通过率** | **~97%** |

把"环境缺依赖"这一类剥离掉后：

| | 文件级 | 备注 |
|---|---:|---|
| 真 PASS | 300 | 核心计算路径全部通过 |
| 缺 optional dep（非真 regression） | 6 | `torchvision` / `torchaudio` 缺失，装上即过 |
| **真"功能性问题"剩余** | **41** | 见下分类 |

---

## 分类 1 — 缺 optional 依赖（不是 regression，安装相应包即可）

容器里没装 `torchvision` / `torchaudio` 就会 import 失败：

| 测试文件 | 缺 |
|---|---|
| `custom_ops/test_deform_conv2d` | `torchvision` |
| `custom_ops/test_nms` | `torchvision` |
| `custom_ops/test_nms3D` | `torchvision` |
| `custom_ops/test_roialign` | `torchvision` |
| `custom_ops/test_rnnt_loss` | `torchaudio` |
| `torch/test_save_and_load` | `torchvision` |

> 修复方法：`pip install torchvision==0.25.0+cpu torchaudio==2.10.0+cpu`
> （从 PyTorch CPU index）。本 overlay 不强制安装，避免污染用户环境。

## 分类 2 — torch 2.10 上游 helper API 漂移（真 regression，进 v0.1.x）

torch 2.10 改了某些内部 helper 的 API，torch_mlu 的 monkey-patch 没跟齐：

| 测试文件 | 失败 root cause |
|---|---|
| `torch/test_dataloader` | `_MultiProcessingDataLoaderIter._in_order` 不存在 |
| `torch/test_pin_memory` | 同上 |
| `torch/test_random` | `ValueError: Overflow when unpacking long long`（`torch.manual_seed` 范围检查变化） |
| `cpp_extension/test_mlu_extension` | 测试自身 reference `torch._C._PYBIND11_COMPILER_TYPE`（torch 2.10 已移除） |
| `utils/test_monkey_patch_ref_leak` | `__eq__()` 签名兼容性 |

## 分类 3 — torch 2.10 profiler 大改（v0.3 重做适配）

torch 2.10 重写了 profiler 子系统。Cambricon 的 profiler 桥接代码假设旧
API，需要整体重做。**本类 v0.1.x 不修**：

- `profiler/test_kineto_tb_plugin`（缺 `third_party/kineto_mlu/tb_plugin` 子模块）
- `profiler/test_profiler`
- `profiler/test_profiler_pmu`
- `profiler/test_profiler_record_all`
- `profiler/test_profiler_with_config`
- `profiler/test_profiler_with_mlugraph`
- `profiler/test_profiler_with_mlugraph_and_record_shapes`
- `profiler/test_profiler_with_pmu_and_mlugraph`

## 分类 4 — `torch.compile` 高级路径（v0.2 重做）

| 测试文件 | 备注 |
|---|---|
| `inductor/test_split_rules` | `BlockPtrTest` 失败——v0.1 有意禁用 block-ptr 路径，**预期失败** |
| `inductor/test_configs_filter` | TIMEOUT，codegen 卡在 `'NoneType' has no attribute 'copy'` |

## 分类 5 — foreach kernel 整类失败（进 v0.1.x）

torch 2.10 的 foreach 注册路径与 torch_mlu 当前桥接不匹配：

- `test_foreach_op/test_foreach_binary`
- `test_foreach_op/test_foreach_copy`（`CNNL_STATUS_BAD_PARAM`）
- `test_foreach_op/test_foreach_lerp`
- `test_foreach_op/test_foreach_reduce`
- `test_foreach_op/test_foreach_unary`

## 分类 6 — MLU runtime 集成边角（进 v0.1.x）

| 测试文件 | 现象 |
|---|---|
| `mlu/test_mlu` | 10 处 `CNRT error: invalid argument`，含 `device_index < num_mlus INTERNAL ASSERT FAILED`——单卡环境下访问伪造多卡 path |
| `mlu/test_caching_allocator` | `test_memory_snapshot` / `test_memory_snapshot_script` |
| `mlu/test_event` | `test_synchronize_enable_timing`：测试需要在不带 MLU context 的子进程跑 |
| `mlu/test_lazy_init` | `test_no_mlus`：未抛出预期 RuntimeError |
| `mlu/test_mlu_cndev_based_avail` | cndev 检测路径 |
| `mlu/test_tf32_ctrl` | TF32 开关状态 |

## 分类 7 — 测试基础设施限制（不是真 regression）

需要 `python -m torch.distributed.launch` 之类的多进程启动器，**单进程
直接 `unittest` 必然失败**。我们的 runner 不支持 launcher，所以这两个文件
归为基础设施限制：

- `distributed/test_distributed`（`master_addr is None`）
- `multiprocessing/test_multiprocessing`（同上）

## 分类 8 — torch_ops 异常路径文本不匹配（cosmetic，进 v0.1.x）

torch 2.10 改了少数 error message 字符串，测试用 `assertRaisesRegex`
来检查的就会 fail。**算子本身计算路径没问题**：

| 测试文件 | 类别 |
|---|---|
| `test_slice` | `assertRaisesRegex` 期望文本变了 |
| `test_softshrink` | 同上 |
| `test_topk` | 同上 |
| `test_gather` | 同上 |
| `test_dot` | 设备 mismatch 检查 |
| `test_sparse_coo_tensor` | 设备 mismatch 检查 |
| `test_addmm` | 数值容差 marginal（`0.0031 > 0.003`） |
| `test__transform_bias_rescale_qkv` | 大 tensor edge case |

## 分类 9 — 性能 regression / 算法慢路径（5 个 TIMEOUT，进 v0.1.x）

每个文件超出 600s 单文件 timeout。Log 显示是某个具体 test 函数本身
执行超时，不是 hang/死循环：

| 测试文件 | 卡住的 test |
|---|---|
| `torch_ops/test_mse_loss` | `test_mse_memory_format_combination` |
| `torch_ops/test_packed_lstm` | `test_packed_lstm_training` |
| `torch_ops/test_sort` | `test_sort_out`（前 6 个 PASS） |
| `torch_ops/test_spectral_ops` | 第一个 test 启动前 |
| `torch_ops/test_syncbn` | `test_batch_norm_backward_elemt` |

可能 root cause：torch 2.10 ABI 上某些 CNNL 路径回退到 slow path，
或新版本激活了原本未走的代码分支。

---

## 修复优先级

| 类别 | v0.1.x | v0.2 | v0.3 |
|---|---|---|---|
| 2 — helper API 漂移 | ✅ | | |
| 5 — foreach 整类 | ✅ | | |
| 6 — MLU runtime 边角 | ✅ | | |
| 8 — error message 文本 | ✅ | | |
| 9 — 5 个 TIMEOUT | ✅ | | |
| 4 — `torch.compile` 高级路径 | | ✅ | |
| 3 — profiler 整组重做 | | | ✅ |

`v0.1.x` 各 release 各自挑几类修，每次发版会把"已修"从 KNOWN_ISSUES
移除并写入 CHANGELOG。

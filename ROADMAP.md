# Roadmap

> 本文件描述 `torch-mlu-overlay` 当前距离 v0.1 GA 还差什么、
> 以及距离我们定义的"fully functional"目标还有多远。

## 阶段定义

| 阶段 | 含义 |
|---|---|
| **v0.1.0-rc1** | 当前已发布的 release candidate。证明升级路径可行：torch_mlu 在 torch 2.10 上能 import、核心算子能跑、torch_mlu_ops 能重编、可用 YOLOv8 完成端到端推理。 |
| **v0.1.0 GA** | 首个正式版。op 覆盖测完跑过且失败已分类、fresh 容器端到端复现可用、apply / rollback 路径在干净环境下验证过。 |
| **fully functional** | 终极目标。MLU370 在 torch 2.10 下行为完整、能与 NVIDIA T4 在同版本 torch 2.10 上的端到端表现持平（功能覆盖 + 性能两个维度）。 |

---

## 距离 v0.1.0 GA — 还差什么

### 🔴 GA blocker（必须做）

- [ ] **op coverage suite 跑完**
      `~377` 个测试文件，rc1 截止时跑了 300 / 79%。需要全部跑完，得到最终 pass 率与失败列表。

- [ ] **失败分类整理 → release notes**
      把最终的 FAIL / ERROR / TIMEOUT 拆成三档：
      - **真 regression**：torch 2.10 升级直接引入的，必须修
      - **baseline 既有失败**：torch 2.5 baseline 上原本就挂的，跟我们无关
      - **out-of-scope**：torch 2.10 上游大改的能力（如 profiler 整体重构），v0.1 范畴外

- [ ] **fresh 容器端到端验证 `apply.sh`**
      当前 `apply.sh` 仅在已经做过修改的开发容器上"逻辑通"。GA 前必须：
      1. 启动一个干净的 Cambricon `torch 2.5` 基础容器
      2. `curl release.tar.gz → tar → bash scripts/apply.sh`
      3. `tests/smoke_basic.py` + `smoke_batch_matmul.py` 应当全部通过
      任何 patch reject、build error、smoke fail 都阻塞 GA。

- [ ] **`COMPATIBILITY.md` / `CHANGELOG.md` 用真实数据填充**
      把 op 测试通过率、已确认的限制、已修的问题写实，不留模糊措辞。

### 🟡 推荐做（GA 之前最好完成）

- [ ] **`rollback.sh` 真实验证**
      在 fresh 容器上 apply 后跑 rollback，确认能回到 baseline。
- [ ] **README 顶部加显眼的 "v0.1 已知限制" 段落**
      避免用户应用后期望错位。
- [ ] **release notes 中文版**
      项目主受众是中文社区，主 release notes 也应有中文。

### 🟢 锦上添花（不阻塞 GA）

- [ ] CROSS_REPO_PAT 换成 fine-grained PAT，权限收敛到 3 个 repo。
- [ ] CI 跟进 `actions/checkout` 新版本。

**预估时间**：等测试跑完后，Tier 1 工作约 2-3 小时即可发 GA。

---

## 距离 "fully functional" — 还差什么

### "fully functional" 的判定标准

只有以下四点同时成立才算：

1. **op 测试 100% 通过**（含 distributed、profiler、foreach、cpp_extension、custom_ops、view_chain、inductor 全部子目录）。
2. **`torch.compile` 全路径可用**（含 block-ptr / dynamo / inductor 高级路径），不再有 `v0.1` 里禁用的代码段。
3. **分布式训练验证过**（FSDP / FSDP2 / DDP 在多 MLU370 卡上跑通端到端训练）。
4. **性能 vs NVIDIA T4 持平**：选一组代表性 workload（推理 + 训练），在相同 torch 2.10 上 MLU370 与 T4 的端到端 throughput / latency 处于同一量级。

### 路线图

#### v0.1.x — bug-fix 季

吸收 v0.1.0 GA 之后社区反馈与 op 测试暴露的 regression。
重点修复（基于当前 rc1 测试快照）：

- `mlu/test_event` / `mlu/test_caching_allocator` —— MLU runtime 集成边角
- `test_foreach_op/*` —— foreach kernel 整类失败，需要排查注册路径
- `torch/test_dataloader` / `pin_memory` / `random` / `save_and_load` —— import-time 错误，疑为 helper 模块路径漂移
- `custom_ops` / `cpp_extension` —— C++ 扩展注册路径

#### v0.2 — `torch.compile` 完整路径

- 重写 `BlockPtrOptions` / `BlockDescriptorOptions` 适配层
- 重新启用被禁用的 block-ptr code path
- 修复 `inductor/test_split_rules`、`test_configs_filter` 这类深路径
- 跑一遍 inductor benchmark suite，对比 baseline

#### v0.3 — profiler / distributed 重适配

- 适配 torch 2.10 的新 profiler API（这是上游 torch 2.10 大改的部分，需要重写 Cambricon 端 profiler 桥接）
- 端到端 FSDP / FSDP2 多卡训练验证
- 修复 `gpu_migration/migration.py` 里目前未被 exercise 的 FSDP2 迁移路径

#### v0.4 — 性能基准 + parity 攻坚

- 选一组 workload（候选：ResNet-50 训练 / Llama-7B 推理 / BERT fine-tune / SD inference）
- 用相同 torch 2.10 在 NVIDIA T4 与 MLU370 上各跑一遍，得到 baseline gap
- 按 gap 优先级逐项调优（kernel 选型、stream 编排、dtype 路径、内存分配器）
- 目标：所选 workload 端到端表现处于同一量级（先求量级持平，再求精确数值）

### 距离量化

| 维度 | rc1 现状 | v0.1 GA | fully functional |
|---|---|---|---|
| op file 通过率 | 86%（300/377）| ≥ 90%（含失败已分类）| 100% |
| op test 通过率 | 97%（2208/2277）| ≥ 98%（已知坑修完）| 100% |
| 端到端 `torch.compile` | 仅 non-block-ptr 路径 | 同 rc1 | 全路径 |
| 分布式（FSDP / DDP） | 未验证 | 未验证 | 多卡 train 通 |
| profiler | 整体失败 | 同 rc1 | 完整跟齐 torch 2.10 |
| 性能 vs T4（同 torch 2.10） | 未测 | 未测 | 同量级 |
| **粗略完成度** | **~65%** | **~75%** | **100%** |

完成度数字是经验估计，主要参考：op test 通过率、关键路径是否启用、是否有性能基准。

---

## 不在本项目范畴

为了让范围清晰，明确以下内容**不**计入本 ROADMAP：

- 寒武纪闭源组件（`_MLUC.so`、`libcnnl.so`、`libcncl.so`、`cncc` 等）的修改或重发布。
- 上层推理 / 服务框架（任何 LLM serving stack）。本项目只做 PyTorch 扩展层，框架层适配是独立工作。
- 寒武纪硬件 / 驱动相关问题：请通过寒武纪官方渠道反馈。

---

## 反馈

任何路线图调整建议、新失败 case、性能数据贡献，欢迎在
[Issues](https://github.com/maxesisnclaw/torch-mlu-overlay/issues) 提出。

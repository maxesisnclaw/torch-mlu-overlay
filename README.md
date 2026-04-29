# torch-mlu-overlay

> **面向寒武纪 MLU370 的 PyTorch 2.10 升级补丁包。**
> 以你已有的寒武纪 `torch 2.5` 基础镜像为底，应用本仓库发布的补丁，
> 即可在 MLU370 上获得可用的 `torch 2.10 + torch_mlu 1.25 + torch_mlu_ops 1.3.2` 工作栈。

> 本项目仅含**文本补丁与脚本**，**不**重发布寒武纪闭源二进制。
> 英文版见 [`README.EN.md`](README.EN.md)。

## 这是什么 / 不是什么

这是一个 **社区维护的升级 overlay**，把寒武纪 MLU370 软件栈向新版本 PyTorch 推进。

- ✅ 我们发布 **补丁文件 + 脚本**（基于寒武纪公开源码生成的纯文本 diff）
- ❌ 我们**不**发布寒武纪二进制（`_MLUC.so`、`libcnnl.so`、`libcncl.so`、`cncc` 等）
- ❌ 本项目与寒武纪科技 (Cambricon) 无任何官方关联，**不是**寒武纪官方发布

应用前，你必须自行准备一个可用的寒武纪 `torch 2.5` 基础容器
（如 `cambricon-base/pytorch:v25.01-torch2.5.0-torchmlu1.24.1-ubuntu22.04-py310`），
本 overlay 在其之上叠加我们的修改。

完整 IP / 来源声明详见 [`DISCLAIMER.md`](DISCLAIMER.md)，路线图详见 [`ROADMAP.md`](ROADMAP.md)，已知问题详见 [`KNOWN_ISSUES.md`](KNOWN_ISSUES.md)。

## 为什么有这个项目

寒武纪 MLU370 平台目前公开发布的 `torch_mlu` 最新基线是 **`1.24.1` 配 `torch 2.5.0`**，
而 PyTorch 上游已经发布到 `torch 2.10`。本 overlay 把 MLU370 软件栈
向前移植到新版本 PyTorch，方便仍在使用 MLU370 的用户继续跟进上游迭代。

v0.1 把 `torch_mlu` 升到 `torch 2.10`。

## 快速开始

在一个已经跑起来的寒武纪 `torch 2.5` 容器内执行（需要联网下载 wheel）：

```bash
# 1. 下载最新 release
RELEASE=v0.1.0  # 见 https://github.com/maxesisnclaw/torch-mlu-overlay/releases
curl -L -o overlay.tar.gz \
  https://github.com/maxesisnclaw/torch-mlu-overlay/releases/download/${RELEASE}/release.tar.gz
tar xzf overlay.tar.gz && cd overlay

# 2. 应用 overlay
bash scripts/apply.sh

# 3. 自检
python tests/smoke_basic.py
python tests/smoke_batch_matmul.py
```

`apply.sh` 做以下事情：

1. 校验当前容器确实是寒武纪 `torch_mlu 1.24.1 + torch 2.5.0` 基础镜像
2. 备份 `site-packages/torch_mlu` / `site-packages/torch_mlu_ops`
   和 `/torch/src/torch_mlu/` / `/workspace/torch_mlu_ops-v1.3.2/` 源码树
3. `pip install torch==2.10.0+cpu`（PyTorch 官方 CPU index）
4. 把 `patches/torch_mlu/*.patch` 应用到 `/torch/src/torch_mlu/`
5. 在 `/torch/src/torch_mlu/` 下 `python setup.py build_ext --inplace`
   重新编译 `torch_mlu` C++ 部分（针对新 torch 2.10 ABI）
6. 把重编出来的 `.so` 与已 patch 的 `.py` 同步到 `site-packages/torch_mlu`
7. 把 `patches/torch_mlu_ops/*.patch` 应用到 torch_mlu_ops 源码树，
   并 `python setup.py build_ext --inplace` 重新编译 `_C.so`
8. 把重编出来的 `torch_mlu_ops` 装回 `site-packages`

回滚：`bash scripts/rollback.sh <备份目录>` 即可还原到原始状态
（备份目录路径在 apply 完成后会打印出来）。

## 应用后你能拿到

| 组件 | 之前 | 之后 |
|---|---|---|
| `torch` | 2.5.0+cpu | **2.10.0+cpu** |
| `torch_mlu` | 1.24.1-torch2.5.0 | **1.25.0-torch2.10.0** |
| `torch_mlu_ops` | 1.3.2+pt25 | **1.3.2+pt210**（本地重编） |

### v0.1.0 已验证场景

| 场景 | 状态 |
|---|---|
| `torch.mlu.is_available()` + 设备探测 | ✅ |
| 基础算子（`torch.bmm`、aten 套件） | ✅ 文件级 86% / 测试级 97%（[`KNOWN_ISSUES.md`](KNOWN_ISSUES.md)） |
| `torch_mlu_ops.batch_matmul` vs `torch.bmm` | ✅ max diff 0（fp16, B=4） |
| YOLOv8n 推理（Ultralytics） | ✅ 检测结果与 CPU 基线一致，5.6× 加速 |
| `torch.compile` block-ptr 路径 | 🔴 v0.1 暂禁用，v0.2 重新启用 |

## 反馈渠道

- 补丁应用失败 / 重编报错 → 在本仓库提 issue
- 上游 torch 新一轮 API 漂移导致需要新增补丁 → 欢迎贡献
  （维护用的私有源仓地址见 [`DISCLAIMER.md`](DISCLAIMER.md)）
- 寒武纪硬件 / 驱动 / 闭源组件相关问题 → 不在本项目范畴，
  请直接联系寒武纪官方渠道

## License

本仓库的 overlay 脚本、CI、文档 采用 **BSD-2-Clause**，
详见 [`LICENSE`](LICENSE)。

补丁文件源自寒武纪基于 BSD 风格许可的 PyTorch 衍生源码，
其修改部分继承相同许可。

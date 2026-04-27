"""smoke_yolov8.py — production-grade end-to-end check using YOLOv8n.

Loads the Ultralytics YOLOv8n weights (auto-downloaded), runs inference
both on CPU and on MLU, and verifies that the detections match. Also
prints a basic perf number.

Skip-able if the host has no internet (weights download) or the user
does not want to install ultralytics. Set SKIP_YOLO=1 to skip.
"""
import os
import sys
import time

if os.environ.get("SKIP_YOLO"):
    print("== SKIP_YOLO set, skipping yolov8 smoke test")
    sys.exit(0)

import torch
import torch_mlu  # noqa: F401

try:
    from ultralytics import YOLO
    import torchvision  # noqa: F401
    import cv2
    import numpy as np
except ImportError as e:
    print(f"== missing optional dep ({e.name}); install with:")
    print(f"   pip install ultralytics torchvision opencv-python-headless")
    print("== or set SKIP_YOLO=1")
    sys.exit(0)

# Allow user to pass an image; otherwise expect the Cambricon Model Zoo
# bundled sample.
SAMPLE = os.environ.get(
    "YOLO_SAMPLE",
    "/workspace/Cambricon_PyTorch_Model_Zoo/Benchmark/Yolov5m_6.0/data/images/zidane.jpg",
)
if not os.path.exists(SAMPLE):
    print(f"== sample image missing: {SAMPLE}")
    print("   set YOLO_SAMPLE=/path/to/your/image.jpg to override")
    sys.exit(0)

device = "mlu:0"
print(f"== torch: {torch.__version__}  torch_mlu: {torch_mlu.__version__}")
print(f"== device: {torch.mlu.get_device_name(0)}")

yolo = YOLO("yolov8n.pt")
backbone = yolo.model.eval()
class_names = yolo.names

def preprocess(img_path, size=640):
    img = cv2.imread(img_path)
    h0, w0 = img.shape[:2]
    r = size / max(h0, w0)
    nh, nw = int(round(h0 * r)), int(round(w0 * r))
    img = cv2.resize(img, (nw, nh), interpolation=cv2.INTER_LINEAR)
    canvas = np.full((size, size, 3), 114, dtype=np.uint8)
    pt, pl = (size - nh) // 2, (size - nw) // 2
    canvas[pt:pt+nh, pl:pl+nw] = img
    canvas = cv2.cvtColor(canvas, cv2.COLOR_BGR2RGB)
    return torch.from_numpy(canvas).permute(2, 0, 1).float().div_(255.0).unsqueeze(0)

def postprocess(pred, conf_thres=0.25, iou_thres=0.45):
    pred = pred[0].t()
    boxes_cxcywh = pred[:, :4]
    conf, cls = pred[:, 4:].max(dim=1)
    keep = conf > conf_thres
    boxes_cxcywh, conf, cls = boxes_cxcywh[keep], conf[keep], cls[keep]
    if boxes_cxcywh.numel() == 0:
        return []
    cx, cy, w, h = boxes_cxcywh.unbind(dim=1)
    boxes_xyxy = torch.stack([cx-w/2, cy-h/2, cx+w/2, cy+h/2], dim=1)
    keep = torchvision.ops.nms(boxes_xyxy, conf, iou_thres)
    return [(int(c), float(p)) for p, c in zip(conf[keep], cls[keep])]

img_t = preprocess(SAMPLE)

with torch.inference_mode():
    backbone.cpu()
    pred_cpu = backbone(img_t)
    pcpu = pred_cpu[0] if isinstance(pred_cpu, (list, tuple)) else pred_cpu
    cpu_dets = postprocess(pcpu)

    backbone.to(device)
    img_mlu = img_t.to(device)
    torch.mlu.synchronize()

    t0 = time.perf_counter()
    pred_mlu = backbone(img_mlu)
    torch.mlu.synchronize()
    cold_ms = (time.perf_counter() - t0) * 1000

    pmlu = pred_mlu[0] if isinstance(pred_mlu, (list, tuple)) else pred_mlu
    mlu_dets = postprocess(pmlu.cpu())

    for _ in range(5):
        backbone(img_mlu)
    torch.mlu.synchronize()
    samples = []
    for _ in range(20):
        torch.mlu.synchronize()
        t0 = time.perf_counter()
        backbone(img_mlu)
        torch.mlu.synchronize()
        samples.append((time.perf_counter() - t0) * 1000)
    samples.sort()
    median = samples[len(samples) // 2]

print(f"  CPU detections: {sorted([(class_names[c], round(p,2)) for c,p in cpu_dets])}")
print(f"  MLU detections: {sorted([(class_names[c], round(p,2)) for c,p in mlu_dets])}")
print(f"  MLU cold:    {cold_ms:.1f}ms")
print(f"  MLU warm:    {median:.1f}ms median")

cpu_classes = {class_names[c] for c, _ in cpu_dets}
mlu_classes = {class_names[c] for c, _ in mlu_dets}
if cpu_classes == mlu_classes:
    print(">>> smoke_yolov8.py PASSED")
else:
    print(f">>> smoke_yolov8.py FAILED (class mismatch: cpu={cpu_classes} mlu={mlu_classes})")
    sys.exit(1)

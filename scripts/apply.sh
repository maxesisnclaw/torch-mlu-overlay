#!/usr/bin/env bash
# torch-mlu-overlay apply script.
# Runs inside a Cambricon torch_mlu 1.24.1 + torch 2.5.0 base container.
#
# Flow:
#   1. Sanity check the base.
#   2. Backup current site-packages and source trees.
#   3. Install torch 2.10.0+cpu from PyTorch CPU index.
#   4. Apply patches/torch_mlu/*.patch  to /torch/src/torch_mlu/.
#   5. Rebuild torch_mlu C++ via setup.py build_ext --inplace.
#   6. Sync rebuilt .so + patched .py into site-packages.
#   7. Apply patches/torch_mlu_ops/*.patch to /workspace/torch_mlu_ops-v1.3.2/.
#   8. Rebuild torch_mlu_ops _C.so and install into site-packages.
#   9. Smoke verify imports.
set -euo pipefail

# ---------- locate paths ----------
PYBIN="${PYBIN:-python3}"
SITE_PACKAGES=$($PYBIN -c "import sysconfig; print(sysconfig.get_paths()['purelib'])")
TORCH_MLU_DST="$SITE_PACKAGES/torch_mlu"
TORCH_MLU_OPS_DST="$SITE_PACKAGES/torch_mlu_ops"
TORCH_MLU_SRC="${TORCH_MLU_SRC:-/torch/src/torch_mlu}"
TMO_SRC="${TMO_SRC:-/workspace/torch_mlu_ops-v1.3.2}"
PATCHES_DIR="$(cd "$(dirname "$0")/.." && pwd)/patches"
BACKUP_DIR="${BACKUP_DIR:-/tmp/torch-mlu-overlay-backup-$(date +%Y%m%d-%H%M%S)}"
MAX_JOBS="${MAX_JOBS:-8}"

echo "============================================"
echo " torch-mlu-overlay apply"
echo "============================================"
echo "  python:                $PYBIN"
echo "  site-packages:         $SITE_PACKAGES"
echo "  torch_mlu source:      $TORCH_MLU_SRC"
echo "  torch_mlu_ops source:  $TMO_SRC"
echo "  patches:               $PATCHES_DIR"
echo "  backup:                $BACKUP_DIR"
echo "  build jobs:            $MAX_JOBS"
echo

# ---------- 1. base sanity ----------
echo "[1/9] Verify base container"
BASE_TM_VER=$($PYBIN -c "import torch_mlu; print(torch_mlu.__version__)" 2>/dev/null || echo "MISSING")
BASE_TORCH_VER=$($PYBIN -c "import torch; print(torch.__version__)" 2>/dev/null || echo "MISSING")
echo "  current torch:     $BASE_TORCH_VER"
echo "  current torch_mlu: $BASE_TM_VER"
case "$BASE_TM_VER" in
  1.24.1*torch2.5.0*) ;;
  *)
    echo "ERROR: expected torch_mlu 1.24.1-torch2.5.0 base, found '$BASE_TM_VER'."
    echo "       This overlay only supports the Cambricon v25.01 base image."
    exit 1
    ;;
esac
[ -d "$TORCH_MLU_SRC" ] || { echo "ERROR: torch_mlu source dir not found at $TORCH_MLU_SRC"; exit 1; }
[ -d "$TMO_SRC" ]       || { echo "ERROR: torch_mlu_ops source dir not found at $TMO_SRC"; exit 1; }

# ---------- 2. backup ----------
echo "[2/9] Backup site-packages and source trees"
mkdir -p "$BACKUP_DIR"
cp -a "$TORCH_MLU_DST"     "$BACKUP_DIR/torch_mlu_site-packages"
cp -a "$TORCH_MLU_OPS_DST" "$BACKUP_DIR/torch_mlu_ops_site-packages"
cp -a "$TORCH_MLU_SRC"     "$BACKUP_DIR/torch_mlu_src"
cp -a "$TMO_SRC"           "$BACKUP_DIR/torch_mlu_ops_src"
echo "  backup written to $BACKUP_DIR"

# ---------- 3. install torch 2.10 ----------
echo "[3/9] Install torch 2.10.0+cpu"
$PYBIN -m pip install --no-cache-dir \
  torch==2.10.0 \
  --index-url https://download.pytorch.org/whl/cpu

# ---------- 4. apply torch_mlu patches to source dir ----------
echo "[4/9] Apply torch_mlu patches → $TORCH_MLU_SRC"
cd "$TORCH_MLU_SRC"
for patch in "$PATCHES_DIR"/torch_mlu/*.patch; do
  [ -e "$patch" ] || { echo "  no torch_mlu patches found"; break; }
  echo "  $(basename "$patch")"
  patch -p1 --no-backup-if-mismatch < "$patch"
done

# ---------- 5. rebuild torch_mlu C++ ----------
echo "[5/9] Rebuild torch_mlu against torch 2.10  (USE_PROFILE=OFF; profiler stays broken in v0.1, see KNOWN_ISSUES.md)"
cd "$TORCH_MLU_SRC"
USE_PROFILE=OFF MAX_JOBS=$MAX_JOBS TORCH_DEVICE_BACKEND_AUTOLOAD=0 \
  $PYBIN setup.py build_ext --inplace

# ---------- 6. sync to site-packages ----------
echo "[6/9] Sync rebuilt torch_mlu into site-packages"
cd "$TORCH_MLU_SRC/torch_mlu"
# fresh-built shared libraries
cp _MLUC.cpython-310-x86_64-linux-gnu.so          "$TORCH_MLU_DST/"
cp csrc/lib/libtorch_mlu.so                        "$TORCH_MLU_DST/csrc/lib/"
cp csrc/lib/libtorch_mlu_python.so                 "$TORCH_MLU_DST/csrc/lib/"
cp csrc/lib/libbangc.so                            "$TORCH_MLU_DST/csrc/lib/"
# patched Python files (preserve directory structure, only .py)
rsync -a --include='*/' --include='*.py' --exclude='*' \
  "$TORCH_MLU_SRC/torch_mlu/" "$TORCH_MLU_DST/"

# ---------- 7. apply torch_mlu_ops patches ----------
echo "[7/9] Apply torch_mlu_ops patches → $TMO_SRC"
cd "$TMO_SRC"
for patch in "$PATCHES_DIR"/torch_mlu_ops/*.patch; do
  [ -e "$patch" ] || { echo "  no torch_mlu_ops patches found"; break; }
  echo "  $(basename "$patch")"
  patch -p1 --no-backup-if-mismatch < "$patch"
done

# ---------- 8. rebuild torch_mlu_ops ----------
echo "[8/9] Rebuild torch_mlu_ops against torch 2.10"
cd "$TMO_SRC"
MAX_JOBS=$MAX_JOBS $PYBIN setup.py build_ext --inplace
cp torch_mlu_ops/_C.cpython-310-x86_64-linux-gnu.so "$TORCH_MLU_OPS_DST/"
cp torch_mlu_ops/_version.py                        "$TORCH_MLU_OPS_DST/"

# ---------- 9. smoke verify ----------
echo "[9/9] Smoke verify"
$PYBIN - <<'PY'
import torch, torch_mlu, torch_mlu_ops as tmo
print(f"  torch:          {torch.__version__}")
print(f"  torch_mlu:      {torch_mlu.__version__}")
print(f"  torch_mlu_ops:  {tmo.__version__}")
print(f"  mlu available:  {torch.mlu.is_available()}")
assert torch.__version__.startswith("2.10."), "torch upgrade failed"
assert "torch2.10.0" in torch_mlu.__version__, "torch_mlu rebuild failed"
assert "pt210" in tmo.__version__, "torch_mlu_ops rebuild failed"
assert torch.mlu.is_available(), "MLU device not available"
print("  >>> apply.sh succeeded")
PY

echo
echo "Done. Backup retained at: $BACKUP_DIR"
echo "To rollback: bash scripts/rollback.sh '$BACKUP_DIR'"

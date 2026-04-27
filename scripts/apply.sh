#!/usr/bin/env bash
# torch-mlu-overlay apply script.
# Run inside a Cambricon torch_mlu 1.24.1 + torch 2.5.0 base container.
set -euo pipefail

# ---------- locate paths ----------
PYBIN="${PYBIN:-python3}"
SITE_PACKAGES=$($PYBIN -c "import sysconfig; print(sysconfig.get_paths()['purelib'])")
TORCH_MLU_DIR="$SITE_PACKAGES/torch_mlu"
TORCH_MLU_OPS_DIR="$SITE_PACKAGES/torch_mlu_ops"
TMO_SRC_DIR="${TMO_SRC_DIR:-/workspace/torch_mlu_ops-v1.3.2}"
PATCHES_DIR="$(cd "$(dirname "$0")/.." && pwd)/patches"
BACKUP_DIR="${BACKUP_DIR:-/tmp/torch-mlu-overlay-backup-$(date +%Y%m%d-%H%M%S)}"

echo "============================================"
echo " torch-mlu-overlay apply"
echo "============================================"
echo "  site-packages:    $SITE_PACKAGES"
echo "  torch_mlu_ops src: $TMO_SRC_DIR"
echo "  patches dir:      $PATCHES_DIR"
echo "  backup dir:       $BACKUP_DIR"
echo

# ---------- sanity: base version ----------
echo "[1/7] Verify base container"
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

# ---------- backup ----------
echo "[2/7] Backup existing site-packages and source tree"
mkdir -p "$BACKUP_DIR"
cp -r "$TORCH_MLU_DIR"     "$BACKUP_DIR/torch_mlu"
cp -r "$TORCH_MLU_OPS_DIR" "$BACKUP_DIR/torch_mlu_ops"
if [ -d "$TMO_SRC_DIR" ]; then
  cp -r "$TMO_SRC_DIR" "$BACKUP_DIR/torch_mlu_ops_src"
fi
echo "  backup written to $BACKUP_DIR"

# ---------- pip install torch 2.10 ----------
echo "[3/7] Install torch 2.10.0+cpu"
$PYBIN -m pip install --no-cache-dir \
  torch==2.10.0 \
  --index-url https://download.pytorch.org/whl/cpu

# ---------- apply torch_mlu patches ----------
echo "[4/7] Apply torch_mlu patches to $TORCH_MLU_DIR"
cd "$TORCH_MLU_DIR"
for patch in "$PATCHES_DIR"/torch_mlu/*.patch; do
  [ -e "$patch" ] || { echo "  no torch_mlu patches found"; break; }
  echo "  applying $(basename "$patch")"
  patch -p2 --no-backup-if-mismatch < "$patch"
done

# ---------- apply torch_mlu_ops patches + rebuild ----------
echo "[5/7] Apply torch_mlu_ops patches to $TMO_SRC_DIR"
cd "$TMO_SRC_DIR"
for patch in "$PATCHES_DIR"/torch_mlu_ops/*.patch; do
  [ -e "$patch" ] || { echo "  no torch_mlu_ops patches found"; break; }
  echo "  applying $(basename "$patch")"
  patch -p1 --no-backup-if-mismatch < "$patch"
done

echo "[6/7] Rebuild torch_mlu_ops against torch 2.10"
cd "$TMO_SRC_DIR"
MAX_JOBS="${MAX_JOBS:-8}" $PYBIN setup.py build_ext --inplace
cp torch_mlu_ops/_C.cpython-310-x86_64-linux-gnu.so "$TORCH_MLU_OPS_DIR/"
cp torch_mlu_ops/_version.py                       "$TORCH_MLU_OPS_DIR/"

# ---------- verify ----------
echo "[7/7] Smoke verify"
$PYBIN - <<'PY'
import torch, torch_mlu, torch_mlu_ops as tmo
print(f"  torch:          {torch.__version__}")
print(f"  torch_mlu:      {torch_mlu.__version__}")
print(f"  torch_mlu_ops:  {tmo.__version__}")
print(f"  mlu available:  {torch.mlu.is_available()}")
assert torch.__version__.startswith("2.10."), "torch upgrade failed"
assert "torch2.10.0" in torch_mlu.__version__, "torch_mlu patch failed"
assert "pt210" in tmo.__version__, "torch_mlu_ops rebuild failed"
print("  >>> apply.sh succeeded")
PY

echo
echo "Done. Backup retained at: $BACKUP_DIR"
echo "To rollback:  bash scripts/rollback.sh '$BACKUP_DIR'"

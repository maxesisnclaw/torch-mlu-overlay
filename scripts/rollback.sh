#!/usr/bin/env bash
# Restore the original Cambricon torch 2.5 state from a backup created
# by apply.sh.
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: bash rollback.sh <backup-dir>"
  echo "  the backup dir is the one printed at the end of apply.sh."
  exit 1
fi
BACKUP_DIR="$1"
[ -d "$BACKUP_DIR" ] || { echo "ERROR: backup dir not found: $BACKUP_DIR"; exit 1; }

PYBIN="${PYBIN:-python3}"
SITE_PACKAGES=$($PYBIN -c "import sysconfig; print(sysconfig.get_paths()['purelib'])")
TORCH_MLU_DST="$SITE_PACKAGES/torch_mlu"
TORCH_MLU_OPS_DST="$SITE_PACKAGES/torch_mlu_ops"
TORCH_MLU_SRC="${TORCH_MLU_SRC:-/torch/src/torch_mlu}"
TMO_SRC="${TMO_SRC:-/workspace/torch_mlu_ops-v1.3.2}"

echo "[1/5] Restore site-packages/torch_mlu"
rm -rf "$TORCH_MLU_DST"
cp -a "$BACKUP_DIR/torch_mlu_site-packages" "$TORCH_MLU_DST"

echo "[2/5] Restore site-packages/torch_mlu_ops"
rm -rf "$TORCH_MLU_OPS_DST"
cp -a "$BACKUP_DIR/torch_mlu_ops_site-packages" "$TORCH_MLU_OPS_DST"

echo "[3/5] Restore $TORCH_MLU_SRC"
rm -rf "$TORCH_MLU_SRC"
cp -a "$BACKUP_DIR/torch_mlu_src" "$TORCH_MLU_SRC"

echo "[4/5] Restore $TMO_SRC"
rm -rf "$TMO_SRC"
cp -a "$BACKUP_DIR/torch_mlu_ops_src" "$TMO_SRC"

echo "[5/5] Reinstall torch 2.5.0+cpu"
$PYBIN -m pip install --no-cache-dir \
  torch==2.5.0 \
  --index-url https://download.pytorch.org/whl/cpu

echo
echo "Done. Verify with:  python -c 'import torch, torch_mlu; print(torch.__version__, torch_mlu.__version__)'"
echo "Expected: 2.5.0+cpu  1.24.1-torch2.5.0"

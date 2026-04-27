#!/usr/bin/env bash
# Restore the original Cambricon torch 2.5 state.
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: bash rollback.sh <backup-dir>"
  exit 1
fi
BACKUP_DIR="$1"
[ -d "$BACKUP_DIR" ] || { echo "ERROR: backup dir not found: $BACKUP_DIR"; exit 1; }

PYBIN="${PYBIN:-python3}"
SITE_PACKAGES=$($PYBIN -c "import sysconfig; print(sysconfig.get_paths()['purelib'])")
TMO_SRC_DIR="${TMO_SRC_DIR:-/workspace/torch_mlu_ops-v1.3.2}"

echo "[1/3] Restore site-packages/torch_mlu"
rm -rf "$SITE_PACKAGES/torch_mlu"
cp -r "$BACKUP_DIR/torch_mlu" "$SITE_PACKAGES/torch_mlu"

echo "[2/3] Restore site-packages/torch_mlu_ops"
rm -rf "$SITE_PACKAGES/torch_mlu_ops"
cp -r "$BACKUP_DIR/torch_mlu_ops" "$SITE_PACKAGES/torch_mlu_ops"

if [ -d "$BACKUP_DIR/torch_mlu_ops_src" ]; then
  echo "[3/3] Restore $TMO_SRC_DIR"
  rm -rf "$TMO_SRC_DIR"
  cp -r "$BACKUP_DIR/torch_mlu_ops_src" "$TMO_SRC_DIR"
fi

echo "[4/4] Reinstall torch 2.5.0+cpu"
$PYBIN -m pip install --no-cache-dir torch==2.5.0+cpu \
  --index-url https://download.pytorch.org/whl/cpu

echo "Done. Verify with:  python -c 'import torch, torch_mlu; print(torch.__version__, torch_mlu.__version__)'"

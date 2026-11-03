#!/usr/bin/env bash
# Run from any directory. Never reset or overwrite an existing upstream checkout.
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
export UV_CACHE_DIR="${UV_CACHE_DIR:-$ROOT/.cache/uv}"
command -v uv >/dev/null || { echo 'Install uv first: https://docs.astral.sh/uv/getting-started/installation/' >&2; exit 1; }
PYTHON="${BANK_PYTHON:-python3.12}"
"$PYTHON" -c 'import sys; assert sys.version_info[:2] == (3, 12), "Python 3.12 required for this tested setup"'
UPSTREAM="$("$PYTHON" -c 'import json; print(json.load(open("configs/upstream.json"))["directory"])')"
COMMIT="$("$PYTHON" -c 'import json; print(json.load(open("configs/upstream.json"))["commit"])')"
URL="$("$PYTHON" -c 'import json; print(json.load(open("configs/upstream.json"))["repository"])')"
if [[ ! -e "$UPSTREAM" ]]; then
  mkdir -p "$(dirname -- "$UPSTREAM")"
  git clone --no-checkout "$URL" "$UPSTREAM"
  git -C "$UPSTREAM" checkout --detach "$COMMIT"
fi
[[ "$(git -C "$UPSTREAM" rev-parse HEAD)" == "$COMMIT" ]] || { echo 'Upstream commit mismatch; preserve existing work and inspect it manually.' >&2; exit 1; }
[[ -z "$(git -C "$UPSTREAM" status --porcelain --untracked-files=normal)" ]] || { echo 'Upstream checkout has changes; inspect before setup.' >&2; exit 1; }
if [[ ! -d .venv ]]; then
  uv venv --python "$PYTHON" .venv
fi
.venv/bin/python -c 'import sys; assert sys.version_info[:2] == (3, 12)'
uv pip sync --python .venv/bin/python --require-hashes requirements-bank.lock
uv pip check --python .venv/bin/python
echo 'Dependencies ready. Run: .venv/bin/python scripts/smoke_bank_transfer.py'

#!/usr/bin/env bash
# Generate TypeScript types from packages/api-contract/openapi.yaml
# into packages/api-client/src/generated/types.ts via openapi-typescript.
# Le fichier produit est commité — voir packages/api-client/CLAUDE.md.
#
# Override paths with env vars OPENAPI_SPEC / OUTPUT_PATH if needed.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

OPENAPI_SPEC="${OPENAPI_SPEC:-$REPO_ROOT/packages/api-contract/openapi.yaml}"
OUTPUT_PATH="${OUTPUT_PATH:-$REPO_ROOT/packages/api-client/src/generated/types.ts}"
OPENAPI_TS_VERSION="${OPENAPI_TS_VERSION:-7.4.4}"

if [[ ! -f "$OPENAPI_SPEC" ]]; then
  echo "error: OpenAPI spec not found at $OPENAPI_SPEC" >&2
  echo "       run \`pnpm openapi:generate\` first." >&2
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT_PATH")"

if command -v pnpm >/dev/null 2>&1; then
  RUNNER=(pnpm dlx "openapi-typescript@$OPENAPI_TS_VERSION")
elif command -v npx >/dev/null 2>&1; then
  RUNNER=(npx --yes "openapi-typescript@$OPENAPI_TS_VERSION")
else
  echo "error: neither pnpm nor npx is available on PATH" >&2
  exit 1
fi

echo "→ generating $OUTPUT_PATH from $OPENAPI_SPEC"
"${RUNNER[@]}" "$OPENAPI_SPEC" --output "$OUTPUT_PATH"
echo "✓ wrote $OUTPUT_PATH"

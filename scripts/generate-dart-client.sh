#!/usr/bin/env bash
# Generate the Dart API client for the mobile app from packages/api-contract/openapi.yaml.
# Uses openapi-generator-cli (dart-dio generator) — the mobile app uses Dio.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

OPENAPI_SPEC="${REPO_ROOT}/packages/api-contract/openapi.yaml"
OUTPUT_DIR="${REPO_ROOT}/apps/mobile/lib/gen/openapi"
GENERATOR="dart-dio"
PACKAGE_NAME="piloo_api_client"

if [[ ! -f "${OPENAPI_SPEC}" ]]; then
  echo "error: OpenAPI spec not found at ${OPENAPI_SPEC}" >&2
  echo "hint: run 'pnpm --filter @piloo/api-contract generate' first." >&2
  exit 1
fi

if command -v openapi-generator-cli >/dev/null 2>&1; then
  RUNNER=("openapi-generator-cli")
elif command -v npx >/dev/null 2>&1; then
  RUNNER=("npx" "--yes" "@openapitools/openapi-generator-cli")
elif command -v pnpm >/dev/null 2>&1; then
  RUNNER=("pnpm" "dlx" "@openapitools/openapi-generator-cli")
else
  echo "error: need openapi-generator-cli, npx, or pnpm available on PATH." >&2
  exit 1
fi

echo "→ regenerating Dart client into ${OUTPUT_DIR}"
rm -rf "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"

"${RUNNER[@]}" generate \
  --input-spec "${OPENAPI_SPEC}" \
  --generator-name "${GENERATOR}" \
  --output "${OUTPUT_DIR}" \
  --package-name "${PACKAGE_NAME}" \
  --additional-properties=pubName="${PACKAGE_NAME}",pubLibrary="${PACKAGE_NAME}.api",nullableFields=true

echo "→ Dart client written to ${OUTPUT_DIR}"

# Build_runner : génère les .g.dart immutables (built_value + json_serializable)
# pour les modèles. Étape obligatoire — sans ça les imports du package échouent.
# `--delete-conflicting-outputs` peut surfaicher un warning dans les versions
# récentes de build_runner — non bloquant.
echo "→ running build_runner inside the generated package"
(
  cd "${OUTPUT_DIR}"
  if command -v flutter >/dev/null 2>&1; then
    flutter pub get
    dart run build_runner build --delete-conflicting-outputs
  else
    dart pub get
    dart run build_runner build --delete-conflicting-outputs
  fi
)
echo "✓ Dart client ready (models + .g.dart built)"

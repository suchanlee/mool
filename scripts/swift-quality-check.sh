#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

mode="${1:-staged}"
if [[ "$mode" != "staged" && "$mode" != "all" ]]; then
  echo "Usage: $0 [staged|all]" >&2
  exit 2
fi

swift_files=()
if [[ "$mode" == "all" ]]; then
  while IFS= read -r file; do
    swift_files+=("$file")
  done < <(rg --files Mool MoolTests MoolUITests -g '*.swift')
else
  while IFS= read -r file; do
    swift_files+=("$file")
  done < <(git diff --cached --name-only --diff-filter=ACMR -- '*.swift')
fi

if [[ "${#swift_files[@]}" -eq 0 ]]; then
  echo "No Swift files to check."
  exit 0
fi

missing_tools=()
for tool in swiftformat swiftlint; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    missing_tools+=("$tool")
  fi
done

if [[ "${#missing_tools[@]}" -gt 0 ]]; then
  printf 'Missing required tools: %s\n' "${missing_tools[*]}" >&2
  echo "Install with: brew install swiftformat swiftlint" >&2
  exit 1
fi

echo "Running swiftformat on ${#swift_files[@]} Swift file(s)..."
swiftformat --config "$repo_root/.swiftformat" "${swift_files[@]}"

if [[ "$mode" == "staged" ]]; then
  git add -- "${swift_files[@]}"
fi

echo "Running swiftlint on ${#swift_files[@]} Swift file(s)..."
export SCRIPT_INPUT_FILE_COUNT="${#swift_files[@]}"
for i in "${!swift_files[@]}"; do
  export "SCRIPT_INPUT_FILE_$i=${swift_files[$i]}"
done

swiftlint lint --strict --use-script-input-files --config "$repo_root/.swiftlint.yml"
echo "Swift quality checks passed."

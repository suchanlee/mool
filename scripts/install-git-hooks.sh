#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

git config core.hooksPath .githooks
chmod +x .githooks/pre-commit scripts/swift-quality-check.sh scripts/install-git-hooks.sh

echo "Installed git hooks path: .githooks"
echo "Pre-commit now runs SwiftFormat + SwiftLint on staged Swift files."

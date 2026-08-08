#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

flutter analyze
dart run dependency_validator

#!/bin/bash
# Dependency audit helper (Phase 8D): outdated packages + licence listing.
set -e
echo "== dart pub outdated =="
dart pub outdated || true
echo
echo "== direct dependency licences (from pub cache) =="
# Prints each direct dependency's LICENSE first line for manual review.
for pkg in $(grep -E '^  [a-z_0-9]+:' pubspec.yaml | sed 's/://;s/ //g' | sort -u); do
  dir=$(dart pub deps --style=compact 2>/dev/null | grep -m1 -o "$pkg [0-9.]*" || true)
  [ -n "$dir" ] && echo "$dir"
done
echo
echo "Review licences manually; generate an SBOM with: dart pub deps --json > sbom-deps.json"

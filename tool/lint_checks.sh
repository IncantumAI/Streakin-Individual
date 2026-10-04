#!/bin/bash
# tool/lint_checks.sh
# Custom lint guards run in CI. Spec §15.4.
# Usage: bash tool/lint_checks.sh
# Exit code 1 if any violation found.

set -e
ERRORS=0
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

fail() { echo -e "${RED}FAIL${NC}: $1"; ERRORS=$((ERRORS+1)); }
pass() { echo -e "${GREEN}PASS${NC}: $1"; }

echo "=== Streakin Custom Lint Checks ==="

# 1. No raw colour literals (0xFF...) outside tokens.dart
RAW_COLORS=$(grep -rn "Color(0x" lib/ \
  --include="*.dart" \
  --exclude="tokens.dart" \
  --exclude="*.g.dart" \
  --exclude="*.freezed.dart" \
  | grep -v "//.*Color(0x" | wc -l)
if [ "$RAW_COLORS" -gt 0 ]; then
  fail "Raw Color(0x...) literals found outside tokens.dart ($RAW_COLORS occurrences)"
  grep -rn "Color(0x" lib/ --include="*.dart" --exclude="tokens.dart" \
    --exclude="*.g.dart" --exclude="*.freezed.dart" | grep -v "//.*Color(0x" | head -10
else
  pass "No raw colour literals outside tokens.dart"
fi

# 2. No Icons.* references (must use AppIcons.*)
ICONS_REFS=$(grep -rn "Icons\." lib/ \
  --include="*.dart" \
  --exclude="icons.dart" \
  --exclude="*.g.dart" \
  | grep -v "//.*Icons\." | wc -l)
if [ "$ICONS_REFS" -gt 0 ]; then
  fail "Direct Icons.* usage found outside icons.dart ($ICONS_REFS occurrences)"
  grep -rn "Icons\." lib/ --include="*.dart" --exclude="icons.dart" \
    --exclude="*.g.dart" | grep -v "//.*Icons\." | head -10
else
  pass "No raw Icons.* usage"
fi

# 3. No cross-feature internal imports
# Each feature's data/domain/application must not import other features' internals
CROSS_IMPORTS=$(grep -rn "import 'package:streakin/features/" lib/features/ \
  --include="*.dart" \
  --exclude="*.g.dart" \
  | grep -v "notes_module.dart" \
  | grep -E "(data|domain|application)/[^']+'" \
  | python3 -c "
import sys, re
lines = sys.stdin.readlines()
violations = []
for line in lines:
    match = re.match(r'lib/features/(\w+)/.*import.*features/(\w+)/(data|domain|application)', line)
    if match and match.group(1) != match.group(2):
        violations.append(line.strip())
for v in violations:
    print(v)
" 2>/dev/null | wc -l)
if [ "$CROSS_IMPORTS" -gt 0 ]; then
  fail "Cross-feature internal imports found ($CROSS_IMPORTS)"
else
  pass "No cross-feature internal imports"
fi

# 4. No print() statements (use AppLogger)
PRINTS=$(grep -rn "^\s*print(" lib/ --include="*.dart" \
  --exclude="*.g.dart" --exclude="*.freezed.dart" \
  | grep -v "//.*print(" | wc -l)
if [ "$PRINTS" -gt 0 ]; then
  fail "print() calls found in lib/ ($PRINTS occurrences)"
  grep -rn "^\s*print(" lib/ --include="*.dart" --exclude="*.g.dart" | head -5
else
  pass "No print() calls"
fi

# 5. TODO(rename) count (informational only)
RENAMES=$(grep -rn "TODO(rename)" lib/ android/ windows/ linux/ \
  --include="*.dart" --include="*.kt" --include="*.cpp" --include="*.rc" 2>/dev/null | wc -l)
echo "INFO: TODO(rename) markers found: $RENAMES (see spec §19)"

echo ""
if [ "$ERRORS" -gt 0 ]; then
  echo -e "${RED}=== $ERRORS check(s) failed ===${NC}"
  exit 1
else
  echo -e "${GREEN}=== All checks passed ===${NC}"
fi

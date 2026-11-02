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
#    The boundary excludes "AppIcons." / "MyIcons." (which contain "Icons.").
ICON_RE='(^|[^A-Za-z0-9_])Icons\.'
ICONS_REFS=$(grep -rnE "$ICON_RE" lib/ \
  --include="*.dart" \
  --exclude="icons.dart" \
  --exclude="*.g.dart" \
  | grep -vE "//.*Icons\." | wc -l)
if [ "$ICONS_REFS" -gt 0 ]; then
  fail "Direct Icons.* usage found outside icons.dart ($ICONS_REFS occurrences)"
  grep -rnE "$ICON_RE" lib/ --include="*.dart" --exclude="icons.dart" \
    --exclude="*.g.dart" | grep -vE "//.*Icons\." | head -10
else
  pass "No raw Icons.* usage"
fi

# 3. No cross-feature internal imports
# A feature's data/, domain/ and application/ layers must not import another
# feature's data/domain/application files; they go through that feature's
# *_module.dart facade. Presentation (UI composition) may compose features.
# Allowed shared contract: calendar's CalendarSource interface, which every
# feature implements to appear on the calendar (spec 4.5).
CROSS_IMPORTS=$(grep -rn "import 'package:streakin/features/" lib/features/ \
  --include="*.dart" \
  --exclude="*.g.dart" \
  | python3 -c "
import sys, re
n = 0
for line in sys.stdin:
    m = re.match(r'lib/features/(\w+)/(data|domain|application)/[^:]*:\d+:.*features/(\w+)/(data|domain|application)/([^\']+)', line)
    if not m or m.group(1) == m.group(3):
        continue
    if m.group(3) == 'calendar' and m.group(5) == 'calendar_source.dart':
        continue
    print(line.strip(), file=sys.stderr)
    n += 1
print(n)
" 2>/tmp/cross_imports.txt)
if [ "$CROSS_IMPORTS" -gt 0 ]; then
  fail "Cross-feature internal imports found ($CROSS_IMPORTS)"
  head -10 /tmp/cross_imports.txt
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

#!/usr/bin/env bash
set -o pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

RUN_INTEGRATION=0
SKIP_FLUTTER=0
SKIP_SUPABASE=0
REQUIRE_SUPABASE=0
HAS_TEST_TARGETS=0
FLUTTER_TEST_TARGETS=()

usage() {
  cat <<'USAGE'
Usage: ./tool/verify.sh [options]

Fast default gate:
  1. flutter pub get
  2. flutter analyze
  3. flutter test
  4. project contract scripts
  5. migration-file sanity check
  6. Supabase pgTAP contracts when a DB target is available
  7. integration_test only when explicitly requested and all prior steps pass

Options:
  --test <path>           Run only the given Flutter test path (repeatable).
  --integration           Run integration_test after all previous gates pass.
  --skip-flutter          Skip Flutter commands.
  --skip-supabase         Skip Supabase contract checks.
  --require-supabase      Fail when Supabase CLI/target is not available.
  -h, --help              Show this help.

Supabase target selection:
  SUPABASE_DB_URL=<encoded postgres connection string>  -> remote/CI pgTAP
  supabase/config.toml + linked project                  -> --linked pgTAP
  otherwise                                               -> SKIPPED
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --test)
      [[ $# -ge 2 ]] || { echo "ERROR: --test requires a path"; exit 2; }
      FLUTTER_TEST_TARGETS+=("$2")
      HAS_TEST_TARGETS=1
      shift 2
      ;;
    --integration)
      RUN_INTEGRATION=1
      shift
      ;;
    --skip-flutter)
      SKIP_FLUTTER=1
      shift
      ;;
    --skip-supabase)
      SKIP_SUPABASE=1
      shift
      ;;
    --require-supabase)
      REQUIRE_SUPABASE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1"
      usage
      exit 2
      ;;
  esac
done

FAILED=0

log_step() {
  printf '\n[%s] %s\n' "$1" "$2"
}

pass() {
  printf 'PASS  %s\n' "$1"
}

fail() {
  printf 'FAIL  %s\n' "$1"
  FAILED=1
}

skip() {
  printf 'SKIP  %s\n' "$1"
}

run_cmd() {
  local label="$1"
  shift
  if "$@"; then
    pass "$label"
  else
    fail "$label"
  fi
}

check_command() {
  command -v "$1" >/dev/null 2>&1
}

migration_sanity() {
  python3 - "$ROOT" <<'PY'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
directory = root / "supabase" / "migrations"

if not directory.is_dir():
    print("FAIL  migration_files_present - supabase/migrations missing")
    raise SystemExit(1)

files = sorted(directory.glob("*.sql"))
if not files:
    print("FAIL  migration_files_present - no *.sql migrations found")
    raise SystemExit(1)

pattern = re.compile(r"^\d{12,14}_[a-zA-Z0-9][a-zA-Z0-9_-]*\.sql$")
timestamps = {}
errors = []

for path in files:
    if not pattern.match(path.name):
        errors.append(f"{path.name}: invalid migration filename")
    if path.stat().st_size == 0:
        errors.append(f"{path.name}: empty migration")
    timestamps.setdefault(path.name[:14], []).append(path.name)

for ts, names in sorted(timestamps.items()):
    pass

if errors:
    for error in errors:
        print(f"FAIL  migration_sanity - {error}")
    raise SystemExit(1)

print(f"PASS  migration_sanity - {len(files)} migration files, valid versioned names, non-empty SQL")
print(f"PASS  migration_latest - {files[-1].name}")
PY
}

supabase_contracts() {
  if ! check_command supabase; then
    if (( REQUIRE_SUPABASE )); then
      echo "FAIL  supabase_cli - command not found"
      return 1
    fi
    skip "Supabase CLI unavailable"
    return 0
  fi

  if [[ ! -d "$ROOT/supabase/tests/database" ]]; then
    if (( REQUIRE_SUPABASE )); then
      echo "FAIL  supabase_test_files - directory missing"
      return 1
    fi
    skip "No Supabase pgTAP test directory"
    return 0
  fi

  log_step "SUPABASE" "Run pgTAP contracts"
  SUPABASE_DB_URL="${SUPABASE_DB_URL:-}"
  if [[ -n "$SUPABASE_DB_URL" ]]; then
    if supabase test db "$ROOT/supabase/tests/database" --db-url "$SUPABASE_DB_URL"; then
      pass "Supabase pgTAP contracts (remote)"
    else
      fail "Supabase pgTAP contracts (remote)"
    fi
  elif [[ -f "$ROOT/supabase/config.toml" ]]; then
    if supabase test db "$ROOT/supabase/tests/database" --linked; then
      pass "Supabase pgTAP contracts (linked)"
    else
      fail "Supabase pgTAP contracts (linked)"
    fi

    log_step "SUPABASE" "Check linked migration state"
    if supabase migration list --linked; then
      pass "Supabase migration list"
    else
      fail "Supabase migration list"
    fi
  else
    if (( REQUIRE_SUPABASE )); then
      echo "FAIL  supabase_target - set SUPABASE_DB_URL or add supabase/config.toml"
      return 1
    fi
    skip "Supabase target unavailable (set SUPABASE_DB_URL for remote pgTAP)"
  fi
}

echo "========================================"
echo "MASHAREENA VERIFICATION"
echo "========================================"

log_step "PROJECT" "Migration-file sanity"
migration_sanity || FAILED=1

if (( ! SKIP_FLUTTER )); then
  if ! check_command flutter; then
    fail "Flutter CLI - command not found"
  else
    log_step "FLUTTER" "Dependencies"
    run_cmd "flutter pub get" flutter pub get

    log_step "FLUTTER" "Static analysis"
    run_cmd "flutter analyze" flutter analyze

    log_step "FLUTTER" "Unit/widget tests"
    if (( HAS_TEST_TARGETS )); then
      run_cmd "Flutter targeted tests" flutter test "${FLUTTER_TEST_TARGETS[@]}"
    else
      run_cmd "Flutter full unit/widget suite" flutter test
    fi
  fi
else
  skip "Flutter checks disabled"
fi

if [[ -f "$ROOT/scripts/verify_execution_contract.py" ]]; then
  log_step "PROJECT" "Existing execution contract"
  run_cmd "scripts/verify_execution_contract.py" python3 "$ROOT/scripts/verify_execution_contract.py"
else
  skip "Existing execution contract script not present"
fi

if (( ! SKIP_SUPABASE )); then
  supabase_contracts || FAILED=1
else
  skip "Supabase checks disabled"
fi

if (( RUN_INTEGRATION )); then
  if (( FAILED )); then
    skip "Integration test blocked because an earlier gate failed"
  elif ! check_command flutter; then
    fail "Integration test - Flutter CLI unavailable"
  elif [[ ! -d "$ROOT/integration_test" ]]; then
    skip "Integration test (no integration_test directory)"
  else
    log_step "DEVICE" "Integration test"
    if flutter test integration_test; then
      pass "Integration test"
    else
      fail "Integration test"
    fi
  fi
else
  skip "Integration test - not requested"
fi

echo
echo "----------------------------------------"
if (( FAILED )); then
  echo "RESULT: FAIL"
  echo "APK/IPA build: NOT RUN"
  exit 1
fi

echo "RESULT: PASS"
echo "Build: NOT RUN"
if (( RUN_INTEGRATION )); then
  echo "Integration test: requested"
else
  echo "Integration test: skipped"
fi

#!/usr/bin/env bats

load test_helper

setup() { setup_audit_fixture; }

@test "help and version are available" {
  run_audit --help
  [ "$status" -eq 0 ]
  [[ $output == *"Usage:"* ]]
  run_audit --version
  [ "$status" -eq 0 ]
  [[ $output == *"0.1.0"* ]]
}

@test "invalid arguments return execution error" {
  run_audit --format xml
  [ "$status" -eq 2 ]
  [[ $output == *"format must be text or json"* ]]
  run_audit --include-sensitive
  [ "$status" -eq 2 ]
  [[ $output == *"unknown option: --include-sensitive"* ]]
}

@test "missing configuration returns execution error" {
  run_audit --config "$TEST_WORK_DIR/does-not-exist.conf"
  [ "$status" -eq 2 ]
  [[ $output == *"configuration file not found"* ]]
}

@test "default output includes per-user account details" {
  run_audit
  [ "$status" -eq 0 ] || { printf '%s\n' "$output"; return 1; }
  [[ $output == *"fixture-host"* ]]
  [[ $output == *"alice"* ]]
  [[ $output == *"198.51.100.10"* ]]
  [[ $output == *"USERNAME"*"STATUS"*"GROUPS"*"LAST LOGIN"* ]]
  [[ $output == *"alice"*"ACTIVE"* ]]
}

@test "password states use accurate classifications" {
  run_audit
  [ "$status" -eq 0 ]
  [[ $output == *"alice"*"ACTIVE"* ]]
  [[ $output == *"locked"*"LOCKED"* ]]
}

@test "no-password produces FAIL and exit one" {
  export MOCK_EMPTY_PASSWORD=1
  run_audit
  [ "$status" -eq 1 ]
  [[ $output == *"no-password=1"* ]]
  [[ $output == *"FAIL"* ]]
}

@test "effective SSH configuration is parsed without mischaracterizing port 22" {
  run_audit --ssh-user alice
  [ "$status" -eq 0 ]
  [[ $output == *"effective permitrootlogin=no"* ]]
  [[ $output == *"effective passwordauthentication=no"* ]]
  [[ $output == *"port 22 is the default, not automatically insecure"* ]]
  [[ $output == *"per-user effective settings evaluated"* ]]
}

@test "unsupported platform returns execution error" {
  printf 'ID=fedora\nPRETTY_NAME="Fixture"\n' >"$FIXTURE_ROOT/etc/os-release"
  run_audit
  [ "$status" -eq 2 ]
  [[ $output == *"unsupported platform"* ]]
}

@test "missing optional commands are reported cleanly" {
  export SYSADMIN_TOOLKIT_DISABLED_COMMANDS=ss
  run_audit
  [ "$status" -eq 0 ]
  [[ $output == *"ss command is unavailable"* ]]
}

@test "JSON is valid and contains no ANSI escapes" {
  local json_file="$TEST_WORK_DIR/audit.json"
  local stderr_file="$TEST_WORK_DIR/audit.stderr"
  local audit_status

  if "$REPO_ROOT/bin/host-security-audit" --format json >"$json_file" 2>"$stderr_file"; then
    audit_status=0
  else
    audit_status=$?
  fi

  [ "$audit_status" -eq 0 ]
  jq -e '.schema_version == 2 and .tool == "host-security-audit" and
    (.findings | type == "array") and
    ([.findings[] | select(.check == "accounts") | .details.accounts] | first | type == "array")' "$json_file"
  if grep -q $'\033' "$json_file"; then
    printf 'JSON output contains an ANSI escape sequence\n' >&2
    return 1
  fi
}

@test "privileged groups include primary group membership" {
  printf 'primarypriv:x:1002:27:Primary Privileged:/home/primarypriv:/bin/bash\n' >>"$FIXTURE_ROOT/etc/passwd"
  run_audit --only accounts
  [ "$status" -eq 0 ]
  [[ $output == *"group=sudo"*"members=alice,primarypriv"* ]]
}

@test "journal query failures are UNKNOWN rather than zero events" {
  export MOCK_JOURNAL_FAILURE=1
  run_audit --only services
  [ "$status" -eq 0 ]
  [[ $output == *"authentication journal query failed"* ]]
  [[ $output == *"high-severity journal query failed"* ]]
}

@test "redaction removes fixture identifiers" {
  run_audit --only accounts --redact-identifiers
  [ "$status" -eq 0 ]
  [[ $output == *"<redacted>"* ]]
  [[ $output != *"fixture-host"* ]]
  [[ $output != *"alice"* ]]
  [[ $output != *"198.51.100.10"* ]]
}

@test "only and fail-on control execution and policy" {
  run_audit --only network --fail-on warn
  [ "$status" -eq 1 ]
  [[ $output == *"Network listeners"* ]]
  [[ $output != *"Account password status"* ]]
}

@test "baseline comparison reports unchanged findings" {
  local baseline="$TEST_WORK_DIR/baseline.json"
  "$REPO_ROOT/bin/host-security-audit" --format json >"$baseline"
  run_audit --format json --baseline "$baseline"
  [ "$status" -eq 0 ]
  jq -e '.findings[] | select(.check == "baseline-diff" and
    .level == "PASS" and .details.new_or_changed == 0)' <<<"$output"
}

@test "failed systemd units produce exit one" {
  export MOCK_SYSTEMD_FAILED=1
  run_audit
  [ "$status" -eq 1 ]
  [[ $output == *"failed unit count=1"* ]]
}

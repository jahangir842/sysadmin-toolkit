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
}

@test "missing configuration returns execution error" {
  run_audit --config "$TEST_WORK_DIR/does-not-exist.conf"
  [ "$status" -eq 2 ]
  [[ $output == *"configuration file not found"* ]]
}

@test "default output redacts identity values" {
  run_audit
  [ "$status" -eq 0 ]
  [[ $output != *"fixture-host"* ]]
  [[ $output != *"alice"* ]]
  [[ $output != *"198.51.100.10"* ]]
  [[ $output == *"usernames and shells redacted"* ]]
}

@test "sensitive output requires explicit option" {
  run_audit --include-sensitive
  [ "$status" -eq 0 ]
  [[ $output == *"fixture-host"* ]]
  [[ $output == *"alice"* ]]
}

@test "password states use accurate classifications" {
  run_audit --include-sensitive
  [ "$status" -eq 0 ]
  [[ $output == *"alice=password-set"* ]]
  [[ $output == *"locked=password-locked"* ]]
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
  jq -e '.tool == "host-security-audit" and (.findings | type == "array")' "$json_file"
  ! grep -q $'\033' "$json_file"
}

@test "failed systemd units produce exit one" {
  export MOCK_SYSTEMD_FAILED=1
  run_audit
  [ "$status" -eq 1 ]
  [[ $output == *"failed unit count=1"* ]]
}

setup_audit_fixture() {
  export REPO_ROOT
  REPO_ROOT=$(CDPATH='' cd -- "$BATS_TEST_DIRNAME/.." && pwd)
  TEST_WORK_DIR=${BATS_TEST_TMPDIR:-"${BATS_TMPDIR:-/tmp}/sysadmin-toolkit-bats-${BATS_TEST_NUMBER:-0}"}
  export TEST_WORK_DIR
  export FIXTURE_ROOT="$TEST_WORK_DIR/root"
  export MOCK_BIN="$TEST_WORK_DIR/bin"
  mkdir -p "$FIXTURE_ROOT/etc" "$MOCK_BIN"
  cp "$REPO_ROOT/tests/fixtures/etc/os-release" "$FIXTURE_ROOT/etc/os-release"
  cp "$REPO_ROOT/tests/fixtures/etc/passwd" "$FIXTURE_ROOT/etc/passwd"
  cp "$REPO_ROOT/tests/fixtures/etc/shells" "$FIXTURE_ROOT/etc/shells"
  cp "$REPO_ROOT/tests/fixtures/bin/"* "$MOCK_BIN/"
  chmod +x "$MOCK_BIN/"*
  export PATH="$MOCK_BIN:/usr/bin:/bin"
  export SYSADMIN_TOOLKIT_ROOT="$FIXTURE_ROOT"
  export SYSADMIN_TOOLKIT_TESTING=1
  export NO_COLOR=1
  unset MOCK_EMPTY_PASSWORD MOCK_SYSTEMD_FAILED MOCK_SSH_INSECURE SYSADMIN_TOOLKIT_DISABLED_COMMANDS
}

run_audit() {
  run "$REPO_ROOT/bin/host-security-audit" "$@"
}

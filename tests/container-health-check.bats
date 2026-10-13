#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031 # Bats isolates each test environment.
setup() {
  REPO_ROOT=$(CDPATH='' cd -- "$BATS_TEST_DIRNAME/.." && pwd)
  export PATH="$REPO_ROOT/tests/fixtures/docker:$PATH"
  export MOCK_DOCKER_INSPECT="$BATS_TEST_TMPDIR/inspect.json"
  export MOCK_DOCKER_CALLS="$BATS_TEST_TMPDIR/calls"
  cp "$REPO_ROOT/tests/fixtures/docker/inspect.json" "$MOCK_DOCKER_INSPECT"
  unset DOCKER_HOST DOCKER_CONTEXT
}
check_containers() { run "$REPO_ROOT/bin/container-health-check" "$@"; }
change_fixture() {
  jq "$1" "$MOCK_DOCKER_INSPECT" >"$BATS_TEST_TMPDIR/updated"
  mv "$BATS_TEST_TMPDIR/updated" "$MOCK_DOCKER_INSPECT"
}
@test "JSON identifies tool, preserves inventory, and excludes secrets" {
  check_containers --format json --expected web
  [ "$status" -eq 0 ]
  jq -e '.tool == "container-health-check" and .containers[0].project == "site" and .containers[0].restarts == 2' <<<"$output"
  [[ $output != *secret-canary* ]]
  run rg 'restart|prune|exec|logs|stop' "$MOCK_DOCKER_CALLS"
  [ "$status" -eq 1 ]
}
@test "text includes project table and shared finding hierarchy" {
  check_containers
  [ "$status" -eq 0 ]
  [[ $output == *"CONTAINER HEALTH REPORT"* && $output == *"site"* && $output == *"Summary:"* ]]
}
@test "missing expected service fails, stopped jobs are informational" {
  change_fixture '.[0].State.Status = "exited" | .[0].State.ExitCode = 0 | del(.[0].State.Health)'
  check_containers --format json
  [ "$status" -eq 0 ]
  check_containers --expected web
  [ "$status" -eq 1 ]
  [[ $output == *"missing or stopped"* ]]
}
@test "unhealthy, restarting, and OOM states fail" {
  for expression in '.[0].State.Health.Status = "unhealthy"' '.[0].State.Status = "restarting"' '.[0].State.OOMKilled = true'; do
    cp "$REPO_ROOT/tests/fixtures/docker/inspect.json" "$MOCK_DOCKER_INSPECT"
    change_fixture "$expression"
    check_containers --format json
    [ "$status" -eq 1 ]
  done
}
@test "absent healthcheck is unknown rather than healthy" {
  change_fixture 'del(.[0].State.Health)'
  check_containers --format json
  [ "$status" -eq 0 ]
  jq -e '.findings[] | select(.check == "container-health" and .level == "UNKNOWN")' <<<"$output"
}
@test "policy warns on public ports, missing limits and socket mount" {
  change_fixture '.[0].HostConfig.Memory = 0 | .[0].HostConfig.NanoCpus = 0 | .[0].HostConfig.Privileged = true | .[0].HostConfig.LogConfig.Config = {} | .[0].NetworkSettings.Ports["80/tcp"][0].HostIp = "0.0.0.0" | .[0].Mounts += [{"Source":"/var/run/docker.sock","Destination":"/socket","RW":false,"Type":"bind"}]'
  check_containers --fail-on warn
  [ "$status" -eq 1 ]
  [[ $output == *"no memory limit"* && $output == *"socket mounted"* && $output == *"without a size limit"* && $output == *"0.0.0.0"* ]]
}
@test "baseline detects new restarts only for same container ID" {
  "$REPO_ROOT/bin/container-health-check" --format json >"$BATS_TEST_TMPDIR/baseline"
  change_fixture '.[0].RestartCount = 4'
  check_containers --baseline "$BATS_TEST_TMPDIR/baseline" --fail-on warn
  [ "$status" -eq 1 ]
  [[ $output == *"new restarts=2"* ]]
  change_fixture '.[0].Id = "replacement"'
  check_containers --baseline "$BATS_TEST_TMPDIR/baseline" --fail-on warn
  [ "$status" -eq 0 ]
}
@test "daemon failure and invalid arguments return execution error" {
  export MOCK_DOCKER_DOWN=1
  check_containers
  [ "$status" -eq 2 ]
  check_containers --timeout 0
  [ "$status" -eq 2 ]
  check_containers --format xml
  [ "$status" -eq 2 ]
  check_containers --expected
  [ "$status" -eq 2 ]
}
@test "empty inventory, vanished containers and unavailable stats remain truthful" {
  export MOCK_DOCKER_EMPTY=1
  check_containers
  [ "$status" -eq 0 ]
  [[ $output == *"no containers found"* ]]
  unset MOCK_DOCKER_EMPTY
  export MOCK_DOCKER_DISAPPEAR=1 MOCK_DOCKER_STATS_FAIL=1
  check_containers
  [ "$status" -eq 0 ]
  [[ $output == *"could not be inspected"* && $output == *"resource snapshot unavailable"* ]]
}
@test "invalid baseline is rejected and help needs no daemon access" {
  printf '{"tool":"host-security-audit","containers":[]}\n' >"$BATS_TEST_TMPDIR/bad-baseline"
  check_containers --baseline "$BATS_TEST_TMPDIR/bad-baseline"
  [ "$status" -eq 2 ]
  export MOCK_DOCKER_DOWN=1
  check_containers --help
  [ "$status" -eq 0 ]
}
@test "CPU quota prevents false missing CPU limit warning and root group is detected" {
  change_fixture '.[0].HostConfig.NanoCpus = 0 | .[0].HostConfig.CpuQuota = 50000 | .[0].Config.User = "root:root"'
  check_containers --format json
  [ "$status" -eq 0 ]
  [[ $output != *"no CPU limit"* && $output == *"configured root/default user"* ]]
}

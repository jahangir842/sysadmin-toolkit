#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031
setup() {
  REPO_ROOT=$(CDPATH='' cd -- "$BATS_TEST_DIRNAME/.." && pwd)
  export PATH="$REPO_ROOT/tests/fixtures/disk:$PATH"
  export MOCK_DU_CALLS="$BATS_TEST_TMPDIR/du-calls"
  unset MOCK_DF_TIMEOUT MOCK_DF_FAIL MOCK_MOUNTS_FAIL MOCK_INODE_UNKNOWN MOCK_DU_FAIL MOCK_SPACE_PERCENT MOCK_INODE_PERCENT
}
check_disk() { run "$REPO_ROOT/bin/disk-capacity-check" "$@"; }
@test "healthy JSON reports space and inodes and excludes virtual mounts" {
  check_disk --format json
  [ "$status" -eq 0 ]
  jq -e '.tool == "disk-capacity-check" and ([.findings[] | select(.check == "disk-space")] | length == 2)' <<<"$output"
  jq -e '.findings[] | select(.check == "disk-inodes" and .level == "PASS" and .details.total == 100)' <<<"$output"
  [[ $output != *tmpfs* ]]
}
@test "space warning boundary and custom failure boundary" {
  export MOCK_SPACE_PERCENT=80
  check_disk --format json
  [ "$status" -eq 0 ]
  jq -e '.findings[] | select(.check == "disk-space" and .level == "WARN")' <<<"$output"
  check_disk --fail-on warn
  [ "$status" -eq 1 ]
  check_disk --space-warn 60 --space-fail 80
  [ "$status" -eq 1 ]
}
@test "full disk and inode exhaustion fail independently" {
  export MOCK_SPACE_PERCENT=100
  check_disk
  [ "$status" -eq 1 ]
  export MOCK_SPACE_PERCENT=10 MOCK_INODE_PERCENT=100
  check_disk --format json
  [ "$status" -eq 1 ]
  jq -e '.findings[] | select(.check == "disk-inodes" and .level == "FAIL")' <<<"$output"
}
@test "exact mount exclusions preserve writable expectations" {
  check_disk --format json --exclude-mount '/data folder' --expect-rw '/data folder'
  [ "$status" -eq 1 ]
  jq -e '([.findings[] | select(.check == "disk-space")] | length == 1) and any(.findings[]; .check == "disk-mount" and .level == "FAIL")' <<<"$output"
  check_disk --expect-rw /missing
  [ "$status" -eq 1 ]
  [[ $output == *'mount is missing'* ]]
  check_disk --expect-rw /
  [ "$status" -eq 0 ]
}
@test "unsupported inode accounting and failed queries are unknown" {
  export MOCK_INODE_UNKNOWN=1
  check_disk --format json
  [ "$status" -eq 0 ]
  jq -e '.findings[] | select(.check == "disk-inodes" and .level == "UNKNOWN")' <<<"$output"
  export MOCK_DF_FAIL=1
  check_disk
  [ "$status" -eq 0 ]
  [[ $output == *UNKNOWN* && $output == *'query failed'* ]]
}
@test "optional directory discovery handles spaces and omits partial results" {
  mkdir -p "$BATS_TEST_TMPDIR/scan folder"
  check_disk --format json --discover "$BATS_TEST_TMPDIR/scan folder" --top 1
  [ "$status" -eq 0 ]
  jq -e '.findings[] | select(.check == "disk-discovery") | .details | length == 1 and .[0].bytes == 100' <<<"$output"
  [[ $(cat "$MOCK_DU_CALLS") == *'-x -B1 --max-depth=1 --null --'* ]]
  export MOCK_DU_FAIL=1
  check_disk --discover "$BATS_TEST_TMPDIR/scan folder"
  [ "$status" -eq 0 ]
  [[ $output == *'partial results omitted'* ]]
}
@test "invalid inputs and failed inventory return execution error" {
  for args in '--space-warn 90 --space-fail 80' '--inode-warn 0' '--timeout 0' '--top 0' '--format xml' '--expect-rw relative' '--discover'; do
    # Intentional splitting of fixed test arguments.
    # shellcheck disable=SC2086
    check_disk $args
    [ "$status" -eq 2 ]
  done
  export MOCK_MOUNTS_FAIL=1
  check_disk
  [ "$status" -eq 2 ]
  check_disk --help
  [ "$status" -eq 0 ]
}
@test "text uses shared storage report hierarchy and no findings when all excluded" {
  check_disk
  [ "$status" -eq 0 ]
  [[ $output == *'DISK CAPACITY REPORT'* && $output == *'FILESYSTEM & STORAGE'* && $output == *'Summary:'* ]]
  check_disk --exclude-mount / --exclude-mount '/data folder'
  [ "$status" -eq 0 ]
  [[ $output == *'no filesystems selected'* ]]
}

@test "capacity timeout is bounded and reported unknown" {
  export MOCK_DF_TIMEOUT=1
  check_disk --format json --timeout 1 --exclude-mount '/data folder'
  [ "$status" -eq 0 ]
  jq -e 'any(.findings[]; .check == "disk-space" and .level == "UNKNOWN" and .details.mount == "/")' <<<"$output"
}

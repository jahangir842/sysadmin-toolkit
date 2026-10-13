# Disk capacity reports

`disk-capacity-check` reports mounted filesystem space (bytes), inode capacity
(counts), and mount options. It is read-only and uses the shared text/JSON report
format. Debian/Ubuntu dependencies are `findmnt` (util-linux), GNU `df`, GNU
`timeout` (coreutils), and `jq`; optional discovery also needs GNU `du`.

```sh
sudo ./bin/disk-capacity-check
sudo ./bin/disk-capacity-check --format json >disk.json
sudo ./bin/disk-capacity-check --space-warn 75 --space-fail 90 \
  --inode-warn 80 --inode-fail 95 --fail-on warn
sudo ./bin/disk-capacity-check --exclude-mount /mnt/archive --expect-rw / \
  --expect-rw /var/lib/docker
sudo ./bin/disk-capacity-check --discover /var --top 10 --timeout 30
```

Only use `--expect-rw /var/lib/docker` if that path is an actual mount target.
Mount arguments must be absolute, exact targets from `findmnt`; exclusions and
expectations are repeatable. Writable expectations are checked even for excluded
mounts. A missing expected mount or an explicitly read-only expected mount is a
`FAIL`. Other read-only mounts are informational, since read-only operation may
be intentional. Writable mount options do not guarantee an application's ability
to write: permissions, quotas, and storage errors require separate investigation.

## Thresholds and coverage

Space and inode warning/failure defaults are 80/90 percent. Thresholds are integer
percentages from 1 through 100; warnings must be below failures. Findings trigger
at or above a threshold. GNU `df` rounds usage percentages up; space percentages
reflect filesystem accounting, including reserved space, and may exceed 100.
Unsupported or unavailable inode accounting is `UNKNOWN`, not a pass.

Virtual filesystems, including tmpfs, are excluded by default. Use
`--exclude-types TYPE,...` to replace that list, or `--exclude-types ''` to inspect
all types. The exact default list is in the command source. Mounted local,
network, bind, and overlay filesystems are otherwise included; different mount
targets can report the same underlying storage. This checks visible mounts,
not unmounted volumes, provider storage, user quotas, or thin-pool capacity.

Every inventory, capacity query, and discovery scan has its own timeout (default
20 seconds, followed by a two-second forced-termination grace period). Total
runtime depends on the number of selected mounts and discovery paths. Failed
mount inventory returns exit 2. Individual failed/timed-out capacity queries are
`UNKNOWN` so remaining mounts can still be reported. As with other toolkit
commands, unknown findings do not themselves change the exit status.

## Optional directory discovery

Discovery is opt-in. `du -x -B1 --max-depth=1 --null` scans recursively, stays on
the starting device, and reports allocated bytes for the root and immediate
subdirectories. The largest entries are sorted and limited by `--top` (1–9999).
The scan root is included, so entries are not additive. Bind mounts on the same
device can still be traversed. Directory scans can cause substantial disk I/O;
use narrow paths and appropriate timeouts. Permission errors, partial scans,
and timeouts produce `UNKNOWN` with partial results omitted.

Normal checks usually work without root; root may be needed to scan restricted
directories. No cleanup or deletion is performed or implied by discovery.

## Automation and report protection

Exit codes are 0 for no policy failures, 1 for `FAIL` findings (or `WARN` with
`--fail-on warn`), and 2 for usage/dependency/inventory errors. Reports contain
hostnames, mount sources, paths, and optional directory names; protect them as
sensitive data. JSON findings include numeric capacity values and thresholds in
`details`; use `details.mount` to distinguish repeated per-mount check IDs.

For example, in a root crontab, replace the checkout and output paths:

```cron
*/15 * * * * umask 077; /opt/sysadmin-toolkit/bin/disk-capacity-check --format json --fail-on warn > /var/log/sysadmin-toolkit-disk.json
```

Cron output storage alone does not send alerts. See [deployment](deployment.md)
for scheduling and handling nonzero exit statuses. Overlapping executions should
be prevented by the scheduler when scans can exceed the reporting interval.

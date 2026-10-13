# Docker container reports

Run from the Git checkout on the Docker host. The command requires Bash, Docker
CLI, `jq`, and GNU `timeout`, plus permission to query the Docker daemon. On
Debian/Ubuntu, install `jq` with `sudo apt-get install jq` if it is missing.

```sh
sudo ./bin/container-health-check --format text
sudo ./bin/container-health-check --format json >containers.json
sudo ./bin/container-health-check --expected web,database --fail-on warn
sudo ./bin/container-health-check --baseline containers.json --format json >containers-next.json
```

Use exact Docker container names for `--expected`, including Compose-generated
names where applicable. Do not write a new report over the baseline being read.
Restart comparisons match container IDs: recreating a container starts a new
history. A lifetime restart count alone is informational.

Text output includes an inventory sorted by Compose project and container, then
findings using the shared report hierarchy. JSON includes `tool`, version,
findings, and a `containers` inventory suitable for the next baseline. Containers
without Compose labels are grouped under `standalone`.

Checks cover unhealthy/restarting/dead containers, OOM kills, expected services,
memory and CPU limits, a current resource snapshot, Docker storage usage,
published ports, root/default users, privileged mode, host namespaces, added
capabilities, engine socket mounts, log size limits, and persistent mounts.
Memory usage of at least 80% is a warning; local Docker data filesystem usage
warns at 80% and fails at 90%. CPU statistics are informational snapshots.

Stopped containers and completed jobs are informational unless explicitly
required with `--expected`. Missing health checks produce `UNKNOWN`. Security
settings and ports produce review warnings, not a claim of compromise. A public
bind address does not prove internet reachability. Mount inventory does not
verify backups. An unhealthy container requires an existing Docker health check
for that state to be observable.

The command queries Docker without changing containers, running commands inside
them, reading application logs, or pruning data. Docker inspection responses are
processed in a private temporary directory, removed on exit. Reports exclude
environment variables, healthcheck output, and raw application logs but still
contain sensitive names, paths, ports, and IDs. Protect report files.

Resource and Docker disk queries that fail or time out yield `UNKNOWN` findings.
Daemon access failure returns exit 2. Each Docker query is bounded by `--timeout`
(default 20 seconds); the complete run can take longer with many containers.
Containers may change during collection, so this is not an atomic snapshot.
Local filesystem capacity is only checked for a local default Docker context;
remote or inaccessible data paths produce `UNKNOWN`.

Exit codes match the host audit: 0 without policy failures, 1 for `FAIL` (or
`WARN` with `--fail-on warn`), and 2 for usage/execution errors. `UNKNOWN` does not
change the exit status.

## Cron from a checkout

Follow the [cron setup](deployment.md#automating-reports-with-cron) to create the
private report directory and edit root's crontab. Add this for checks every ten
minutes, replacing the checkout path and expected names with your own:

```cron
PATH=/usr/sbin:/usr/bin:/sbin:/bin
*/10 * * * * umask 077; /home/gciadmin/sysadmin-toolkit/bin/container-health-check --format json --expected web,database > /var/log/sysadmin-toolkit/containers-$(date +\%F-\%H\%M).json 2> /var/log/sysadmin-toolkit/containers-$(date +\%F-\%H\%M).err
```

Keep the percent signs escaped. Allow enough time between runs for collection to
finish; consider `flock` for hosts where runs may overlap. Root's cron executes
checkout code, so keep it and its parent directories controlled by trusted
administrators. Review updates before pulling them. Cron does not alert on exit
status; monitoring must inspect findings or run status separately.

The host-audit cleanup example does not match container reports. Optional
30-day cleanup for these files:

```cron
0 3 * * * find /var/log/sysadmin-toolkit -maxdepth 1 -type f \( -name 'containers-*.json' -o -name 'containers-*.err' \) -mtime +30 -delete
```

Docker reference: [container inspection](https://docs.docker.com/reference/cli/docker/container/inspect/),
[resource statistics](https://docs.docker.com/reference/cli/docker/container/stats/),
and [logging configuration](https://docs.docker.com/engine/logging/configure/).

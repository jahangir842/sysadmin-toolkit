# sysadmin-toolkit

Reusable, conservative Linux administration and auditing commands. Version
`0.1.0` targets Debian and Ubuntu. Commands are read-only unless a future
operation explicitly implements both `--apply` and interactive confirmation.

The first implemented command is `host-security-audit`. It reports observations
as `PASS`, `WARN`, `FAIL`, `INFO`, or `UNKNOWN`; it never claims that a host is
secure. The report includes hostnames, usernames, group memberships, SSH listen
addresses, process details, key fingerprints, and a per-user table of password
status, groups, and last login for root and interactive accounts at or above
`UID_MIN`. Protect the report as sensitive data.

Text output is presented as a grouped report with a findings summary and uses
colors in interactive terminals. Set `NO_COLOR=1` to disable colors. JSON output
remains available for automation.

```sh
sudo ./bin/host-security-audit --format text
sudo ./bin/host-security-audit --format json >audit.json
sudo ./bin/host-security-audit --ssh-user service-account
sudo ./bin/host-security-audit --profile server --fail-on warn
sudo ./bin/host-security-audit --redact-identifiers
sudo ./bin/host-security-audit --baseline previous-audit.json
```

Exit status is `0` when there are no `FAIL` findings, `1` when one or more
`FAIL` findings exist, and `2` for usage, configuration, platform, or execution
errors. `WARN` and `UNKNOWN` do not change a successful exit status.

The audit groups checks as `accounts`, `updates`, `ssh`, `network`,
`confinement`, `filesystem`, and `services`. Use `--only` or `--skip` with a
comma-separated list of those names. `--fail-on warn` makes warnings fail an
automation run. `--redact-identifiers` suppresses hostnames, usernames,
addresses, group membership details, process identifiers, and SSH-key
fingerprints. `--baseline`/`--diff` compares check levels with a previous JSON
report. Expensive discovery commands are bounded by `--timeout`.

Coverage includes account and sudo policy, authorized keys, effective SSH
configuration, listener and firewall state, security updates, reboot state,
AppArmor and selected kernel controls, sensitive file permissions, privileged
executables, mount/encryption indicators, persistence mechanisms, time
synchronization, journal/audit status, and security events. Context-dependent
observations remain `INFO` or `UNKNOWN` unless site policy makes them
actionable.

## Running from a checkout

From a verified Git checkout on a Debian or Ubuntu server, run the audit
directly from the repository directory:

```sh
sudo ./bin/host-security-audit --format text
sudo ./bin/host-security-audit --format json >audit.json
```

Keep the repository layout intact so the script can load its adjacent `lib/`
files. Running from a checkout uses the code in that checkout, so review updates
before pulling them and running the command again. Keep each client's checkout,
configuration, and audit output separate; do not commit client-specific data or
results to this repository.

For daily reports from a checkout, see [automating reports with cron](docs/deployment.md#automating-reports-with-cron).

See [deployment](docs/deployment.md), the [security model](docs/security-model.md),
and the [report visual hierarchy](docs/reporting-style.md). New commands should
follow the shared report hierarchy and use `lib/logging.sh` for common rendering
behavior. Contributions must pass `shellcheck` and `bats tests`.

## Commands

See the [feature roadmap](ROADMAP.md) for the prioritized implementation plan
and completion checklists for future VPS and Linux server management features.

- `host-security-audit` — implemented.
- `container-health-check` — implemented; see [Docker container reports](docs/containers.md).
- `disk-capacity-check` — implemented; see [disk capacity reports](docs/disk-capacity.md).
- `backup-verification` and `tls-expiry-check` — reserved command names;
  currently return exit 2 with a
  clear not-implemented message.

## Quick Docker status check

Requires Docker CLI, `jq`, and GNU `timeout` (provided by `coreutils`), plus
access to a running Docker daemon. On Debian/Ubuntu, install the reporting
dependencies before the first run:

```sh
sudo apt-get update
sudo apt-get install -y jq coreutils
```

From the checkout directory, run:

```sh
sudo ./bin/container-health-check --format text
sudo ./bin/container-health-check --format json >containers.json
```

To require specific containers to be running, replace `web,database` with their
exact Docker container names:

```sh
sudo ./bin/container-health-check --expected web,database --format text
```

To detect new restarts since a saved JSON report:

```sh
sudo ./bin/container-health-check --baseline containers.json --format text
```

The report groups containers by Compose project and checks health, OOM kills,
resource limits, disk usage, published ports, security settings, and logging.
It is read-only. Missing health checks are `UNKNOWN`; stopped containers are
informational unless listed in `--expected`. Protect saved reports as sensitive
data. See [Docker container reports](docs/containers.md) for details and a cron
example that runs every ten minutes.

Keep this repository private until output, fixtures, documentation, and Git
history have been reviewed for client-identifying information.

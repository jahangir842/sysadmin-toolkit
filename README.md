# sysadmin-toolkit

Reusable, conservative Linux administration and auditing commands. Version
`0.1.0` targets Debian and Ubuntu. Commands are read-only unless a future
operation explicitly implements both `--apply` and interactive confirmation.

The first implemented command is `host-security-audit`. It reports observations
as `PASS`, `WARN`, `FAIL`, `INFO`, or `UNKNOWN`; it never claims that a host is
secure. Sensitive authentication details are redacted unless
`--include-sensitive` is explicitly supplied.

Text output is presented as a grouped report with a findings summary and uses
colors in interactive terminals. Set `NO_COLOR=1` to disable colors. JSON output
remains available for automation.

```sh
sudo /usr/local/sbin/host-security-audit --format text
sudo /usr/local/sbin/host-security-audit --format json >audit.json
sudo /usr/local/sbin/host-security-audit --ssh-user service-account
```

Exit status is `0` when there are no `FAIL` findings, `1` when one or more
`FAIL` findings exist, and `2` for usage, configuration, platform, or execution
errors. `WARN` and `UNKNOWN` do not change a successful exit status.

## Running from a checkout

Installing the toolkit system-wide is optional. From a verified checkout on a
Debian or Ubuntu server, run the audit directly:

```sh
sudo ./bin/host-security-audit --format text
sudo ./bin/host-security-audit --format json >audit.json
```

Keep the repository layout intact so the script can load its adjacent `lib/`
files. Running from a checkout uses the code in that checkout, so review updates
before pulling them and running the command again. Keep each client's checkout,
configuration, and audit output separate; do not commit client-specific data or
results to this repository.

If you prefer a system-wide command, install the verified checkout under
`/usr/local/lib/sysadmin-toolkit` and add a link in `/usr/local/sbin`:

```sh
sudo install -d -o root -g root -m 0755 /usr/local/lib/sysadmin-toolkit/{bin,lib}
sudo install -o root -g root -m 0755 bin/* /usr/local/lib/sysadmin-toolkit/bin/
sudo install -o root -g root -m 0644 lib/*.sh /usr/local/lib/sysadmin-toolkit/lib/
sudo ln -s /usr/local/lib/sysadmin-toolkit/bin/host-security-audit /usr/local/sbin/host-security-audit
```

To remove that system-wide installation, verify the paths and then run:

```sh
sudo unlink /usr/local/sbin/host-security-audit
sudo rm -r /usr/local/lib/sysadmin-toolkit
```

See [deployment](docs/deployment.md) and the [security model](docs/security-model.md).
Contributions must pass `shellcheck` and `bats tests`.

## Commands

- `host-security-audit` — implemented.
- `container-health-check`, `backup-verification`, `tls-expiry-check`, and
  `disk-capacity-check` — reserved command names; currently return exit 2 with a
  clear not-implemented message.

Keep this repository private until output, fixtures, documentation, and Git
history have been reviewed for client-identifying information.

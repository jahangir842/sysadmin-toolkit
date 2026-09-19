# sysadmin-toolkit

Reusable, conservative Linux administration and auditing commands. Version
`0.1.0` targets Debian and Ubuntu. Commands are read-only unless a future
operation explicitly implements both `--apply` and interactive confirmation.

The first implemented command is `host-security-audit`. It reports observations
as `PASS`, `WARN`, `FAIL`, `INFO`, or `UNKNOWN`; it never claims that a host is
secure. Sensitive authentication details are redacted unless
`--include-sensitive` is explicitly supplied.

```sh
sudo /usr/local/sbin/host-security-audit --format text
sudo /usr/local/sbin/host-security-audit --format json >audit.json
sudo /usr/local/sbin/host-security-audit --ssh-user service-account
```

Exit status is `0` when there are no `FAIL` findings, `1` when one or more
`FAIL` findings exist, and `2` for usage, configuration, platform, or execution
errors. `WARN` and `UNKNOWN` do not change a successful exit status.

See [installation](docs/installation.md), [deployment](docs/deployment.md), and
the [security model](docs/security-model.md). Contributions must pass
`shellcheck` and `bats tests`.

## Commands

- `host-security-audit` — implemented.
- `container-health-check`, `backup-verification`, `tls-expiry-check`, and
  `disk-capacity-check` — reserved command names; currently return exit 2 with a
  clear not-implemented message.

Keep this repository private until output, fixtures, documentation, and Git
history have been reviewed for client-identifying information.

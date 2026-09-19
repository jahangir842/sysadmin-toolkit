# Security model

The toolkit is read-only by default. Any future mutation must require `--apply`
and an interactive confirmation; automation must not weaken that contract.
Temporary directories use `mktemp -d`, mode 0700, and cleanup traps.

Site expectations belong outside the repository, conventionally at
`/etc/sysadmin-toolkit/site.conf`. The audit accepts `--config FILE` only when
the file is root-owned and not group/world writable. Configuration is parsed as
a small allowlisted `KEY=value` format and is never executed as shell code.
Start from `config/example.conf`; never store client identifiers or secrets in
this repo.

Default output redacts hostnames, usernames, addresses, and raw authentication
records. `--include-sensitive` is an explicit authorization boundary; redirect
that output to a mode-0600 file, restrict its retention, and transfer it only
through an approved encrypted channel. The JSON stream contains no ANSI codes.

Findings are observations, not proof of security. In particular, port 22 is
merely the SSH default; locked passwords do not disable every access method;
configured passwords do not imply SSH password authentication; and UFW must be
interpreted alongside bind addresses and provider/network firewalls.

For multiple clients, use a separately managed root-owned configuration per
environment. Deploy pinned releases, record only version and verified digest in
client repositories, and keep outputs out of source control. Review fixtures,
documentation, output, and full Git history before considering publication.

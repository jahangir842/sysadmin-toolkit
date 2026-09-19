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

Output includes hostnames, usernames, group memberships, SSH listen addresses,
process identifiers, SSH public-key fingerprints, and a per-user table of
password status, groups, and last login by default. The table covers root and
interactive accounts at or above the host's configured `UID_MIN`. Treat both
text and JSON output as sensitive: restrict access, use mode-0600 when saving
reports, limit retention, and transfer them only through an approved encrypted
channel. Authentication events are emitted as aggregate counts; raw
authentication records are not included. The JSON stream contains no ANSI
codes.

Use `--redact-identifiers` when operational identifiers are unnecessary. This
redacts hostnames, usernames, addresses, memberships, process data, login
details, and key fingerprints, but does not make a report anonymous: package,
service, platform, and policy information may still identify a host. Baseline
files are read only and must receive the same protection as current reports.

Filesystem discovery is restricted to the live root, does not cross filesystem
boundaries, emits aggregate counts, and is bounded by `--timeout`. Package
checks use APT simulation with locking disabled and do not refresh metadata or
install packages. The audit does not change firewall, SSH, account, kernel,
service, or package state.

Findings are observations, not proof of security. In particular, port 22 is
merely the SSH default; locked passwords do not disable every access method;
configured passwords do not imply SSH password authentication; and UFW must be
interpreted alongside bind addresses and provider/network firewalls.

For multiple clients, use a separately managed root-owned configuration per
environment. Deploy pinned releases, record only version and verified digest in
client repositories, and keep outputs out of source control. Review fixtures,
documentation, output, and full Git history before considering publication.

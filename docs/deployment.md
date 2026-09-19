# Release and deployment

## Tagged releases

Update `CHANGELOG.md`, run ShellCheck and Bats, review the Git diff and history
for client data, then create a signed semantic-version tag such as `v0.1.0`.
Build a source archive and a separate SHA-256 checksum file in CI or a clean
release workspace. Publishing remains a deliberate human action.

## Pinned, checksum-verified installation

Download the exact release archive and checksum file as separate steps. Never
pipe network output into a shell. Verify before extracting:

```sh
sha256sum --check sysadmin-toolkit-v0.1.0.tar.gz.sha256
tar -tzf sysadmin-toolkit-v0.1.0.tar.gz
tar -xzf sysadmin-toolkit-v0.1.0.tar.gz
```

Inspect the archive member list before extraction and install using the commands
in `installation.md`. Obtain the expected checksum through an authenticated,
independent release channel; a checksum downloaded from the same compromised
location alone does not establish authenticity.

A client repository can record only non-secret provenance, for example:

```text
sysadmin-toolkit version: 0.1.0
archive sha256: <verified digest>
installed path: /usr/local/lib/sysadmin-toolkit
```

Do not copy site configuration, audit output, hostnames, addresses, or logs into
that record.

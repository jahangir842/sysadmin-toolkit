# Changelog

All notable changes follow Keep a Changelog and versions follow Semantic Versioning.

## [Unreleased]

### Added

- Expanded host auditing for updates, lifecycle, accounts, sudo and SSH keys,
  firewalls and listeners, AppArmor and kernel controls, filesystem and storage
  posture, persistence, time, logging, audit services, and security events.
- Added check-group selection, host profiles, policy severity thresholds,
  identifier redaction, bounded discovery, listener allowlists, baseline
  comparison, and structured JSON schema version 2.

### Fixed

- Include primary-group members in privileged group reports, use the host's
  interactive-account definition consistently, and report failed journal
  queries as unknown rather than zero events.

## [0.1.0] - 2026-09-19

### Added

- Initial Debian/Ubuntu host security audit, shared libraries, documentation,
  fixture-driven Bats tests, and CI validation.

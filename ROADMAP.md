# Feature roadmap

Build a handy toolkit that a system administrator can pull onto a VPS or Linux
server and use for routine checks, troubleshooting, and maintenance. Debian
and Ubuntu are supported today; broader Linux support is a future milestone.

This document tracks planned work, not currently available functionality. See
[README.md](README.md) for implemented commands and usage.

## How to use this plan

- Implement features in the order below, adjusting priorities when a concrete
  operational need warrants it.
- Check off individual items when implemented and verified. Check off a feature
  heading only when all its acceptance items are complete.
- Update command documentation and the changelog with each completed feature.
- Keep unfinished items unchecked; reserved command names are not implementations.

## Existing foundation

- [x] Host security audit with grouped text/JSON reports, policy controls,
  redaction, and baseline comparison.
- [x] Docker container health reports with expected-container policy,
  resource/security observations, and restart comparison.
- [x] Shared shell libraries, fixture-based tests, CI, and deployment guidance.

## Phase 1: Everyday server checks

### 1. Disk capacity — complete

- [x] Implement `disk-capacity-check`; see [disk capacity reports](docs/disk-capacity.md).
- [x] Report filesystem space and inode usage with configurable warning/failure
  thresholds and mount exclusions.
- [x] Identify unexpectedly read-only mounts using explicit site expectations.
- [x] Offer optional, bounded discovery of large directories without crossing
  filesystem boundaries.
- [x] Document text/JSON output, permissions, thresholds, and scheduling; verify
  full disks, inode exhaustion, excluded mounts, and unavailable information.

### 2. Host health

- [ ] Add `host-health-check`.
- [ ] Report CPU load relative to available cores, available memory, swap
  pressure, and recent OOM events.
- [ ] Measure CPU steal time over a bounded sample interval where supported.
- [ ] Support configurable thresholds and explain sampling windows in reports.
- [ ] Document usage and verify healthy, overloaded, and unavailable-data cases.

### 3. Service health

- [ ] Add `service-health-check`.
- [ ] Check explicitly required systemd services and inventory failed units.
- [ ] Report restart counts and detect increases against a saved baseline.
- [ ] Support optional HTTP endpoint checks with timeouts, expected status codes,
  and normal TLS verification.
- [ ] Document usage and verify missing services, failures, restart changes,
  endpoint errors, and timeouts.

## Phase 2: Recovery and scheduled work

### 4. Backup verification

- [ ] Implement `backup-verification` (currently a placeholder).
- [ ] Define a documented backup evidence format or backend adapter interface.
- [ ] Check latest successful backup age, expected paths, and available backup
  inventory without reporting credentials or backup contents.
- [ ] Report integrity-check and restore-test results with their timestamps;
  distinguish missing evidence from successful verification.
- [ ] Keep restore drills separate and explicitly authorized; do not restore
  over live data as part of a routine check.
- [ ] Document supported backends and verify stale, failed, incomplete, and
  unavailable backup evidence.

### 5. TLS certificates

- [ ] Implement `tls-expiry-check` (currently a placeholder).
- [ ] Check configured TLS endpoints with SNI, hostname matching, chain
  validation, and bounded connection times.
- [ ] Report certificate expiry using configurable warning/failure periods.
- [ ] Support local certificate files with clearly stated limits on what a
  local-file check establishes.
- [ ] Document usage and verify expired certificates, hostname mismatches,
  untrusted chains, and unreachable endpoints.

### 6. Scheduled jobs

- [ ] Add `scheduled-job-check`.
- [ ] Report failed systemd timer jobs and overdue runs against site expectations.
- [ ] Define success markers for cron jobs whose outcomes cannot otherwise be
  established reliably.
- [ ] Distinguish a configured schedule from evidence of a successful run.
- [ ] Document marker integration and verify missed, failed, and unknown runs.

## Phase 3: Combined reports and notifications

### 7. Combined VPS report

- [ ] Add `vps-report` to run selected toolkit checks.
- [ ] Produce a combined text/JSON report with per-command results and a
  documented aggregate exit-status policy.
- [ ] Bound check execution and preserve execution errors and unknown findings.
- [ ] Support site configuration and check selection without duplicating checks.
- [ ] Document usage and verify mixed results, missing dependencies, and timeouts.

### 8. Alert delivery

- [ ] Add opt-in delivery through configured notification channels.
- [ ] Notify on new failures and recoveries with deduplication and cooldowns.
- [ ] Store credentials outside the repository and redact notification payloads.
- [ ] Provide a preview mode and report delivery failures separately from findings.
- [ ] Document setup and verify repeated failures, recovery, and delivery errors.

## Phase 4: Maintenance and troubleshooting

### 9. Configuration drift

- [ ] Compare selected configuration hashes, installed packages, enabled
  services, and listeners against an explicit baseline.
- [ ] Support exclusions and deliberate baseline updates.
- [ ] Protect baseline data and avoid collecting secret configuration contents.
- [ ] Document usage and verify additions, removals, changes, and missing evidence.

### 10. Maintenance readiness

- [ ] Summarize pending updates, reboot requirements, backup freshness,
  available disk space, and required service health before maintenance.
- [ ] Reuse existing checks and apply configurable readiness expectations.
- [ ] Document usage and verify ready, blocked-by-policy, and unknown states.

### 11. Multiple-server reporting

- [ ] Collect reports over SSH using an inventory stored outside the repository.
- [ ] Support per-host timeouts, bounded concurrency, and clear unreachable-host
  results while retaining SSH host-key verification.
- [ ] Record toolkit versions and handle incompatible report schemas explicitly.
- [ ] Document setup and verify partial fleet failures and version differences.

### 12. Incident snapshots

- [ ] Capture bounded resource, service, and network diagnostics for troubleshooting.
- [ ] Support identifier redaction, restrictive artifact permissions, and
  documented retention expectations.
- [ ] Exclude credentials and raw sensitive logs by default.
- [ ] Document usage and verify partial capture, timeouts, and redaction.

## Phase 5: Portability and routine management

- [ ] Add a dependency/platform preflight that explains prerequisites for each
  command and reports unsupported environments clearly.
- [ ] Define and test a Linux distribution support matrix before advertising
  support beyond Debian/Ubuntu.
- [ ] Document verified checkout/release installation and upgrade workflows.
- [ ] Identify concrete routine management operations from administrator needs
  and add a separate checklist for each before implementation.
- [ ] For operations that modify a server, provide a reviewable plan, explicit
  `--apply`, interactive confirmation, and operation-specific recovery guidance
  consistent with the security model.

## Requirements for every new feature

- Follow the [security model](docs/security-model.md): checks are read-only;
  changes require the existing explicit-apply and confirmation contract.
- Reuse shared reporting and the [report hierarchy](docs/reporting-style.md),
  with consistent finding levels and documented exit codes.
- Offer text and structured JSON reports for reporting commands.
- Keep site expectations, credentials, inventories, and reports outside source
  control; parse configuration as data rather than executing it.
- Bound expensive work and distinguish unavailable evidence from a healthy result.
- Verify meaningful success/failure cases, pass ShellCheck and the relevant Bats
  tests, and update user documentation and the changelog before checking work off.

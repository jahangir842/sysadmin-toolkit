# Report visual hierarchy

All current and future toolkit commands should present interactive text reports
with the same visual hierarchy. The goal is a report that an administrator can
scan quickly during a terminal session while preserving precise findings for
automation.

## Required order

Use this order for text reports:

1. A blue title block with the report name.
2. Report context such as date, hostname, operating system, kernel, and uptime.
3. A separator followed by the PASS, WARN, FAIL, INFO, and UNKNOWN summary.
4. Yellow section headings in the form `[+] SECTION NAME`.
5. The detailed findings for that section.
6. A blue `END OF REPORT` block.

Only show context fields that apply to the command. Group related checks into a
small number of sections instead of printing one long list.

```text
==============================================
        SYSTEM SECURITY AUDIT REPORT
==============================================
Date:     2026-09-20T08:30:00Z
Hostname: example-host
OS:       Ubuntu 24.04 LTS
Kernel:   6.8.0-generic
Uptime:   up 7 weeks
----------------------------------------------
Summary:  2 PASS  3 WARN  1 FAIL  8 INFO  0 UNKNOWN
Result:   FAILURES NEED REVIEW

[+] AUDITING USER ACCOUNTS (UID >= 1000)...
----------------------------------------------
USERNAME        STATUS     GROUPS                                   LAST LOGIN
------------------------------------------------------------------------------------------------
operator        ACTIVE     operator sudo docker                     Sat Sep 19 14:26:25 2026

[+] SSH SECURITY CONFIGURATION
----------------------------------------------
SSH root login:                    PASS    effective permitrootlogin=no

==============================================
              END OF REPORT
==============================================
```

## Color rules

Apply color to information that carries meaning, not to every line:

- Blue: report title and footer.
- Yellow: `[+]` section headings and WARN values.
- Green: PASS values and active account status.
- Red: FAIL values, locked or passwordless account status, and membership in
  highly privileged groups such as `sudo` or `docker`.
- Magenta: UNKNOWN values.
- Blue: INFO values.

Always print the status word as well as its color. Color must never be the only
way a finding is communicated.

Enable ANSI colors only when standard output is an interactive terminal and
`NO_COLOR` is unset. `NO_COLOR=1`, redirected output, and piped output must stay
readable without escape sequences.

## Tables and labels

Use a table when a section repeats the same fields for several objects, such as
users, disks, containers, certificates, or backups. Keep headers uppercase,
left-align text fields, and place a separator immediately below the header.
Color individual values without disturbing column alignment.

For ordinary findings, use a stable human-readable label followed by the
severity and message. Keep labels aligned within a section. Messages should say
what was observed and provide context without claiming that a host is secure.
For example, report port 22 as the SSH default rather than claiming that a
different port is inherently safe.

## Text and JSON separation

Collect findings before rendering them. The text renderer owns headings,
alignment, colors, and the footer. Machine-readable output must contain no ANSI
escape sequences and must not depend on terminal column widths.

Adding or changing visual formatting must not change exit-code behavior:

- `0`: no FAIL findings.
- `1`: one or more FAIL findings.
- `2`: usage, configuration, platform, or execution error.

Use the shared functions in `lib/logging.sh` for common rendering behavior so
new commands do not create a different color palette or report structure.

## Sensitive output

Reports may contain hostnames, usernames, group memberships, addresses, and
operational details. Treat both text and JSON reports as sensitive data. The
visual design must not obscure or silently remove these fields.

# Release and deployment

## Tagged releases

Update `CHANGELOG.md`, run ShellCheck and Bats, review the Git diff and history
for client data, then create a signed semantic-version tag such as `v0.1.0`.
Build a source archive and a separate SHA-256 checksum file in CI or a clean
release workspace. Publishing remains a deliberate human action.

## Running a pinned Git checkout

Clone the repository and select a reviewed release tag before running the audit:

```sh
git clone https://github.com/jahangir842/sysadmin-toolkit.git
cd sysadmin-toolkit
git checkout v0.1.0
sudo ./bin/host-security-audit --format text
```

Verify the release tag through your trusted release process and review updates
before selecting a newer revision. Keep the repository layout intact so the
command can load its adjacent `lib/` files.

A client repository can record only non-secret provenance, for example:

```text
sysadmin-toolkit version: 0.1.0
git commit: <verified commit SHA>
checkout directory: <path to the Git checkout>
```

Do not copy site configuration, audit output, hostnames, addresses, or logs into
that record.

## Automating reports with cron

Cron can run the audit directly from a Git checkout. Use absolute paths and
root's crontab so the audit can inspect the host without a sudo password prompt.
The examples below assume the checkout is `/home/gciadmin/sysadmin-toolkit`;
replace that path with your actual checkout directory.

Create a private report directory and open root's crontab:

```sh
sudo install -d -o root -g root -m 0700 /var/log/sysadmin-toolkit
sudo crontab -e
```

Add the following lines to generate a JSON report every day at 02:00 in the
server's local timezone:

```cron
PATH=/usr/sbin:/usr/bin:/sbin:/bin
0 2 * * * umask 077; /home/gciadmin/sysadmin-toolkit/bin/host-security-audit --format json > /var/log/sysadmin-toolkit/audit-$(date +\%F).json 2> /var/log/sysadmin-toolkit/audit-$(date +\%F).err
```

Keep the backslashes before `%`: cron treats an unescaped `%` as a newline.
The command resolves its `lib/` files relative to the script, so cron does not
need to change into the checkout directory. For text reports, replace
`--format json` with `--format text` and the `.json` extension with `.txt`.
Rerunning the command on the same date overwrites that day's files.

Root executes the code in this checkout. Keep the checkout and its parent
directories writable only by trusted administrators. For unattended use,
prefer a dedicated root-owned checkout in a root-controlled directory and
update the cron path accordingly. Review updates before pulling them; do not
automatically pull new code in the cron job.

Reports contain sensitive host information. The directory permissions and
`umask` restrict access to root. Keep reports outside the repository and choose
a retention period appropriate for the host. To remove only matching report
files older than 30 days, optionally add this daily cleanup job:

```cron
0 3 * * * find /var/log/sysadmin-toolkit -maxdepth 1 -type f \( -name 'audit-*.json' -o -name 'audit-*.txt' -o -name 'audit-*.err' \) -mtime +30 -delete
```

An audit exit status of `1` means the report contains `FAIL` findings; `2` means
a usage, configuration, platform, or execution error. Check the report and
matching `.err` file after the first scheduled run. Cron does not automatically
alert on these exit statuses; configure monitoring separately if needed.

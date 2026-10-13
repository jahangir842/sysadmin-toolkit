#!/usr/bin/env bash

declare -a FINDING_LEVELS=() FINDING_CHECKS=() FINDING_MESSAGES=()
declare -a FINDING_DETAILS=() FINDING_REMEDIATIONS=()

add_finding() {
  local details=${4-}
  [[ -n $details ]] || details='{}'
  FINDING_LEVELS+=("$1")
  FINDING_CHECKS+=("$2")
  FINDING_MESSAGES+=("$3")
  FINDING_DETAILS+=("$details")
  FINDING_REMEDIATIONS+=("${5:-}")
}

json_escape() {
  local value=$1 character code output='' i
  LC_ALL=C
  for ((i = 0; i < ${#value}; i++)); do
    character=${value:i:1}
    case $character in
      '"') output+='\"' ;;
      $'\\') output+=$'\\' ;;
      $'\b') output+='\b' ;;
      $'\f') output+='\f' ;;
      $'\n') output+='\n' ;;
      $'\r') output+='\r' ;;
      $'\t') output+='\t' ;;
      *)
        printf -v code '%d' "'$character"
        if ((code < 32)); then
          printf -v character '\\u%04x' "$code"
        fi
        output+=$character
        ;;
    esac
  done
  printf '%s' "$output"
}

report_section() {
  case $1 in
    accounts|password-state|privileged-groups|last-login|account-identifiers|account-aging|sudo|authorized-keys) printf 'USER ACCOUNTS & PRIVILEGE' ;;
    ssh|ssh-root-login|ssh-password-auth|ssh-empty-passwords|ssh-port|ssh-listen-addresses|ssh-effective|ssh-user-config) printf 'SSH SECURITY CONFIGURATION' ;;
    listeners|firewall) printf 'NETWORK & FIREWALL STATUS' ;;
    updates|automatic-updates|reboot-required|lifecycle) printf 'UPDATES & PLATFORM SUPPORT' ;;
    apparmor|kernel-hardening|secure-boot) printf 'MANDATORY ACCESS & KERNEL' ;;
    sensitive-files|world-writable|privileged-files|mounts|encryption) printf 'FILESYSTEM & STORAGE' ;;
    persistence|fail2ban|ssh-auth-failures|system-errors|systemd|time-sync|journald|auditd|logrotate|log-space) printf 'SERVICES, LOGGING & SECURITY EVENTS' ;;
    disk-*) printf 'FILESYSTEM & STORAGE' ;;
    container-*) printf 'CONTAINER OPERATIONS' ;;
    baseline-diff) printf 'BASELINE COMPARISON' ;;
    *) printf 'OTHER CHECKS' ;;
  esac
}

report_label() {
  case $1 in
    host) printf 'Host' ;;
    accounts) printf 'Users found' ;;
    password-state) printf 'Account password status' ;;
    privileged-groups) printf 'Privileged group access' ;;
    last-login) printf 'Account login activity' ;;
    account-identifiers) printf 'Account identifier integrity' ;;
    account-aging) printf 'Account expiration and dormancy' ;;
    sudo) printf 'Sudo policy' ;;
    authorized-keys) printf 'Authorized SSH keys' ;;
    ssh) printf 'SSH configuration' ;;
    ssh-root-login) printf 'SSH root login' ;;
    ssh-password-auth) printf 'SSH password authentication' ;;
    ssh-empty-passwords) printf 'SSH empty passwords' ;;
    ssh-port) printf 'SSH port' ;;
    ssh-listen-addresses) printf 'SSH listen addresses' ;;
    ssh-effective) printf 'Effective SSH settings' ;;
    ssh-user-config) printf 'Per-user SSH settings' ;;
    listeners) printf 'Network listeners' ;;
    firewall) printf 'Firewall status' ;;
    updates) printf 'Security updates' ;;
    automatic-updates) printf 'Automatic updates' ;;
    reboot-required) printf 'Reboot requirement' ;;
    lifecycle) printf 'Distribution support' ;;
    apparmor) printf 'AppArmor confinement' ;;
    kernel-hardening) printf 'Kernel hardening' ;;
    secure-boot) printf 'Secure Boot' ;;
    sensitive-files) printf 'Sensitive file permissions' ;;
    world-writable) printf 'World-writable paths' ;;
    privileged-files) printf 'Privileged executables' ;;
    mounts) printf 'Mount protections' ;;
    encryption) printf 'Storage encryption' ;;
    persistence) printf 'Persistence mechanisms' ;;
    fail2ban) printf 'Fail2ban protection' ;;
    ssh-auth-failures) printf 'SSH authentication activity' ;;
    system-errors) printf 'High-severity system log entries' ;;
    systemd) printf 'System services' ;;
    time-sync) printf 'Time synchronization' ;;
    journald) printf 'Journal persistence' ;;
    auditd) printf 'Audit service' ;;
    logrotate) printf 'Log rotation' ;;
    log-space) printf 'Log filesystem capacity' ;;
    disk-space) printf 'Disk space (bytes)' ;;
    disk-inodes) printf 'Inode capacity (counts)' ;;
    disk-mount) printf 'Mount state' ;;
    disk-discovery) printf 'Directory sizes' ;;
    baseline-diff) printf 'Baseline difference' ;;
    *) printf '%s' "$1" ;;
  esac
}

level_color() {
  [[ ${REPORT_COLORS:-no} == yes ]] || return 0
  case $1 in
    PASS) printf '\033[0;32m' ;;
    WARN) printf '\033[1;33m' ;;
    FAIL) printf '\033[0;31m' ;;
    INFO) printf '\033[0;34m' ;;
    UNKNOWN) printf '\033[0;35m' ;;
  esac
}

render_account_table() {
  local message=$1 reset=$2 green=$3 red=$4 yellow=$5
  local summary rows='' username status groups last_login status_color group_color
  summary=${message%%$'\n'*}
  printf '%s\n' "$summary"
  printf '%-15s %-10s %-40s %s\n' 'USERNAME' 'STATUS' 'GROUPS' 'LAST LOGIN'
  printf '%s\n' '------------------------------------------------------------------------------------------------'
  [[ $message == *$'\n'* ]] || return 0
  rows=${message#*$'\n'}
  while IFS=$'\t' read -r username status groups last_login; do
    status_color=$yellow
    case $status in ACTIVE) status_color=$green ;; LOCKED|NO_PASSWORD) status_color=$red ;; esac
    group_color=
    [[ " $groups " == *' sudo '* || " $groups " == *' docker '* ]] && group_color=$red
    printf '%-15s %s%-10s%s %s%-40s%s %s\n' \
      "$username" "$status_color" "$status" "$reset" \
      "$group_color" "$groups" "$reset" "$last_login"
  done <<<"$rows"
}

render_container_metrics_table() {
  local check=$1 details=$2
  jq -r --arg check "$check" '
    def cell: if . == null or . == "" then "unknown" else tostring end;
    (if $check == "container-resources" then
      [["CONTAINER", "CPU", "MEMORY / LIMIT", "MEMORY %", "PIDS"]] +
      [sort_by(.container)[] | [.container, .cpu, .memory, .memory_percent, .pids] | map(cell)]
    else
      [["TYPE", "TOTAL", "ACTIVE", "SIZE", "RECLAIMABLE"]] +
      [.[] | [.type, .total, .active, .size, .reclaimable] | map(cell)]
    end) | . as $rows |
    [range(0; 5) as $column | [$rows[] | .[$column] | length] | max] as $widths |
    $rows[] | . as $row |
    "  " + ([range(0; 5) as $column |
      $row[$column] + (if $column < 4 then
        " " * ($widths[$column] - ($row[$column] | length)) else "" end)] |
      join("  "))' <<<"$details"
}

render_text() {
  local i level color reset blue yellow green red bold section previous_section='' check message remediation
  local host_message='' hostname=unknown timestamp=unknown os=unknown kernel=unknown uptime=unknown
  local pass_count=0 warn_count=0 fail_count=0 info_count=0 unknown_count=0
  local total=${#FINDING_LEVELS[@]}
  local container_heading prefix
  REPORT_COLORS=no
  if [[ -t 1 && ${NO_COLOR:-} == "" ]]; then REPORT_COLORS=yes; fi

  for level in "${FINDING_LEVELS[@]}"; do
    case $level in
      PASS) ((pass_count += 1)) ;;
      WARN) ((warn_count += 1)) ;;
      FAIL) ((fail_count += 1)) ;;
      INFO) ((info_count += 1)) ;;
      UNKNOWN) ((unknown_count += 1)) ;;
    esac
  done

  if [[ $REPORT_COLORS == yes ]]; then
    red=$'\033[0;31m'; green=$'\033[0;32m'; yellow=$'\033[1;33m'
    blue=$'\033[0;34m'; bold=$'\033[1m'; reset=$'\033[0m'
  else
    red=; green=; yellow=; blue=; bold=; reset=
  fi

  for ((i = 0; i < total; i++)); do
    if [[ ${FINDING_CHECKS[$i]} == host ]]; then host_message=${FINDING_MESSAGES[$i]}; break; fi
  done
  hostname=${host_message#*hostname=}; hostname=${hostname%% timestamp=*}
  timestamp=${host_message#* timestamp=}; timestamp=${timestamp%% os=*}
  os=${host_message#* os=}; os=${os%% kernel=*}
  kernel=${host_message#* kernel=}; kernel=${kernel%% uptime=*}
  uptime=${host_message#* uptime=}

  printf '\n%s==============================================%s\n' "$blue" "$reset"
  printf '%s        %-38s%s\n' "$blue" "${REPORT_TITLE:-SYSTEM SECURITY AUDIT REPORT}" "$reset"
  printf '%s==============================================%s\n' "$blue" "$reset"
  printf 'Date:     %s\n' "$timestamp"
  printf 'Hostname: %s\n' "$hostname"
  printf 'OS:       %s\n' "$os"
  printf 'Kernel:   %s\n' "$kernel"
  printf 'Uptime:   %s\n' "$uptime"
  printf '%s\n' '----------------------------------------------'
  printf 'Summary:  %s%d PASS%s  %s%d WARN%s  %s%d FAIL%s  %d INFO  %d UNKNOWN\n' \
    "$green" "$pass_count" "$reset" "$yellow" "$warn_count" "$reset" \
    "$red" "$fail_count" "$reset" "$info_count" "$unknown_count"
  if ((fail_count > 0)); then
    printf 'Result:   %s%sFAILURES NEED REVIEW%s\n' "$red" "$bold" "$reset"
  elif ((warn_count > 0 || unknown_count > 0)); then
    printf 'Result:   %s%sREVIEW RECOMMENDED%s\n' "$yellow" "$bold" "$reset"
  else
    printf 'Result:   %sNO FAIL FINDINGS%s\n' "$green" "$reset"
  fi

  for ((i = 0; i < total; i++)); do
    level=${FINDING_LEVELS[$i]}
    check=${FINDING_CHECKS[$i]}
    message=${FINDING_MESSAGES[$i]}
    remediation=${FINDING_REMEDIATIONS[$i]}
    [[ $check == host ]] && continue
    section=$(report_section "$check")
    if [[ ${TOOLKIT_TOOL:-} == container-health-check ]]; then
      container_heading=$(jq -r 'if type == "object" and .project != null and .container != null
        then "[\(.project)/\(.container)]" else "" end' <<<"${FINDING_DETAILS[$i]}")
      if [[ -n $container_heading ]]; then
        section=$container_heading
        prefix="$container_heading "
        message=${message#"$prefix"}
      fi
    fi
    if [[ $section != "$previous_section" ]]; then
      printf '\n%s[+] %s%s\n' "$yellow" "$section" "$reset"
      printf '%s\n' '----------------------------------------------'
      previous_section=$section
    fi

    if [[ $check == accounts ]]; then
      render_account_table "$message" "$reset" "$green" "$red" "$yellow"
      continue
    fi

    color=$(level_color "$level")
    if [[ ${TOOLKIT_TOOL:-} == container-health-check &&
      ( $check == container-resources || $check == container-storage ) ]] &&
      jq -e 'type == "array"' <<<"${FINDING_DETAILS[$i]}" >/dev/null; then
      if [[ $check == container-resources ]]; then
        message='Current resource snapshot (not historical utilization)'
      else
        message='Docker disk usage (reclaimable does not mean safe to delete)'
      fi
      printf '%-34s %s%-7s%s %s\n' "$(report_label "$check"):" "$color" "$level" "$reset" "$message"
      render_container_metrics_table "$check" "${FINDING_DETAILS[$i]}"
      printf '\n'
      continue
    fi
    printf '%-34s %s%-7s%s %s\n' "$(report_label "$check"):" "$color" "$level" "$reset" "$message"
    [[ -z $remediation ]] || printf '%-34s %s\n' '  Remediation:' "$remediation"
  done

  printf '\n%s==============================================%s\n' "$blue" "$reset"
  printf '%s              END OF REPORT                   %s\n' "$blue" "$reset"
  printf '%s==============================================%s\n' "$blue" "$reset"
}

render_json() {
  local i comma='' details
  printf '{"schema_version":2,"tool":"%s","version":"%s","findings":[' "$(json_escape "${TOOLKIT_TOOL:-host-security-audit}")" "$(json_escape "$TOOLKIT_VERSION")"
  for ((i = 0; i < ${#FINDING_LEVELS[@]}; i++)); do
    details=${FINDING_DETAILS[$i]}
    case $details in \{*\}|\[*\]) ;; *) details='{}' ;; esac
    printf '%s{"id":"%s","level":"%s","check":"%s","summary":"%s","message":"%s","details":%s,"remediation":"%s"}' \
      "$comma" "$(json_escape "${FINDING_CHECKS[$i]}")" \
      "$(json_escape "${FINDING_LEVELS[$i]}")" \
      "$(json_escape "${FINDING_CHECKS[$i]}")" "$(json_escape "${FINDING_MESSAGES[$i]}")" \
      "$(json_escape "${FINDING_MESSAGES[$i]}")" "$details" "$(json_escape "${FINDING_REMEDIATIONS[$i]}")"
    comma=,
  done
  printf ']}\n'
}

findings_exit_code() {
  local level
  for level in "${FINDING_LEVELS[@]}"; do
    [[ $level == FAIL ]] && return 1
    [[ ${REPORT_FAIL_ON_LEVEL:-fail} == warn && $level == WARN ]] && return 1
  done
  return 0
}

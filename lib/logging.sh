#!/usr/bin/env bash

declare -a FINDING_LEVELS=() FINDING_CHECKS=() FINDING_MESSAGES=()

add_finding() {
  FINDING_LEVELS+=("$1")
  FINDING_CHECKS+=("$2")
  FINDING_MESSAGES+=("$3")
}

json_escape() {
  local value=$1
  value=${value//\\/\\\\}; value=${value//\"/\\\"}
  value=${value//$'\n'/\\n}; value=${value//$'\r'/\\r}; value=${value//$'\t'/\\t}
  printf '%s' "$value"
}

report_section() {
  case $1 in
    accounts|password-state|privileged-groups|last-login) printf 'AUDITING USER ACCOUNTS (UID >= 1000)...' ;;
    ssh|ssh-root-login|ssh-password-auth|ssh-port|ssh-listen-addresses|ssh-effective|ssh-user-config) printf 'SSH SECURITY CONFIGURATION' ;;
    listeners|firewall) printf 'NETWORK & FIREWALL STATUS' ;;
    fail2ban|ssh-auth-failures|system-errors|systemd) printf 'SERVICES & SECURITY EVENTS' ;;
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
    ssh) printf 'SSH configuration' ;;
    ssh-root-login) printf 'SSH root login' ;;
    ssh-password-auth) printf 'SSH password authentication' ;;
    ssh-port) printf 'SSH port' ;;
    ssh-listen-addresses) printf 'SSH listen addresses' ;;
    ssh-effective) printf 'Effective SSH settings' ;;
    ssh-user-config) printf 'Per-user SSH settings' ;;
    listeners) printf 'Network listeners' ;;
    firewall) printf 'Firewall status' ;;
    fail2ban) printf 'Fail2ban protection' ;;
    ssh-auth-failures) printf 'SSH authentication activity' ;;
    system-errors) printf 'High-severity system log entries' ;;
    systemd) printf 'System services' ;;
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
  local summary rows= username status groups last_login status_color group_color
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

render_text() {
  local i level color reset blue yellow green red bold section previous_section= check message
  local host_message= hostname=unknown timestamp=unknown os=unknown kernel=unknown uptime=unknown
  local pass_count=0 warn_count=0 fail_count=0 info_count=0 unknown_count=0
  local total=${#FINDING_LEVELS[@]}
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
  printf '%s        SYSTEM SECURITY AUDIT REPORT          %s\n' "$blue" "$reset"
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
    [[ $check == host ]] && continue
    section=$(report_section "$check")
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
    printf '%-34s %s%-7s%s %s\n' "$(report_label "$check"):" "$color" "$level" "$reset" "$message"
  done

  printf '\n%s==============================================%s\n' "$blue" "$reset"
  printf '%s              END OF REPORT                   %s\n' "$blue" "$reset"
  printf '%s==============================================%s\n' "$blue" "$reset"
}

render_json() {
  local i comma=
  printf '{"tool":"host-security-audit","version":"%s","findings":[' "$(json_escape "$TOOLKIT_VERSION")"
  for ((i = 0; i < ${#FINDING_LEVELS[@]}; i++)); do
    printf '%s{"level":"%s","check":"%s","message":"%s"}' \
      "$comma" "$(json_escape "${FINDING_LEVELS[$i]}")" \
      "$(json_escape "${FINDING_CHECKS[$i]}")" "$(json_escape "${FINDING_MESSAGES[$i]}")"
    comma=,
  done
  printf ']}\n'
}

findings_exit_code() {
  local level
  for level in "${FINDING_LEVELS[@]}"; do [[ $level == FAIL ]] && return 1; done
  return 0
}

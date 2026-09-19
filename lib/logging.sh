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
    host|accounts|password-state|privileged-groups|last-login) printf 'HOST AND ACCOUNTS' ;;
    ssh|ssh-root-login|ssh-password-auth|ssh-listen|ssh-effective|ssh-user-config) printf 'SSH SECURITY' ;;
    listeners|firewall) printf 'NETWORK AND FIREWALL' ;;
    fail2ban|ssh-auth-failures|system-errors|systemd) printf 'SERVICES AND SYSTEM LOGS' ;;
    *) printf 'OTHER CHECKS' ;;
  esac
}

report_label() {
  case $1 in
    host) printf 'Host' ;;
    accounts) printf 'Interactive accounts' ;;
    password-state) printf 'Account password status' ;;
    privileged-groups) printf 'Privileged group access' ;;
    last-login) printf 'Account login activity' ;;
    ssh) printf 'SSH configuration' ;;
    ssh-root-login) printf 'SSH root login' ;;
    ssh-password-auth) printf 'SSH password authentication' ;;
    ssh-listen) printf 'SSH listening settings' ;;
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

render_text() {
  local i level color reset bold title_color section previous_section=
  local pass_count=0 warn_count=0 fail_count=0 info_count=0 unknown_count=0
  local total=${#FINDING_LEVELS[@]}
  local colors=no
  if [[ -t 1 && ${NO_COLOR:-} == "" ]]; then colors=yes; fi

  for level in "${FINDING_LEVELS[@]}"; do
    case $level in
      PASS) ((pass_count += 1)) ;;
      WARN) ((warn_count += 1)) ;;
      FAIL) ((fail_count += 1)) ;;
      INFO) ((info_count += 1)) ;;
      UNKNOWN) ((unknown_count += 1)) ;;
    esac
  done

  if [[ $colors == yes ]]; then
    bold=$'\033[1m'; reset=$'\033[0m'; title_color=$'\033[36m'
  else
    bold=; reset=; title_color=
  fi
  printf '%s%s%s\n' "$bold" '============================================================' "$reset"
  printf '%s%s%s\n' "$bold" '                 HOST SECURITY AUDIT REPORT' "$reset"
  printf '%s%s%s\n' "$bold" '============================================================' "$reset"
  printf 'Summary: %d findings  |  %d PASS  %d WARN  %d FAIL  %d INFO  %d UNKNOWN\n' \
    "$total" "$pass_count" "$warn_count" "$fail_count" "$info_count" "$unknown_count"
  if ((fail_count > 0)); then
    printf 'Result: %sFAILURES NEED REVIEW%s\n' "$([[ $colors == yes ]] && printf '\033[31m\033[1m')" "$reset"
  elif ((warn_count > 0 || unknown_count > 0)); then
    printf 'Result: %sREVIEW RECOMMENDED%s\n' "$([[ $colors == yes ]] && printf '\033[33m\033[1m')" "$reset"
  else
    printf 'Result: No FAIL findings reported.\n'
  fi

  for ((i = 0; i < total; i++)); do
    level=${FINDING_LEVELS[$i]}
    section=$(report_section "${FINDING_CHECKS[$i]}")
    if [[ $section != "$previous_section" ]]; then
      printf '\n%s%s[%s]%s\n' "$title_color" "$bold" "$section" "$reset"
      previous_section=$section
    fi

    color=
    if [[ $colors == yes ]]; then
      case $level in
        PASS) color=$'\033[32m' ;; WARN) color=$'\033[33m' ;;
        FAIL) color=$'\033[31m' ;; INFO) color=$'\033[36m' ;;
        UNKNOWN) color=$'\033[35m' ;;
      esac
    fi
    printf '  %s[%-7s]%s %-32s %s\n' "$color" "$level" "$reset" \
      "$(report_label "${FINDING_CHECKS[$i]}"):" "${FINDING_MESSAGES[$i]}"
  done
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

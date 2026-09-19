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

render_text() {
  local i level color reset
  for ((i = 0; i < ${#FINDING_LEVELS[@]}; i++)); do
    level=${FINDING_LEVELS[$i]}; color=; reset=
    if [[ -t 1 && ${NO_COLOR:-} == "" ]]; then
      reset=$'\033[0m'
      case $level in
        PASS) color=$'\033[32m' ;; WARN) color=$'\033[33m' ;;
        FAIL) color=$'\033[31m' ;; INFO) color=$'\033[36m' ;;
        UNKNOWN) color=$'\033[35m' ;;
      esac
    fi
    printf '%s%-7s%s %-24s %s\n' "$color" "$level" "$reset" \
      "${FINDING_CHECKS[$i]}" "${FINDING_MESSAGES[$i]}"
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

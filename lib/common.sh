#!/usr/bin/env bash

# shellcheck disable=SC2034 # Used by scripts that source this library.
TOOLKIT_VERSION="0.1.0"

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

command_exists() {
  if [[ ${SYSADMIN_TOOLKIT_TESTING:-0} == 1 && ",${SYSADMIN_TOOLKIT_DISABLED_COMMANDS:-}," == *",$1,"* ]]; then
    return 1
  fi
  command -v "$1" >/dev/null 2>&1
}
require_command() { command_exists "$1" || die "required command not found: $1"; }
is_safe_name() { [[ $1 =~ ^[a-zA-Z0-9_.-]+$ ]]; }
root_path() { printf '%s%s' "${SYSADMIN_TOOLKIT_ROOT:-}" "$1"; }

make_temp_dir() {
  TOOLKIT_TMPDIR=$(mktemp -d "${TMPDIR:-/tmp}/sysadmin-toolkit.XXXXXXXX") ||
    die "unable to create secure temporary directory"
  chmod 700 "$TOOLKIT_TMPDIR" || die "unable to protect temporary directory"
  trap 'rm -rf -- "${TOOLKIT_TMPDIR:-}"' EXIT HUP INT TERM
}

validate_config_file() {
  local file=$1 mode owner
  [[ -f $file ]] || die "configuration file not found: $file"
  if [[ ${SYSADMIN_TOOLKIT_TESTING:-0} != 1 ]]; then
    owner=$(stat -c '%u' "$file") || die "cannot inspect configuration ownership"
    mode=$(stat -c '%a' "$file") || die "cannot inspect configuration permissions"
    [[ $owner == 0 ]] || die "configuration must be owned by root: $file"
    (( (8#$mode & 8#022) == 0 )) || die "configuration must not be group/world writable: $file"
  fi
}

load_config() {
  local file=$1 line key value line_number=0 forbidden_subshell forbidden_backtick
  forbidden_subshell=\$\(
  forbidden_backtick=\`
  validate_config_file "$file"
  declare -F apply_config_value >/dev/null || die "configuration handler is unavailable"
  while IFS= read -r line || [[ -n $line ]]; do
    ((line_number += 1))
    line=${line%%#*}
    [[ $line =~ ^[[:space:]]*$ ]] && continue
    if [[ ! $line =~ ^[[:space:]]*([A-Z][A-Z0-9_]*)[[:space:]]*=[[:space:]]*(.*)$ ]]; then
      die "invalid configuration syntax at $file:$line_number"
    fi
    key=${BASH_REMATCH[1]}
    value=${BASH_REMATCH[2]}
    value=${value%"${value##*[![:space:]]}"}
    if [[ $value == \"*\" && $value == *\" ]]; then value=${value:1:${#value}-2}; fi
    if [[ $value == \'*\' && $value == *\' ]]; then value=${value:1:${#value}-2}; fi
    [[ $value != *"$forbidden_subshell"* && $value != *"$forbidden_backtick"* ]] ||
      die "command syntax is forbidden in configuration at $file:$line_number"
    apply_config_value "$key" "$value" || die "invalid configuration at $file:$line_number"
  done <"$file"
}

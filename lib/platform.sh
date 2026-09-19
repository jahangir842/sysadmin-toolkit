#!/usr/bin/env bash

# shellcheck disable=SC2034 # PLATFORM_ID is consumed by callers.
detect_platform() {
  local os_file id like
  os_file=$(root_path /etc/os-release)
  [[ -r $os_file ]] || return 2
  id=$(awk -F= '$1 == "ID" {gsub(/\"/, "", $2); print tolower($2)}' "$os_file")
  like=$(awk -F= '$1 == "ID_LIKE" {gsub(/\"/, "", $2); print tolower($2)}' "$os_file")
  case " $id $like " in
    *" debian "*|*" ubuntu "*) PLATFORM_ID=$id; return 0 ;;
    *) PLATFORM_ID=${id:-unknown}; return 1 ;;
  esac
}

os_pretty_name() {
  awk -F= '$1 == "PRETTY_NAME" {sub(/^[^=]*=/, ""); gsub(/^\"|\"$/, ""); print}' \
    "$(root_path /etc/os-release)"
}

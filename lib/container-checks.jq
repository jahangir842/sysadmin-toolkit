def finding($level; $check; $message; $details):
  {level: $level, check: $check, message: $message, details: $details};
. as $containers |
(if length == 0 then finding("INFO"; "container-health"; "no containers found"; {}) else empty end),
($expected | split(",")[] | select(length > 0) | . as $name |
  if any($containers[]; .name == $name and .state == "running") then
    finding("PASS"; "container-expected"; "expected container running: \($name)"; {container: $name})
  else finding("FAIL"; "container-expected"; "expected container missing or stopped: \($name)"; {container: $name}) end),
($containers[] | . as $c | "[\(.project)/\(.name)]" as $label |
  {container: .name, id: .id, project: .project} as $d |
  finding((if .state == "restarting" or .state == "dead" or .health == "unhealthy" then "FAIL" elif .state == "running" and .health == "healthy" then "PASS" elif .state == "running" then "UNKNOWN" else "INFO" end); "container-health"; "\($label) state=\(.state) health=\(.health) exit=\(.exit_code)"; $d),
  (if .oom then finding("FAIL"; "container-restarts"; "\($label) last state records an OOM kill"; $d) else empty end),
  finding("INFO"; "container-restarts"; "\($label) restart count=\(.restarts) (lifetime counter)"; $d),
  ($previous[0][] | select(.id == $c.id) |
    if $c.restarts > .restarts then finding("WARN"; "container-restarts"; "\($label) new restarts=\($c.restarts - .restarts)"; $d)
    elif $c.restarts < .restarts then finding("INFO"; "container-restarts"; "\($label) restart counter decreased"; $d) else empty end),
  (if .state == "running" then
    (if (.memory_limit // 0) == 0 then finding("WARN"; "container-resources"; "\($label) no memory limit"; $d) else empty end),
    (if (.cpu_limit // 0) == 0 and (.cpu_quota // 0) <= 0 and (.cpu_set // "") == "" then finding("WARN"; "container-resources"; "\($label) no CPU limit or CPU set"; $d) else empty end)
  else empty end),
  (if .privileged then finding("WARN"; "container-security"; "\($label) privileged container"; $d) else empty end),
  (if .user == "" or (.user | split(":")[0]) == "root" or (.user | split(":")[0]) == "0" then finding("WARN"; "container-security"; "\($label) configured root/default user; runtime user may differ"; $d) else empty end),
  (if .network_mode == "host" or .pid_mode == "host" or .ipc_mode == "host" then finding("WARN"; "container-security"; "\($label) host namespace enabled"; $d) else empty end),
  (if (.capabilities | length) > 0 then finding("WARN"; "container-security"; "\($label) added capabilities: \(.capabilities | join(","))"; $d) else empty end),
  (.mounts[] | select(.source | test("(^|/)(docker|podman)\\.sock$")) | finding("WARN"; "container-security"; "\($label) container engine socket mounted (including read-only mounts)"; $d)),
  (.ports | to_entries[] | .key as $port | .value[]? |
    finding((if .HostIp == "0.0.0.0" or .HostIp == "::" or .HostIp == "" then "WARN" else "INFO" end); "container-network"; "\($label) published \(.HostIp):\(.HostPort) -> \($port); verify intended exposure"; $d)),
  (if .log_driver == "json-file" and ((.log_options["max-size"] // "") == "" or .log_options["max-size"] == "-1") then finding("WARN"; "container-logging"; "\($label) json-file logging without a size limit"; $d)
   elif .log_driver == "none" then finding("INFO"; "container-logging"; "\($label) Docker logging disabled"; $d)
   else finding("INFO"; "container-logging"; "\($label) logging driver=\(.log_driver); verify retention policy"; $d) end),
  finding("INFO"; "container-persistence"; "\($label) mounts=\(.mounts | length); backup coverage requires site policy"; ($d + {mounts: .mounts}))
)

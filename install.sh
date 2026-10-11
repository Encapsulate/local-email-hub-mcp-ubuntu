#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
venv_dir="$project_root/.venv"
config_dir="$HOME/.config/linux-email-hub"
data_dir="$HOME/.local/share/linux-email-hub"
bin_dir="$HOME/.local/bin"
unit_dir="$HOME/.config/systemd/user"
unit_path="$unit_dir/linux-email-hub.service"

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required. On Ubuntu: sudo apt install python3 python3-venv" >&2
  exit 2
fi

python3 - <<'PY'
import sys
if sys.version_info < (3, 11):
    raise SystemExit("Python 3.11 or newer is required")
PY

python3 -m venv "$venv_dir"
if command -v uv >/dev/null 2>&1; then
  uv sync --project "$project_root" --frozen --no-dev
else
  "$venv_dir/bin/python" -m pip install "$project_root"
fi

install -d -m 0700 "$config_dir" "$data_dir" "$data_dir/backups" "$bin_dir" "$unit_dir"

write_wrapper() {
  local name="$1"
  local target="$2"
  local temporary
  temporary="$(mktemp "$bin_dir/.${name}.XXXXXX")"
  chmod 0700 "$temporary"
  printf '#!/bin/sh\nexec "%s" "$@"\n' "$target" >"$temporary"
  mv -f -- "$temporary" "$bin_dir/$name"
}

write_wrapper email-hub-configure "$venv_dir/bin/email-hub-configure"
write_wrapper email-hub-approve "$venv_dir/bin/email-hub-approve"

status_temp="$(mktemp "$bin_dir/.email-hub-status.XXXXXX")"
chmod 0700 "$status_temp"
printf '#!/bin/sh\nexec "%s" --health "$@"\n' "$venv_dir/bin/linux-email-hub" >"$status_temp"
mv -f -- "$status_temp" "$bin_dir/email-hub-status"

unit_temp="$(mktemp "$unit_dir/.linux-email-hub.service.XXXXXX")"
chmod 0600 "$unit_temp"
cat >"$unit_temp" <<EOF
[Unit]
Description=Local Email Hub MCP — Ubuntu Edition
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=$venv_dir/bin/linux-email-hub
Restart=on-failure
RestartSec=5
UMask=0077
NoNewPrivileges=true
PrivateTmp=true
PrivateDevices=true
ProtectSystem=strict
ProtectHome=read-only
ReadWritePaths=$data_dir
RestrictSUIDSGID=true
LockPersonality=true
MemoryDenyWriteExecute=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6

[Install]
WantedBy=default.target
EOF
mv -f -- "$unit_temp" "$unit_path"

systemctl --user daemon-reload
systemctl --user enable --now linux-email-hub.service

for _ in {1..40}; do
  if "$venv_dir/bin/python" "$project_root/verify_mcp.py" >/dev/null 2>&1; then
    break
  fi
  sleep 0.25
done

"$venv_dir/bin/python" "$project_root/verify_mcp.py"

cat <<'EOF'

Installed successfully. No mailbox credential was requested or copied.

Next:
  1. Create a Google app password.
  2. Run: email-hub-configure
  3. Run: email-hub-status
  4. Register http://127.0.0.1:18477/mcp in a trusted local MCP client.

If ~/.local/bin is not on PATH, open a new login shell or invoke the commands
with their full path under ~/.local/bin.
EOF

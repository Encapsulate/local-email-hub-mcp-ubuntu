#!/usr/bin/env bash
set -euo pipefail

bin_dir="$HOME/.local/bin"
unit_dir="$HOME/.config/systemd/user"

systemctl --user disable --now linux-email-hub.service 2>/dev/null || true

unit_path="$unit_dir/linux-email-hub.service"
if [[ -f "$unit_path" ]] && grep -q 'Local Email Hub MCP' "$unit_path"; then
  rm -f -- "$unit_path"
fi

for command_name in email-hub-configure email-hub-status email-hub-approve; do
  command_path="$bin_dir/$command_name"
  if [[ -f "$command_path" ]] && grep -q 'email-hub' "$command_path"; then
    rm -f -- "$command_path"
  fi
done

systemctl --user daemon-reload

cat <<'EOF'
The service and command wrappers were removed.

Private configuration and state were preserved intentionally:
  ~/.config/linux-email-hub/
  ~/.local/share/linux-email-hub/

Review those paths and remove them manually only if you no longer need the
credential, outbound queue, audit state, or backups.
EOF

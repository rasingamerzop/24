#!/usr/bin/env bash
# ZYNEX v2.0 - Upgraded script with ZynexFetch and admin mode
# Save as: zynex_v2.sh
set -o errexit
set -o pipefail
set -o nounset

# -----------------------
# Config
# -----------------------
CONFIG_DIR="${HOME}/.zynex"
FETCH_DIR="${CONFIG_DIR}/fetch"
CONFIG_FILE="${CONFIG_DIR}/config"
LOG_FILE="${CONFIG_DIR}/zynex.log"
MENU_FILE="${PWD}/menu.txt"
SELF_PATH="$(realpath "$0")"
UPDATE_CHECK_URL="${UPDATE_CHECK_URL:-https://raw.githubusercontent.com/youruser/yourrepo/main/zynex_v2.sh}"
DEFAULT_ADMIN_EMAIL="admin@zynexcode.com"
DEFAULT_ADMIN_PW="zynex@123"
THEME_DEFAULT="neon"

mkdir -p "${CONFIG_DIR}"
mkdir -p "${FETCH_DIR}"
touch "${LOG_FILE}"

# -----------------------
# Themes & Colors
# -----------------------
declare -A THEME_COLORS_NEON=(
  ["RED"]="\e[31m" ["GRN"]="\e[32m" ["YEL"]="\e[33m" ["CYN"]="\e[36m" ["WHT"]="\e[97m" ["BOLD"]="\e[1m" ["RESET"]="\e[0m"
)
declare -A THEME_COLORS_DARK=(
  ["RED"]="\e[91m" ["GRN"]="\e[92m" ["YEL"]="\e[93m" ["CYN"]="\e[96m" ["WHT"]="\e[37m" ["BOLD"]="\e[1m" ["RESET"]="\e[0m"
)
declare -A THEME_COLORS_LIGHT=(
  ["RED"]="\e[31m" ["GRN"]="\e[32m" ["YEL"]="\e[33m" ["CYN"]="\e[36m" ["WHT"]="\e[30m" ["BOLD"]="\e[1m" ["RESET"]="\e[0m"
)

# -----------------------
# Load or create config
# -----------------------
if [[ -f "${CONFIG_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${CONFIG_FILE}"
else
  THEME="${THEME:-$THEME_DEFAULT}"
  ADMIN_EMAIL="${ADMIN_EMAIL:-$DEFAULT_ADMIN_EMAIL}"
  # create hashed password for default password
  ADMIN_PWHASH="${ADMIN_PWHASH:-}"
  if [[ -z "${ADMIN_PWHASH}" ]]; then
    # create hashed default password
    ADMIN_PWHASH="$(printf '%s' "${DEFAULT_ADMIN_PW}" | sha256sum | awk '{print $1}')"
  fi
  cat > "${CONFIG_FILE}" <<EOF
# ZYNEX CONFIG
THEME="${THEME}"
ADMIN_EMAIL="${ADMIN_EMAIL:-$DEFAULT_ADMIN_EMAIL}"
ADMIN_PWHASH="${ADMIN_PWHASH}"
EOF
fi

apply_theme() {
  case "${THEME}" in
    neon) theme_map=THEME_COLORS_NEON;;
    dark) theme_map=THEME_COLORS_DARK;;
    light) theme_map=THEME_COLORS_LIGHT;;
    *) theme_map=THEME_COLORS_NEON;;
  esac
  for k in RED GRN YEL CYN WHT BOLD RESET; do
    declare -g "${k}"="${!theme_map[$k]}"
  done
}
apply_theme

log() {
  local ts; ts=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$ts] $*" | tee -a "${LOG_FILE}"
}

# -----------------------
# Utilities
# -----------------------
typewriter() { local text="$1"; local delay="${2:-0.007}"; local i; for ((i=0;i<${#text};i++)); do printf "%s" "${text:$i:1}"; sleep "${delay}"; done; printf "\n"; }
prompt_confirm() { local response; read -r -p "$1 [y/N]: " response; case "$response" in [yY]|[yY][eE][sS]) return 0;; *) return 1;; esac; }
ensure_command() { local cmd="$1"; if ! command -v "$cmd" >/dev/null 2>&1; then echo -e "${YEL}Command '$cmd' not found. Attempting to install...${RESET}"; if command -v apt-get >/dev/null 2>&1; then sudo apt-get update && sudo apt-get install -y "$cmd"; elif command -v yum >/dev/null 2>&1; then sudo yum install -y "$cmd"; elif command -v dnf >/dev/null 2>&1; then sudo dnf install -y "$cmd"; else echo -e "${RED}Install $cmd manually.${RESET}"; return 1; fi; fi; return 0; }
hash_password() { local pw="$1"; if command -v sha256sum >/dev/null 2>&1; then printf '%s' "$pw" | sha256sum | cut -d' ' -f1; else printf '%s' "$pw" | sha1sum | cut -d' ' -f1; fi; }
save_config() { cat > "${CONFIG_FILE}" <<EOF
# ZYNEX CONFIG
THEME="${THEME}"
ADMIN_EMAIL="${ADMIN_EMAIL}"
ADMIN_PWHASH="${ADMIN_PWHASH}"
EOF
apply_theme; }

init_admin_if_needed() {
  if [[ -z "${ADMIN_PWHASH:-}" ]]; then
    ADMIN_EMAIL="${ADMIN_EMAIL:-$DEFAULT_ADMIN_EMAIL}"
    ADMIN_PWHASH="$(hash_password "${DEFAULT_ADMIN_PW}")"
    save_config
  fi
}

admin_login() {
  init_admin_if_needed
  echo -n "Admin email: "
  read -r entered_email
  read -r -s -p "Admin password: " pw
  printf "\n"
  if [[ "${entered_email}" != "${ADMIN_EMAIL}" ]]; then
    echo -e "${RED}Wrong email.${RESET}"
    return 1
  fi
  if [[ "$(hash_password "$pw")" == "${ADMIN_PWHASH}" ]]; then
    log "Admin login successful for ${entered_email}"
    echo -e "${GRN}Admin mode unlocked.${RESET}"
    return 0
  else
    echo -e "${RED}Wrong password.${RESET}"
    return 1
  fi
}

change_admin_password() {
  echo "Change admin password"
  read -r -s -p "New password: " p1; printf "\n"
  read -r -s -p "Confirm: " p2; printf "\n"
  if [[ "$p1" != "$p2" ]]; then echo -e "${RED}Passwords do not match.${RESET}"; return 1; fi
  ADMIN_PWHASH="$(hash_password "$p1")"
  save_config
  echo -e "${GRN}Admin password changed.${RESET}"
}

# -----------------------
# Banner (user-provided ASCII)
# -----------------------
print_banner() {
  clear
  echo -e "${YEL}"
  cat <<'EOF'
 /$$$$$$$$       /$$     /$$       /$$   /$$       /$$$$$$$$       /$$   /$$
|_____ $$       |  $$   /$$/      | $$$ | $$      | $$_____/      | $$  / $$
     /$$/        \  $$ /$$/       | $$$$| $$      | $$            |  $$/ $$/ 
    /$$/          \  $$$$/        | $$ $$ $$      | $$$$$          \  $$$$/  
   /$$/            \  $$/         | $$  $$$$      | $$__/           >$$  $$  
  /$$/              | $$          | $$\  $$$      | $$             /$$/\  $$ 
 /$$$$$$$$          | $$          | $$ \  $$      | $$$$$$$$      | $$  \ $$ 
|________/          |__/          |__/  \__/      |________/      |__/  |__/ 
EOF
  echo -e "${RESET}"
}

generate_menu_text() {
  cat <<EOF
${BOLD}========== MAIN MENU ==========${RESET}
${BOLD}1. Panel (run remote panel script)${RESET}
${BOLD}2. Wing (run remote wing script)${RESET}
${BOLD}3. Update (run remote update script)${RESET}
${BOLD}4. Uninstall (run remote uninstall script)${RESET}
${BOLD}5. Blueprint (run remote blueprint script)${RESET}
${BOLD}6. Cloudflare (run remote cloudflare script)${RESET}
${BOLD}7. Change Theme${RESET}
${BOLD}8. ZynexFetch (system info + fetch manager)${RESET}
${BOLD}9. Network Diagnostics${RESET}
${BOLD}10. Backup${RESET}
${BOLD}11. Restore${RESET}
${BOLD}12. Custom Commands${RESET}
${BOLD}13. Auto-Update Check${RESET}
${BOLD}14. Admin Mode${RESET}
${BOLD}15. Show System Info${RESET}
${BOLD}16. View Logs${RESET}
${BOLD}17. Exit${RESET}
${BOLD}================================${RESET}
EOF
}

save_menu_to_file() { generate_menu_text > "${MENU_FILE}"; }

# -----------------------
# Remote script runner
# -----------------------
run_remote_script() {
  local encoded="$1"; local url
  if echo "$encoded" | grep -qE '^[A-Za-z0-9+/]+=*$' && [[ $(echo "$encoded" | tr -d '\n' | wc -c) -ge 8 ]]; then
    url="$(echo "$encoded" | base64 -d 2>/dev/null || true)"
    if [[ -z "$url" ]]; then url="$encoded"; fi
  else url="$encoded"; fi
  echo -e "${YEL}Planned remote execution:${RESET} ${CYN}${url}${RESET}"
  if ! prompt_confirm "Download and inspect the script before executing?"; then echo "Aborted."; return 1; fi
  ensure_command curl || return 1
  local tmp; tmp="$(mktemp)"
  if curl -fsSL "$url" -o "$tmp"; then
    echo -e "${GRN}Downloaded:${RESET} ${tmp}"
    echo "---- begin preview (first 200 lines) ----"
    sed -n '1,200p' "$tmp"
    echo "---- end preview ----"
    if prompt_confirm "Run downloaded script now?"; then chmod +x "$tmp"; log "Executing remote script: $url"; bash "$tmp"; local rc=$?; rm -f "$tmp"; if [[ $rc -eq 0 ]]; then echo -e "${GRN}Executed successfully.${RESET}"; else echo -e "${RED}Script exit code: $rc${RESET}"; fi; return $rc; else rm -f "$tmp"; echo "Canceled."; return 2; fi
  else echo -e "${RED}Download failed.${RESET}"; rm -f "$tmp" 2>/dev/null || true; return 1; fi
}

# -----------------------
# Network diagnostics
# -----------------------
network_diagnostics() {
  echo -e "${BOLD}Network Diagnostics${RESET}"
  echo "Public IP:"; if command -v curl >/dev/null 2>&1; then curl -s https://ifconfig.co || curl -s https://ipinfo.io/ip || echo "N/A"; else echo "Install curl to check IP"; fi
  echo; echo "DNS resolution for google.com:"; if command -v dig >/dev/null 2>&1; then dig +short google.com | head -n 5; else nslookup google.com 2>/dev/null | sed -n '1,6p' || echo "dig/nslookup not available"; fi
  echo; echo "Ping (3 packets) to 8.8.8.8:"; ping -c 3 8.8.8.8 || true
  if command -v speedtest >/dev/null 2>&1; then echo "Running speedtest..."; speedtest --accept-license --accept-gdpr || true; else if prompt_confirm "Install speedtest-cli?"; then ensure_command curl || return; if command -v apt-get >/dev/null 2>&1; then curl -s https://install.speedtest.net/app/cli/install.deb.sh | sudo bash; sudo apt-get install -y speedtest; elif command -v yum >/dev/null 2>&1 || command -v dnf >/dev/null 2>&1; then curl -s https://install.speedtest.net/app/cli/install.rpm.sh | sudo bash; sudo yum install -y speedtest || sudo dnf install -y speedtest; else echo "Manual install required."; fi; fi; fi
  read -r -p "Press Enter to continue..."
}

# -----------------------
# Backup & Restore
# -----------------------
backup_prompt() {
  echo "Create backup (tar.gz)"; read -r -p "Enter folder(s)/file(s) to backup (space separated): " paths; read -r -p "Enter output filename (without ext): " fname; fname="${fname:-backup_$(date +%Y%m%d_%H%M%S)}"; out="${PWD}/${fname}.tar.gz"; tar -czf "$out" $paths; echo -e "${GRN}Backup saved to:${RESET} ${out}"; log "Created backup: ${out} (source: ${paths})"; read -r -p "Press Enter to continue..."
}
restore_prompt() {
  echo "Restore from backup (tar.gz)"; read -r -p "Enter backup file path: " file
  if [[ ! -f "$file" ]]; then echo -e "${RED}File not found.${RESET}"; return 1; fi
  echo "Contents:"; tar -tzf "$file" | sed -n '1,40p'
  if prompt_confirm "Restore into current directory?"; then tar -xzf "$file"; echo -e "${GRN}Restore complete.${RESET}"; log "Restored backup ${file} into ${PWD}"; else echo "Canceled."; fi
  read -r -p "Press Enter to continue..."
}

# -----------------------
# Custom Commands
# -----------------------
custom_commands_menu() {
  PS3="Choose a command (or 0 to go back): "
  options=("Show nginx status" "Show ufw status" "List Docker containers" "Custom shell command" "Back")
  select opt in "${options[@]}"; do
    case "$REPLY" in
      1) sudo systemctl status nginx || echo "Nginx not present"; break ;;
      2) sudo ufw status || echo "UFW not present"; break ;;
      3) docker ps -a || echo "Docker not present"; break ;;
      4) read -r -p "Enter command: " c; bash -c "$c" || echo "Command finished with non-zero exit"; break ;;
      5) break ;;
      *) echo "Invalid";;
    esac
  done
  read -r -p "Press Enter to continue..."
}

# -----------------------
# System Info (ZynexFetch main visual)
# -----------------------
zynexfetch_banner() {
cat <<'EOF'
 /$$$$$$$$       /$$     /$$       /$$   /$$       /$$$$$$$$       /$$   /$$
|_____ $$       |  $$   /$$/      | $$$ | $$      | $$_____/      | $$  / $$
     /$$/        \  $$ /$$/       | $$$$| $$      | $$            |  $$/ $$/ 
    /$$/          \  $$$$/        | $$ $$ $$      | $$$$$          \  $$$$/ 
   /$$/            \  $$/         | $$  $$$$      | $$__/           >$$  $$ 
  /$$/              | $$          | $$\  $$$      | $$             /$$/\  $$
 /$$$$$$$$          | $$          | $$ \  $$      | $$$$$$$$      | $$  \ $$
|________/          |__/          |__/  \__/      |________/      |__/  |__/
EOF
}

zynexfetch_show_info() {
  zynexfetch_banner
  echo
  echo -e "${BOLD}ZYNEXFETCH 1.0${RESET}"
  echo "User: $(whoami)"
  echo "Host: $(hostname -f 2>/dev/null || hostname)"
  if command -v lsb_release >/dev/null 2>&1; then echo "OS: $(lsb_release -ds)"; else echo "OS: $(uname -srm)"; fi
  echo "Uptime: $(uptime -p)"
  if command -v free >/dev/null 2>&1; then echo "Memory: $(free -h | awk '/Mem:/ {print $3\"/\"$2}')"; fi
  echo "Disk (/): $(df -h / | awk 'NR==2 {print $3\"/\"$2 \" (\"$5\")\"}')"
  echo "CPU: $(awk -F: '/model name/ {print $2; exit}' /proc/cpuinfo | sed 's/^[ \t]*//')"
  if command -v ip >/dev/null 2>&1; then echo "Local IPs: $(ip -4 addr show scope global | awk '/inet / {print $2}' | paste -sd ", " -)"; fi
  if command -v curl >/dev/null 2>&1; then echo "Public IP: $(curl -s https://ifconfig.co || curl -s https://ipinfo.io/ip || echo N/A)"; fi
  echo
  read -r -p "Press Enter to continue..."
}

# -----------------------
# ZynexFetch download/cache manager
# -----------------------
zynexfetch_get_filename_from_url() {
  local url="$1"
  local cd; cd="$(curl -sI "$url" 2>/dev/null | tr -d '\r' | awk -F': ' '/[Cc]ontent-[Dd]isposition/ {print $2; exit}')"
  if [[ -n "$cd" ]]; then
    local fn; fn="$(echo "$cd" | sed -n 's/.*filename=["'\'']\?\([^"'\'';]*\).*/\1/p')"
    [[ -n "$fn" ]] && { echo "$fn"; return 0; }
  fi
  echo "${url##*/}" | sed 's/[?].*//'
}
zynexfetch_calc_sha256() { local file="$1"; if command -v sha256sum >/dev/null 2>&1; then sha256sum "$file" | awk '{print $1}'; elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$file" | awk '{print $1}'; else echo ""; fi; }
zynexfetch_save_metadata() { local file="$1"; local url="$2"; local checksum="$3"; local meta="${file}.meta"; cat > "${meta}" <<EOF
SOURCE=${url}
DOWNLOADED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
SHA256=${checksum}
EOF
}

zynexfetch_single_download() {
  local url="$1"; local suggested; suggested="$(zynexfetch_get_filename_from_url "$url")"
  [[ -z "$suggested" ]] && suggested="download_$(date +%Y%m%d_%H%M%S)"
  echo "Detected filename: ${suggested}"
  read -r -p "Save as (leave blank to accept): " fname; fname="${fname:-$suggested}"
  local dest="${FETCH_DIR}/${fname}"
  if [[ -f "${dest}" ]]; then if ! prompt_confirm "File exists. Overwrite?"; then echo "Skipping."; return 0; else rm -f "${dest}"; fi; fi
  ensure_command curl || return 1
  if curl -L --progress-bar -o "${dest}" "$url"; then
    echo -e "${GRN}Downloaded to ${dest}${RESET}"
    read -r -p "If you have a SHA256 checksum paste it now (or leave blank): " provided
    provided="${provided//[[:space:]]/}"
    local actual; actual="$(zynexfetch_calc_sha256 "${dest}")"
    if [[ -n "$provided" ]]; then
      if [[ -z "$actual" ]]; then echo -e "${YEL}No checksum tool available; skipped verification.${RESET}"; else
        if [[ "${provided}" == "${actual}" ]]; then echo -e "${GRN}SHA256 verified.${RESET}"; else echo -e "${RED}SHA256 mismatch! Provided:${provided} Actual:${actual}${RESET}"; if prompt_confirm "Remove downloaded file?"; then rm -f "${dest}"; return 2; fi; fi
      fi
    fi
    zynexfetch_save_metadata "${dest}" "${url}" "${actual}"
    log "Fetched ${dest} from ${url}"
  else
    echo -e "${RED}Download failed for ${url}${RESET}"; rm -f "${dest}" 2>/dev/null || true; return 1
  fi
  return 0
}

zynexfetch_batch_download() {
  read -r -p "Enter path to file with URLs (one per line): " listfile
  if [[ ! -f "$listfile" ]]; then echo -e "${RED}List file not found.${RESET}"; return 1; fi
  while IFS= read -r url; do
    url="${url%%#*}"; url="${url//[[:space:]]/}"; [[ -z "$url" ]] && continue
    echo "----"; echo "Processing: $url"; zynexfetch_single_download "$url"
  done < "$listfile"
  echo "Batch complete."
}

zynexfetch_list_cache() { echo -e "${BOLD}Cached files in ${FETCH_DIR}:${RESET}"; ls -lh "${FETCH_DIR}" | sed -n '1,200p' || echo "(empty)"; echo; read -r -p "Press Enter to continue..."; }
zynexfetch_clear_cache() { echo "This will remove all cached files."; if prompt_confirm "Proceed?"; then rm -rf "${FETCH_DIR}"/*; echo -e "${GRN}Cache cleared.${RESET}"; log "Cleared fetch cache"; else echo "Canceled."; fi; read -r -p "Press Enter to continue..."; }

zynexfetch_menu() {
  while true; do
    zynexfetch_banner
    cat <<EOF
1) ZynexFetch Info (neofetch-style)
2) Fetch single URL
3) Batch fetch from file
4) List cache
5) Clear cache
6) Back to main menu
EOF
    read -r -p "Choose [1-6]: " opt
    case "$opt" in
      1) zynexfetch_show_info ;;
      2) read -r -p "Enter URL: " url; zynexfetch_single_download "$url"; read -r -p "Press Enter to continue..."; ;;
      3) zynexfetch_batch_download ;;
      4) zynexfetch_list_cache ;;
      5) zynexfetch_clear_cache ;;
      6) break ;;
      *) echo "Invalid option." ;;
    esac
  done
}

# -----------------------
# System Info & Logs
# -----------------------
system_info() {
  echo -e "${BOLD}SYSTEM INFORMATION${RESET}"
  echo "Hostname: $(hostname)"
  echo "User: $(whoami)"
  echo "Directory: $(pwd)"
  echo "System: $(uname -srm)"
  echo "Uptime: $(uptime -p)"
  if command -v free >/dev/null 2>&1; then echo "Memory: $(free -h | awk '/Mem:/ {print $3\"/\"$2}')"; fi
  echo "Disk: $(df -h / | awk 'NR==2 {print $3\"/\"$2 \" (\"$5\")\"}')"
  read -r -p "Press Enter to continue..."
}

view_logs() { echo "Last 200 lines: ${LOG_FILE}"; tail -n 200 "${LOG_FILE}" || true; read -r -p "Press Enter to continue..."; }

# -----------------------
# Auto-update
# -----------------------
auto_update_check() {
  ensure_command curl || return
  if ! curl -fsSL "${UPDATE_CHECK_URL}" -o /tmp/zynex_remote.sh; then echo -e "${RED}Failed to reach update URL.${RESET}"; rm -f /tmp/zynex_remote.sh 2>/dev/null || true; return 1; fi
  if ! cmp -s /tmp/zynex_remote.sh "${SELF_PATH}"; then
    echo -e "${YEL}Update available!${RESET}"
    if prompt_confirm "Download and replace current script?"; then cp /tmp/zynex_remote.sh "${SELF_PATH}.bak-$(date +%s)"; mv /tmp/zynex_remote.sh "${SELF_PATH}"; chmod +x "${SELF_PATH}"; echo -e "${GRN}Updated. Backup saved.${RESET}"; log "Script auto-updated"; exec "${SELF_PATH}"; else echo "Canceled."; rm -f /tmp/zynex_remote.sh; fi
  else echo -e "${GRN}You already have the latest version.${RESET}"; rm -f /tmp/zynex_remote.sh; fi
  read -r -p "Press Enter to continue..."
}

# -----------------------
# Animated exit
# -----------------------
animated_exit() { for i in {3..1}; do printf "\rExiting in %d..." "$i"; sleep 0.6; done; printf "\r                     \r"; echo -e "${CYN}Goodbye!${RESET}"; exit 0; }

# -----------------------
# Main loop
# -----------------------
main_loop() {
  init_admin_if_needed
  typewriter "${YEL}Welcome to ZYNEX v2.0 — Upgraded${RESET}" 0.004
  while true; do
    print_banner
    save_menu_to_file
    generate_menu_text
    echo -ne "${BOLD}Enter choice [1-17]: ${RESET}"
    read -r choice
    log "User chose: ${choice}"
    case "${choice}" in
      1) encoded="aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL0ppc2hudVRoZUdhbWVyL1Zwcy9yZWZzL2hlYWRzL21haW4vY2QvcGFuZWwuc2g="; run_remote_script "${encoded}"; ;;
      2) encoded="aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL0ppc2hudVRoZUdhbWVyL1Zwcy9yZWZzL2hlYWRzL21haW4vY2Qvd2luZy5zaA=="; run_remote_script "${encoded}"; ;;
      3) encoded="aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL0ppc2hudVRoZUdhbWVyL1Zwcy9yZWZzL2hlYWRzL21haW4vY2QvdXAuc2g="; run_remote_script "${encoded}"; ;;
      4) encoded="aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL0ppc2hudVRoZUdhbWVyL1Zwcy9yZWZzL2hlYWRzL21haW4vY2QvdW5pbnN0YWxsbC5zaA=="; run_remote_script "${encoded}"; ;;
      5) encoded="aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL0ppc2hudVRoZUdhbWVyL1Zwcy9yZWZzL2hlYWRzL21haW4vY2QvYmx1ZXByaW50LnNo"; run_remote_script "${encoded}"; ;;
      6) encoded="aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL0ppc2hudVRoZUdhbWVyL1Zwcy9yZWZzL2hlYWRzL21haW4vY2QvY2xvdWRmbGFyZS5zaA=="; run_remote_script "${encoded}"; ;;
      7) echo "Themes: neon, dark, light"; read -r -p "Theme: " newtheme; case "$newtheme" in neon|dark|light) THEME="$newtheme"; save_config; apply_theme; echo -e "${GRN}Theme set to ${THEME}.${RESET}";; *) echo "Unknown theme.";; esac; read -r -p "Press Enter to continue..."; ;;
      8) zynexfetch_menu ;;
      9) network_diagnostics ;;
      10) backup_prompt ;;
      11) restore_prompt ;;
      12) custom_commands_menu ;;
      13) auto_update_check ;;
      14) if admin_login; then PS3="Admin: choose: "; admin_opts=("Change admin password" "View/Change update URL" "Back"); select aop in "${admin_opts[@]}"; do case "$REPLY" in 1) change_admin_password; break ;; 2) echo "Current UPDATE_CHECK_URL: ${UPDATE_CHECK_URL}"; read -r -p "Enter new update URL (or leave blank): " newu; if [[ -n "$newu" ]]; then UPDATE_CHECK_URL="$newu"; save_config; echo "UPDATE_CHECK_URL set."; log "UPDATE_CHECK_URL changed by admin"; fi; break ;; 3) break ;; *) echo "Invalid";; esac; done; fi ;;
      15) system_info ;;
      16) view_logs ;;
      17) animated_exit ;;
      *) echo -e "${RED}${BOLD}Invalid option${RESET}"; read -r -p "Press Enter to continue..."; ;;
    esac
  done
}

# -----------------------
# Run
# -----------------------
main_loop

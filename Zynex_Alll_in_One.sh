#!/usr/bin/env bash
# ZYNEX v3.0 - Rebuilt, with Create/Remove/Add feature system, Admin, themes, and more
# Save as: zynex_v3.sh
# Run: chmod +x zynex_v3.sh && ./zynex_v3.sh

set -o errexit
set -o pipefail
set -o nounset

# -----------------------
# Basic paths & defaults
# -----------------------
CONFIG_DIR="${HOME}/.zynex"
FETCH_DIR="${CONFIG_DIR}/fetch"
FEATURES_DIR="${CONFIG_DIR}/features"
CONFIG_FILE="${CONFIG_DIR}/config"
LOG_FILE="${CONFIG_DIR}/zynex.log"
MENU_FILE="${PWD}/zynex_menu.txt"
SELF_PATH="$(realpath "$0")"
UPDATE_CHECK_URL="${UPDATE_CHECK_URL:-https://raw.githubusercontent.com/youruser/yourrepo/main/zynex_v3.sh}"
DEFAULT_ADMIN_EMAIL="admin@zynexcode.com"
DEFAULT_ADMIN_PW="zynex@123"
THEME_DEFAULT="neon"
ANIMATE_DEFAULT="yes"

mkdir -p "${CONFIG_DIR}" "${FETCH_DIR}" "${FEATURES_DIR}"
touch "${LOG_FILE}"

# -----------------------
# Theme color sets
# -----------------------
# These are simple literal escape sequences. If terminal doesn't support them it's harmless.
THEME_neon_RED="\e[31m"; THEME_neon_GRN="\e[32m"; THEME_neon_YEL="\e[33m"; THEME_neon_CYN="\e[36m"; THEME_neon_WHT="\e[97m"; THEME_neon_BOLD="\e[1m"; THEME_neon_RESET="\e[0m"
THEME_dark_RED="\e[91m"; THEME_dark_GRN="\e[92m"; THEME_dark_YEL="\e[93m"; THEME_dark_CYN="\e[96m"; THEME_dark_WHT="\e[37m"; THEME_dark_BOLD="\e[1m"; THEME_dark_RESET="\e[0m"
THEME_light_RED="\e[31m"; THEME_light_GRN="\e[32m"; THEME_light_YEL="\e[33m"; THEME_light_CYN="\e[36m"; THEME_light_WHT="\e[30m"; THEME_light_BOLD="\e[1m"; THEME_light_RESET="\e[0m"
THEME_fire_RED="\e[31m"; THEME_fire_GRN="\e[33m"; THEME_fire_YEL="\e[33m"; THEME_fire_CYN="\e[35m"; THEME_fire_WHT="\e[97m"; THEME_fire_BOLD="\e[1m"; THEME_fire_RESET="\e[0m"

# -----------------------
# Load or create config
# -----------------------
if [[ -f "${CONFIG_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${CONFIG_FILE}"
else
  THEME="${THEME:-$THEME_DEFAULT}"
  ADMIN_EMAIL="${ADMIN_EMAIL:-$DEFAULT_ADMIN_EMAIL}"
  ADMIN_PWHASH="${ADMIN_PWHASH:-}"
  ANIMATE="${ANIMATE:-$ANIMATE_DEFAULT}"
  FEATURES_REGISTRY="${FEATURES_REGISTRY:-}" # will store newline-separated "name|url" lines
  if [[ -z "${ADMIN_PWHASH}" ]]; then
    ADMIN_PWHASH="$(printf '%s' "${DEFAULT_ADMIN_PW}" | sha256sum | awk '{print $1}')"
  fi
  cat > "${CONFIG_FILE}" <<EOF
# ZYNEX CONFIG
THEME="${THEME}"
ADMIN_EMAIL="${ADMIN_EMAIL}"
ADMIN_PWHASH="${ADMIN_PWHASH}"
UPDATE_CHECK_URL="${UPDATE_CHECK_URL}"
ANIMATE="${ANIMATE}"
FEATURES_REGISTRY="${FEATURES_REGISTRY}"
EOF
fi

# -----------------------
# Apply theme variables
# -----------------------
apply_theme() {
  case "${THEME}" in
    neon) prefix="THEME_neon" ;;
    dark) prefix="THEME_dark" ;;
    light) prefix="THEME_light" ;;
    fire) prefix="THEME_fire" ;;
    *) prefix="THEME_neon" ;;
  esac
  RED="$(eval "echo \${${prefix}_RED}")"
  GRN="$(eval "echo \${${prefix}_GRN}")"
  YEL="$(eval "echo \${${prefix}_YEL}")"
  CYN="$(eval "echo \${${prefix}_CYN}")"
  WHT="$(eval "echo \${${prefix}_WHT}")"
  BOLD="$(eval "echo \${${prefix}_BOLD}")"
  RESET="$(eval "echo \${${prefix}_RESET}")"
}
apply_theme

# -----------------------
# Utilities
# -----------------------
log() {
  local ts; ts=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$ts] $*" | tee -a "${LOG_FILE}"
}

typewriter() {
  local text="$1"
  local delay="${2:-0.005}"
  if [[ "${ANIMATE:-no}" == "yes" ]]; then
    local i; for ((i=0;i<${#text};i++)); do printf "%s" "${text:$i:1}"; sleep "${delay}"; done
    printf "\n"
  else
    printf "%s\n" "$text"
  fi
}

prompt_confirm() {
  local prompt="${1:-Are you sure?}"
  read -r -p "$prompt [y/N]: " resp
  case "$resp" in [yY]|[yY][eE][sS]) return 0;; *) return 1;; esac
}

ensure_command() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo -e "${YEL}Command '$cmd' not found. Attempting to install...${RESET}"
    if command -v apt-get >/dev/null 2>&1; then sudo apt-get update && sudo apt-get install -y "$cmd"
    elif command -v yum >/dev/null 2>&1; then sudo yum install -y "$cmd"
    elif command -v dnf >/dev/null 2>&1; then sudo dnf install -y "$cmd"
    else echo -e "${RED}Please install '$cmd' manually.${RESET}"; return 1; fi
  fi
  return 0
}

hash_password() {
  local pw="$1"
  printf '%s' "$pw" | sha256sum | awk '{print $1}'
}

save_config() {
  # FEATURES_REGISTRY may contain newlines; handle safely by writing raw variable and using printf
  cat > "${CONFIG_FILE}" <<EOF
# ZYNEX CONFIG
THEME="${THEME}"
ADMIN_EMAIL="${ADMIN_EMAIL}"
ADMIN_PWHASH="${ADMIN_PWHASH}"
UPDATE_CHECK_URL="${UPDATE_CHECK_URL}"
ANIMATE="${ANIMATE}"
FEATURES_REGISTRY="$(printf '%s' "${FEATURES_REGISTRY}")"
EOF
  apply_theme
}

init_admin_if_needed() {
  if [[ -z "${ADMIN_PWHASH:-}" ]]; then
    ADMIN_EMAIL="${ADMIN_EMAIL:-$DEFAULT_ADMIN_EMAIL}"
    ADMIN_PWHASH="$(hash_password "${DEFAULT_ADMIN_PW}")"
    save_config
  fi
}

# -----------------------
# Admin
# -----------------------
admin_login() {
  init_admin_if_needed
  echo -n "Admin email: "
  read -r entered_email
  read -r -s -p "Admin password: " pw
  echo
  if [[ "${entered_email}" != "${ADMIN_EMAIL}" ]]; then echo -e "${RED}Wrong email.${RESET}"; return 1; fi
  if [[ "$(hash_password "$pw")" == "${ADMIN_PWHASH}" ]]; then
    log "Admin login successful for ${entered_email}"
    echo -e "${GRN}Admin mode unlocked.${RESET}"
    return 0
  else
    echo -e "${RED}Wrong password.${RESET}"; return 1
  fi
}

change_admin_password() {
  echo "Change admin password"
  read -r -s -p "New password: " p1; echo
  read -r -s -p "Confirm password: " p2; echo
  if [[ "$p1" != "$p2" ]]; then echo -e "${RED}Passwords do not match.${RESET}"; return 1; fi
  ADMIN_PWHASH="$(hash_password "$p1")"
  save_config
  echo -e "${GRN}Admin password changed.${RESET}"
}

# -----------------------
# Banner & Menu
# -----------------------
print_banner() {
  clear
  echo -e "${YEL}"
  cat <<'EOF'
  ________  __   __  __   __  ______
 /  _____/ /  | /  |/  | /  |/      \
/   \  ___`|  |/|  ' /|  ' `---|  |---
\    \_\  \|   /|    < |   /     |  |  
 \______  /|__| |_|\_\|__|      |__|  
        \/                              
EOF
  echo -e "${RESET}"
}

generate_menu_text() {
  cat <<EOF
${BOLD}======== ZYNEX v3.0 MAIN MENU ========${RESET}
1) Panel Installer
2) Wing Installer
3) Update Panel
4) Cloudflare Setup
5) Backup
6) Restore
7) Change Theme
8) ZynexFetch (System Info + Fetch Manager)
9) System Info
10) Network Diagnostics
11) Create Feature
12) Remove Feature
13) Add Feature (register remote script)
14) Admin Mode
15) Auto-Update Check
16) View Logs
17) Exit
${BOLD}======================================${RESET}
EOF
}
save_menu_to_file() { generate_menu_text > "${MENU_FILE}"; }

# -----------------------
# Remote runner (safe)
# -----------------------
run_remote_script() {
  local encoded_or_url="$1"
  local url
  # If looks base64-like decode, otherwise take literal
  if echo "$encoded_or_url" | grep -qE '^[A-Za-z0-9+/]+=*$' && [[ $(echo "$encoded_or_url" | tr -d '\n' | wc -c) -ge 8 ]]; then
    url="$(echo "$encoded_or_url" | base64 -d 2>/dev/null || true)"
    [[ -z "$url" ]] && url="$encoded_or_url"
  else
    url="$encoded_or_url"
  fi
  echo -e "${YEL}Remote URL:${RESET} ${CYN}${url}${RESET}"
  if ! prompt_confirm "Download and preview script before execution?"; then echo "Aborted."; return 1; fi
  ensure_command curl || return 1
  local tmp; tmp="$(mktemp)"
  if ! curl -fsSL "$url" -o "$tmp"; then echo -e "${RED}Download failed.${RESET}"; rm -f "$tmp"; return 1; fi
  echo "---- begin preview (first 200 lines) ----"
  sed -n '1,200p' "$tmp"
  echo "---- end preview ----"
  if prompt_confirm "Run downloaded script now?"; then
    chmod +x "$tmp"
    log "Executing remote script: $url"
    bash "$tmp" || { echo -e "${RED}Script failed.${RESET}"; rm -f "$tmp"; return 1; }
    echo -e "${GRN}Executed successfully.${RESET}"
  else
    echo "Canceled."
  fi
  rm -f "$tmp"
  return 0
}

# -----------------------
# ZynexFetch (info + fetch manager)
# -----------------------
zynexfetch_banner() {
  cat <<'EOF'
   _____               _  __ ______
  /__   \__ _ _ __ ___| |/ /|___  /
    / /\/ _` | '__/ _ \ ' /    / / 
   / / | (_| | | |  __/ . \   / /  
   \/   \__,_|_|  \___|_|\_\ /_/   
EOF
}

zynexfetch_show_info() {
  zynexfetch_banner
  echo
  echo -e "${BOLD}ZYNEXFETCH${RESET}"
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

zynexfetch_get_filename_from_url() {
  local url="$1"
  local cd; cd="$(curl -sI "$url" 2>/dev/null | tr -d '\r' | awk -F': ' '/[Cc]ontent-[Dd]isposition/ {print $2; exit}')"
  if [[ -n "$cd" ]]; then
    local fn; fn="$(echo "$cd" | sed -n 's/.*filename=["'\'']\?\([^"'\'';]*\).*/\1/p')"
    [[ -n "$fn" ]] && { echo "$fn"; return 0; }
  fi
  echo "${url##*/}" | sed 's/[?].*//'
}

zynexfetch_calc_sha256() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$file" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$file" | awk '{print $1}'
  else echo ""; fi
}

zynexfetch_save_metadata() {
  local file="$1"; local url="$2"; local checksum="$3"; local meta="${file}.meta"
  cat > "${meta}" <<EOF
SOURCE=${url}
DOWNLOADED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
SHA256=${checksum}
EOF
}

zynexfetch_single_download() {
  local url="$1"
  local suggested; suggested="$(zynexfetch_get_filename_from_url "$url")"
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

zynexfetch_list_cache() { echo -e "${BOLD}Cached files in ${FETCH_DIR}:${RESET}"; ls -1h "${FETCH_DIR}" | sed -n '1,200p' || echo "(empty)"; echo; read -r -p "Press Enter to continue..."; }
zynexfetch_clear_cache() { echo "This will remove all cached files."; if prompt_confirm "Proceed?"; then rm -rf "${FETCH_DIR}"/*; echo -e "${GRN}Cache cleared.${RESET}"; log "Cleared fetch cache"; else echo "Canceled."; fi; read -r -p "Press Enter to continue..."; }

zynexfetch_menu() {
  while true; do
    zynexfetch_banner
    cat <<EOF
1) ZynexFetch Info
2) Fetch single URL
3) List cache
4) Clear cache
5) Back
EOF
    read -r -p "Choose [1-5]: " opt
    case "$opt" in
      1) zynexfetch_show_info ;;
      2) read -r -p "Enter URL: " url; zynexfetch_single_download "$url"; read -r -p "Press Enter to continue..." ;; 
      3) zynexfetch_list_cache ;;
      4) zynexfetch_clear_cache ;;
      5) break ;;
      *) echo "Invalid";;
    esac
  done
}

# -----------------------
# Backup & Restore
# -----------------------
backup_prompt() {
  echo "Create backup (tar.gz)"
  read -r -p "Enter folder(s)/file(s) to backup (space separated): " -a paths
  if [[ ${#paths[@]} -eq 0 ]]; then echo "No paths provided."; return 1; fi
  read -r -p "Enter output filename (without ext, default backup_TIMESTAMP): " fname; fname="${fname:-backup_$(date +%Y%m%d_%H%M%S)}"
  out="${PWD}/${fname}.tar.gz"
  tar -czf "$out" "${paths[@]}"
  echo -e "${GRN}Backup saved to:${RESET} ${out}"
  log "Created backup: ${out} (source: ${paths[*]})"
  read -r -p "Press Enter to continue..."
}

restore_prompt() {
  echo "Restore from backup (tar.gz)"
  read -r -p "Enter backup file path: " file
  if [[ ! -f "$file" ]]; then echo -e "${RED}File not found.${RESET}"; return 1; fi
  echo "Contents:"
  tar -tzf "$file" | sed -n '1,40p'
  if prompt_confirm "Restore into current directory?"; then tar -xzf "$file"; echo -e "${GRN}Restore complete.${RESET}"; log "Restored backup ${file} into ${PWD}"; else echo "Canceled."; fi
  read -r -p "Press Enter to continue..."
}

# -----------------------
# Custom Feature Manager: create / remove / add (register remote)
# -----------------------
list_local_features() {
  if [[ ! -d "${FEATURES_DIR}" ]]; then echo "(no features)"; return; fi
  ls -1 "${FEATURES_DIR}" 2>/dev/null || echo "(no features)"
}

create_feature() {
  read -r -p "Feature name (no spaces, e.g. my-feature): " fname
  [[ -z "$fname" ]] && { echo "Cancelled."; return 1; }
  local dir="${FEATURES_DIR}/${fname}"
  if [[ -d "$dir" ]]; then echo -e "${YEL}Feature already exists: $fname${RESET}"; return 1; fi
  mkdir -p "$dir"
  cat > "${dir}/run.sh" <<'EOF'
#!/usr/bin/env bash
# Starter script for feature: PLACEHOLDER_NAME
echo "Running feature: PLACEHOLDER_NAME"
# Put your commands below
EOF
  sed -i "s/PLACEHOLDER_NAME/${fname}/g" "${dir}/run.sh"
  chmod +x "${dir}/run.sh"
  echo -e "${GRN}Feature '${fname}' created at ${dir}.${RESET}"
  log "Created feature: ${fname}"
  read -r -p "Open feature dir? [y/N]: " o && [[ "$o" =~ ^[yY] ]] && ${EDITOR:-vi} "$dir/run.sh"
}

remove_feature() {
  echo "Local features:"
  list_local_features
  read -r -p "Feature name to remove (or blank to cancel): " fname
  [[ -z "$fname" ]] && { echo "Cancelled."; return 1; }
  local dir="${FEATURES_DIR}/${fname}"
  if [[ ! -d "$dir" ]]; then echo -e "${RED}Feature not found: $fname${RESET}"; return 1; fi
  if prompt_confirm "Permanently remove feature '${fname}'?"; then rm -rf "$dir"; echo -e "${GRN}Removed.${RESET}"; log "Removed feature: ${fname}"; else echo "Canceled."; fi
}

add_feature() {
  read -r -p "Feature name to register (no spaces): " fname
  [[ -z "$fname" ]] && { echo "Cancelled."; return 1; }
  read -r -p "Remote script URL to associate with this feature: " url
  [[ -z "$url" ]] && { echo "Cancelled."; return 1; }
  # Append to FEATURES_REGISTRY as "name|url\n"
  FEATURES_REGISTRY="$(printf '%s\n' "${FEATURES_REGISTRY}" | sed '/^\s*$/d')"
  FEATURES_REGISTRY="${FEATURES_REGISTRY}"$'\n'"${fname}|${url}"
  FEATURES_REGISTRY="$(printf '%s\n' "${FEATURES_REGISTRY}" | sed '/^\s*$/d' | awk '!seen[$0]++')"
  save_config
  echo -e "${GRN}Registered feature: ${fname}${RESET}"
  log "Registered remote feature: ${fname} -> ${url}"
}

run_registered_features_menu() {
  # present list from FEATURES_REGISTRY
  if [[ -z "${FEATURES_REGISTRY// }" ]]; then echo "No registered features."; return; fi
  echo "Registered features:"
  local i=0
  local arr=()
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    arr+=("$line")
  done <<< "$(printf '%s\n' "${FEATURES_REGISTRY}")"
  for idx in "${!arr[@]}"; do
    local name; name="${arr[$idx]%%|*}"
    echo "$((idx+1)). $name"
  done
  read -r -p "Choose number to run (or 0 to cancel): " cho
  if [[ "$cho" =~ ^[0-9]+$ ]] && (( cho > 0 && cho <= ${#arr[@]} )); then
    local entry="${arr[$((cho-1))]}"
    local name="${entry%%|*}"
    local url="${entry#*|}"
    echo "Running registered feature: $name"
    run_remote_script "$url"
  else
    echo "Canceled."
  fi
}

# -----------------------
# Network diagnostics & simple helpers
# -----------------------
network_diagnostics() {
  echo -e "${BOLD}Network Diagnostics${RESET}"
  echo "Public IP:"
  if command -v curl >/dev/null 2>&1; then curl -s https://ifconfig.co || curl -s https://ipinfo.io/ip || echo "N/A"; else echo "Install curl to check IP"; fi
  echo
  echo "DNS resolution for google.com:"
  if command -v dig >/dev/null 2>&1; then dig +short google.com | head -n 5; else nslookup google.com 2>/dev/null | sed -n '1,6p' || echo "dig/nslookup not available"; fi
  echo
  echo "Ping (3 packets) to 8.8.8.8:"
  ping -c 3 8.8.8.8 || true
  read -r -p "Press Enter to continue..."
}

# -----------------------
# System Info & logs
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

view_logs() {
  echo "Last 200 lines: ${LOG_FILE}"
  tail -n 200 "${LOG_FILE}" || true
  read -r -p "Press Enter to continue..."
}

# -----------------------
# Auto-update
# -----------------------
auto_update_check() {
  ensure_command curl || return
  local tmp="/tmp/zynex_v3_remote.sh"
  if ! curl -fsSL "${UPDATE_CHECK_URL}" -o "${tmp}"; then echo -e "${RED}Failed to reach update URL.${RESET}"; rm -f "${tmp}" 2>/dev/null || true; return 1; fi
  if ! cmp -s "${tmp}" "${SELF_PATH}"; then
    echo -e "${YEL}Update available!${RESET}"
    if prompt_confirm "Download and replace current script?"; then
      cp "${SELF_PATH}" "${SELF_PATH}.bak-$(date +%s)"
      mv "${tmp}" "${SELF_PATH}"
      chmod +x "${SELF_PATH}"
      echo -e "${GRN}Updated. Backup saved.${RESET}"
      log "Script auto-updated"
      echo "Restarting new script..."
      exec "${SELF_PATH}"
    else
      echo "Canceled."
      rm -f "${tmp}"
    fi
  else
    echo -e "${GRN}You already have the latest version.${RESET}"
    rm -f "${tmp}"
  fi
  read -r -p "Press Enter to continue..."
}

# -----------------------
# Placeholder functions for installers (Panel, Wing, Update, Cloudflare)
# Users can replace body with real commands or remote-run
# -----------------------
panel_installer() {
  echo "Panel installer placeholder. You can register a remote script via Add Feature or modify this function."
  read -r -p "Run a registered 'panel' feature if exists? [y/N]: " r && [[ "$r" =~ ^[yY] ]] && run_registered_features_menu
  read -r -p "Press Enter to continue..."
}
wing_installer() {
  echo "Wing installer placeholder (similar behavior)."
  read -r -p "Press Enter to continue..."
}
update_panel() {
  echo "Update panel placeholder. You can use Auto-Update Check (menu item 15)."
  read -r -p "Press Enter to continue..."
}
cloudflare_setup() {
  echo "Cloudflare setup placeholder."
  read -r -p "Press Enter to continue..."
}

# -----------------------
# Animated exit
# -----------------------
animated_exit() {
  for i in {3..1}; do printf "\rExiting in %d..." "$i"; sleep 0.6; done
  printf "\r                     \r"
  echo -e "${CYN}Goodbye!${RESET}"
  exit 0
}

# -----------------------
# Main loop
# -----------------------
main_loop() {
  init_admin_if_needed
  typewriter "${YEL}Welcome to ZYNEX v3.0 — Rebuilt${RESET}" 0.004
  while true; do
    print_banner
    save_menu_to_file
    generate_menu_text
    echo -ne "${BOLD}Enter choice [1-17]: ${RESET}"
    read -r choice
    log "User chose: ${choice}"
    case "${choice}" in
      1) panel_installer ;;
      2) wing_installer ;;
      3) update_panel ;;
      4) cloudflare_setup ;;
      5) backup_prompt ;;
      6) restore_prompt ;;
      7) echo "Themes: neon, dark, light, fire"; read -r -p "Theme: " newtheme; case "$newtheme" in neon|dark|light|fire) THEME="$newtheme"; save_config; apply_theme; echo -e "${GRN}Theme set to ${THEME}.${RESET}";; *) echo "Unknown theme.";; esac; read -r -p "Press Enter to continue..." ;;
      8) zynexfetch_menu ;;
      9) system_info ;;
      10) network_diagnostics ;;
      11) create_feature ;;
      12) remove_feature ;;
      13) add_feature ;;
      14) 
         if admin_login; then
           PS3="Admin: choose: "
           admin_opts=("Change admin password" "View/Change update URL" "List Registered Features" "Run Registered Feature" "Back")
           select aop in "${admin_opts[@]}"; do
             case "$REPLY" in
               1) change_admin_password; break ;;
               2) echo "Current UPDATE_CHECK_URL: ${UPDATE_CHECK_URL}"; read -r -p "Enter new update URL (or leave blank): " newu; if [[ -n "$newu" ]]; then UPDATE_CHECK_URL="$newu"; save_config; echo "UPDATE_CHECK_URL set."; log "UPDATE_CHECK_URL changed by admin"; fi; break ;;
               3) echo -e "${BOLD}Registered features:${RESET}"; printf '%s\n' "${FEATURES_REGISTRY:-(none)}"; break ;;
               4) run_registered_features_menu; break ;;
               5) break ;;
               *) echo "Invalid";;
             esac
           done
         fi
         ;;
      15) auto_update_check ;;
      16) view_logs ;;
      17) animated_exit ;;
      *) echo -e "${RED}${BOLD}Invalid option${RESET}"; read -r -p "Press Enter to continue..."; ;;
    esac
  done
}

# -----------------------
# Start
# -----------------------
main_loop

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$0"
case "$SCRIPT_PATH" in
  /*) ;;
  *) SCRIPT_PATH="$(pwd)/$SCRIPT_PATH" ;;
esac
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
cd "$SCRIPT_DIR"
ROOT="$(pwd)"

HOME_DIR="$HOME"
QS_SRC="$ROOT/quickshell"
QS_DST="$HOME_DIR/.config/quickshell"
HYPR_SRC="$ROOT/hypr"
HYPR_DST="$HOME_DIR/.config/hypr"
THEME_DST="$HOME_DIR/.config/theme"

RED='\033[0;31m'
GRN='\033[0;32m'
CYN='\033[0;36m'
YLW='\033[1;33m'
DIM='\033[2m'
RST='\033[0m'
BLD='\033[1m'

banner() {
  clear 2>/dev/null || true
  printf '%b\n' "\( {CYN} \){BLD}"
  cat << 'ART'
 ███████╗██╗    ██╗ █████╗ ██╗   ██╗███████╗██╗  ██╗██╗     
 ██╔════╝██║    ██║██╔══██╗╚██╗ ██╔╝██╔════╝╚██╗██╔╝██║     
 ███████╗██║ █╗ ██║███████║ ╚████╔╝ █████╗   ╚███╔╝ ██║     
 ╚════██║██║███╗██║██╔══██║  ╚██╔╝  ██╔══╝   ██╔██╗ ██║     
 ███████║╚███╔███╔╝██║  ██║   ██║   ██║     ██╔╝ ██╗███████╗
 ╚══════╝ ╚══╝╚══╝ ╚═╝  ╚═╝   ╚═╝   ╚═╝     ╚═╝  ╚═╝╚══════╝
ART
  printf '%b\n' "${RST}"
  printf '%b\n' "  \( {DIM}SwayFX + QuickShell rice installer \){RST}"
  printf '%b\n' "  ${DIM}source: \( {ROOT} \){RST}"
  printf '\n'
}

copy_tree() {
  src="$1"
  dst="$2"
  if [ ! -d "$src" ]; then
    printf '%b\n' "  \( {YLW}skip \){RST} (no dir): $src"
    return 0
  fi
  mkdir -p "$dst"
  cp -a "$src"/. "$dst"/
  printf '%b\n' "  \( {GRN}ok \){RST}  $src  ->  $dst"
}

install_files() {
  printf '%b\n' "\( {BLD}Installing... \){RST}"
  printf '\n'

  copy_tree "$QS_SRC" "$QS_DST"

  if [ -d "$HYPR_SRC" ]; then
    mkdir -p "$HYPR_DST"
    cp -a "$HYPR_SRC"/. "$HYPR_DST"/
    printf '%b\n' "  \( {GRN}ok \){RST}  $HYPR_SRC  ->  $HYPR_DST"
  fi

  mkdir -p "$THEME_DST"
  mkdir -p "$QS_DST/scripts"
  mkdir -p "$HOME_DIR/Изображения/Wallpapers"

  if [ ! -f "$THEME_DST/accent" ]; then
    echo "#89b4fa" > "$THEME_DST/accent"
    printf '%b\n' "  \( {GRN}ok \){RST}  default accent -> $THEME_DST/accent"
  fi

  if [ -d "$QS_DST/scripts" ]; then
    find "$QS_DST/scripts" -type f -name "*.sh" -exec chmod +x {} \;
    printf '%b\n' "  \( {GRN}ok \){RST}  chmod +x scripts"
  fi

  for cfg in \
    "$HOME_DIR/.config/swayfx/config" \
    "$HOME_DIR/.config/sway/config"
  do
    if [ -f "$cfg" ]; then
      if ! grep -q "QS_AUTOSTART_BEGIN" "$cfg" 2>/dev/null; then
        printf "\n# QS_AUTOSTART_BEGIN\n# QS_AUTOSTART_END\n" >> "$cfg"
        printf '%b\n' "  \( {GRN}ok \){RST}  autostart markers -> $cfg"
      fi
      break
    fi
  done

  printf '\n'
  printf '%b\n' "\( {GRN} \){BLD}Done.${RST}"
  printf '%b\n' "  Launch:  \( {CYN}qs -p \~/.config/quickshell/shell.qml \){RST}"
  printf '%b\n' "  Or bind: \( {CYN}exec qs -p \~/.config/quickshell/shell.qml \){RST}"
  printf '\n'
}

backup_then_install() {
  stamp="$(date +%Y%m%d_%H%M%S)"
  bak="$HOME_DIR/.config/swayfxl-backup-$stamp"
  mkdir -p "$bak"
  printf '%b\n' "${BLD}Backup -> \( bak \){RST}"
  if [ -d "$QS_DST" ]; then
    cp -a "$QS_DST" "$bak/quickshell"
    printf '%b\n' "  \( {GRN}ok \){RST}  quickshell"
  fi
  if [ -d "$HYPR_DST" ]; then
    cp -a "$HYPR_DST" "$bak/hypr"
    printf '%b\n' "  \( {GRN}ok \){RST}  hypr"
  fi
  printf '\n'
  install_files
}

menu() {
  banner
  printf '%b\n' "  \( {BLD}1 \){RST}) install          \( {DIM}(overwrite into \~/.config) \){RST}"
  printf '%b\n' "  \( {BLD}2 \){RST}) backup + install \( {DIM}(save old configs first) \){RST}"
  printf '%b\n' "  \( {BLD}0 \){RST}) exit"
  printf '\n'
  printf '  choice: '
  read -r choice
  printf '\n'
  case "$choice" in
    1) install_files ;;
    2) backup_then_install ;;
    0) printf '%b\n' "  \( {DIM}bye \){RST}"; exit 0 ;;
    *) printf '%b\n' "  \( {RED}unknown option \){RST}"; exit 1 ;;
  esac
}

ARG="${1:-}"
case "$ARG" in
  --install|-i) banner; install_files ;;
  --backup|-b)  banner; backup_then_install ;;
  *)            menu ;;
esac
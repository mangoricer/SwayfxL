#!/usr/bin/env bash
set -euo pipefail

CFG=""
for f in "$HOME/.config/swayfx/config" "$HOME/.config/sway/config"; do
  [[ -f "$f" ]] && CFG="$f" && break
done

if [[ -z "$CFG" ]]; then
  echo "NO_CONFIG"
  exit 1
fi

BEGIN="# QS_AUTOSTART_BEGIN"
END="# QS_AUTOSTART_END"

ensure_markers() {
  if ! grep -qxF "$BEGIN" "$CFG"; then
    printf '\n%s\n%s\n' "$BEGIN" "$END" >> "$CFG"
  fi
}

list() {
  ensure_markers
  awk -v b="$BEGIN" -v e="$END" '
    $0 == b { p = 1; next }
    $0 == e { p = 0; next }
    p && NF { print }
  ' "$CFG"
}

add() {
  local cmd="${*:-}"
  [[ -z "$cmd" ]] && exit 1
  ensure_markers
  case "$cmd" in
    exec|exec\ *) ;;
    *) cmd="exec $cmd" ;;
  esac
  if list | grep -Fxq -- "$cmd"; then
    exit 0
  fi
  local tmp
  tmp=$(mktemp)
  awk -v e="$END" -v c="$cmd" '
    $0 == e { print c }
    { print }
  ' "$CFG" > "$tmp"
  mv "$tmp" "$CFG"
}

del() {
  local line="${*:-}"
  [[ -z "$line" ]] && exit 1
  ensure_markers
  local tmp
  tmp=$(mktemp)
  awk -v b="$BEGIN" -v e="$END" -v t="$line" '
    $0 == b { p = 1; print; next }
    $0 == e { p = 0; print; next }
    p && $0 == t { next }
    { print }
  ' "$CFG" > "$tmp"
  mv "$tmp" "$CFG"
}

edit() {
  local old="$1"
  shift
  local new="${*:-}"
  [[ -z "$old" || -z "$new" ]] && exit 1
  case "$new" in
    exec|exec\ *) ;;
    *) new="exec $new" ;;
  esac
  ensure_markers
  local tmp
  tmp=$(mktemp)
  awk -v b="$BEGIN" -v e="$END" -v o="$old" -v n="$new" '
    $0 == b { p = 1; print; next }
    $0 == e { p = 0; print; next }
    p && $0 == o { print n; next }
    { print }
  ' "$CFG" > "$tmp"
  mv "$tmp" "$CFG"
}

case "${1:-}" in
  list) list ;;
  add)  shift; add "$@" ;;
  del)  shift; del "$@" ;;
  edit)
    old="${2:-}"
    shift 2
    edit "\( old" " \)@"
    ;;
  *) echo "usage: list|add|del|edit"; exit 1 ;;
esac
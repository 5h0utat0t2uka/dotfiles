#!/bin/sh

direction=
if [ "$1" = "--scroll" ]; then
  direction="$2"
  file="$f"
  # lf reserves a prompt and status row, plus two rows for an outer border.
  height=$((lf_height - 2))
  if [ "$lf_drawbox" = true ] && [ "$lf_borderstyle" != separators ]; then
    height=$((height - 2))
  fi
else
  file="$1"
  width="${2:-80}"
  height="${3:-24}"
fi
[ -f "$file" ] || exit 0
[ "$height" -gt 0 ] || exit 0

mime="$(file --mime-type -Lb -- "$file" 2>/dev/null)"

case "$mime" in
  text/*|application/json|application/xml|application/javascript|application/x-sh|application/x-shellscript)
    ;;
  image/*)
    [ -z "$direction" ] || exit 0
    CHAFA="$(command -v chafa 2>/dev/null)"
    if [ -n "$CHAFA" ]; then
      exec "$CHAFA" \
        -f symbols \
        --size="${width}x${height}" \
        --symbols=block,border,space \
        --animate=off \
        --clear \
        --polite=on \
        -- "$file"
    fi
    printf 'chafa not found\n'
    exit 0
    ;;

  *)
    [ -z "$direction" ] || exit 0
    exec file --brief -- "$file"
    ;;
esac

offset=${lf_user_preview_offset:-0}
if [ -n "$direction" ]; then
  case "$direction" in
    down) next=$((offset + 1)) ;;
    up)   next=$((offset - 1)) ;;
    *)    exit 1 ;;
  esac
  if [ "$next" -le 0 ]; then
    next=0
  else
    # Stop at the requested window, or align the last line with the pane bottom.
    next=$(LC_ALL=C awk -v end="$((next + height))" -v rows="$height" \
      'NR == end { exit } END { print (NR > rows ? NR - rows : 0) }' < "$file") || exit 1
  fi
  [ "$next" -ne "$offset" ] || exit 0
  exec "$lf" -remote "send $id :set user_preview_offset $next; set preview"
fi

first=$((offset + 1))
last=$((offset + height))
BAT="$(command -v bat 2>/dev/null || command -v batcat 2>/dev/null)"
if [ -n "$BAT" ]; then
  "$BAT" --color=always --style=plain --paging=never --wrap=never \
    --terminal-width="$width" --line-range="$first:$last" -- "$file"
else
  sed -n "${first},${last}p;${last}q" < "$file"
fi
# lf must refresh this preview when the offset changes or the file is reselected.
exit 1

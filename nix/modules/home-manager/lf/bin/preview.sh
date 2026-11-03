#!/bin/sh

file="$1"
width="${2:-80}"
height="${3:-24}"
[ -f "$file" ] || exit 0
[ "$height" -gt 0 ] || exit 0

mime="$(file --mime-type -Lb -- "$file" 2>/dev/null)"

case "$mime" in
  text/*|application/json|application/xml|application/javascript|application/x-sh|application/x-shellscript)
    ;;
  image/*)
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
    exec file --brief -- "$file"
    ;;
esac

# The patched lf supplies a line range and consumes this header for text only.
first=${7:-1}
rows=${8:-$height}
if [ "$#" -ge 8 ]; then
  printf 'lf-text-preview\n'
fi
last=$((first + rows - 1))
BAT="$(command -v bat 2>/dev/null || command -v batcat 2>/dev/null)"
if [ -n "$BAT" ]; then
  exec "$BAT" --color=always --style=plain --paging=never --wrap=never \
    --terminal-width="$width" --line-range="$first:$last" -- "$file"
else
  exec sed -n "${first},${last}p;${last}q" < "$file"
fi

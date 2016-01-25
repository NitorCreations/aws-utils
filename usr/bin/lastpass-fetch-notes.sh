#!/bin/bash -e

mode="$1"
shift

if [ ! "$mode" ]; then
  echo "usage: $0 <mode> [<file> ...] [--optional <file> ...]" >&2
  echo "Files specified after --optional won't fail if the file does not exist."
  exit 1
fi

for path ; do
  if [ "$path" = "--optional" ]; then
    optional=1
    continue
  fi
  FNAME="$(basename "$path")"
  DNAME="$(dirname "$path")"
  if ! mkdir -p "$DNAME" || ! lpass show --notes "$FNAME" > "$path"; then
    if [ ! "$optional" ]; then
      echo "ERROR: Failed to get file $path"
      exit 1
    else
      echo "Optional file $path not found"
    fi
  else
    chmod $mode $path
    echo "Fetched $path"
  fi
done

#!/bin/bash -e
if [ "$1" = "--help" ]; then
    echo "usage: $0 [<file> ...]" >&2
    echo "Creates a self-extracting bash archive, suitable for storing in e.g. Lastpass SecureNotes" >&2
    exit 1
fi
eof_marker="AR_EOF_MARKER_$(basename $(mktemp --dry-run | tr . _))"
echo '#!/bin/bash -e'
echo 'umask 077'
for file ; do
    echo 'echo "Extracting '"$file"'"'
    [ -e "$file" ]
    echo 'cat > "'"$file"'" << '\'$eof_marker\'' || { echo "ERROR extracting file" ; exit 1 ; }'
    cat "$file"
    echo $eof_marker
    mode=$(stat -c '%a' "$file")
    echo 'chmod '"$mode"' "'"$file"'"'
done

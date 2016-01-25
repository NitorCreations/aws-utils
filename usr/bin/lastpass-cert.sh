#!/bin/bash -e

lastpass-login.sh webmaster@nitorcreations.com .lpass-key
lastpass-fetch-notes.sh 444 "$@"
lastpass-logout.sh

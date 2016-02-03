#!/bin/bash -xe

logged_file=/dev/shm/fetch-secrets-logged

login_if_not_already () {
  if [ ! -e $logged_file ]; then
    s3-role-download.sh nitor-infra-secure webmaster.pwd - | lastpass-login.sh webmaster@nitorcreations.com -
    touch $logged_file
  fi
}

case "$1" in
  login)
    # usage: fetch-secrets.sh login
    shift
    login_if_not_already
    ;;
  get)
    # usage: fetch-secrets.sh get <mode> [<file> ...] [--optional <file> ...]
    # logs in automatically if necessary
    shift
    mode="$1"
    shift
    login_if_not_already
    lastpass-fetch-notes.sh "$mode" "$@"
    ;;
  logout)
    # usage: fetch-secrets.sh logout
    shift
    if [ -e $logged_file ]; then
      lastpass-logout.sh
      rm $logged_file
    fi
    ;;
  *)
    # old api
    s3-role-download.sh nitor-infra-secure webmaster.pwd .lpass-key
    chmod 600 .lpass-key
    lastpass-cert.sh "$@"
    rm -f .lpass-key
    ;;
esac

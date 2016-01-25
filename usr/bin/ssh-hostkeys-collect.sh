#!/bin/bash -e
host="$1"
if [ ! "$host" -o "$host" = "--help" ]; then
   echo "usage: $0 <hostname>" >&2
   echo "Creates a <hostname>-ssh-hostkeys.sh archive in the current directory" >&2
   exit 10
fi
create-shell-archive.sh /etc/ssh/ssh_host_* > ${host}-ssh-hostkeys.sh 

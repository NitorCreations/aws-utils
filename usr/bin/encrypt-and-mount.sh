#!/bin/bash

usage() {
  if [ -n "$1" ]; then
    echo "$1"
  fi
  echo "Usage: $0 blk-device mount-path"
  exit 1
}
crypted_devices() {
  for dev in  $(dmsetup ls --target crypt | grep -v "No devices found" | awk '{ print $1 }'); do
    echo -n "$dev "
    dmsetup deps $dev -o blkdevname | awk -NF '\\(|\\)' '{ print $2 }'
  done
}
if ! [ -b "$1" ]; then
  usage "'$1' not a block device"
fi
if ! ([ -d "$2" ] || mkdir -p "$2"); then
  usage "Mount point $2 not available"
fi
DEVPATH=$1
DEV=$(basename $DEVPATH)
if crypted_devices | grep $DEV > /dev/null; then
  CRYPTDEV=$(crypted_devices | grep $DEV | cut -d" " -f1)
  umount -f /dev/mapper/$CRYPTDEV
  cryptsetup close $CRYPTDEV
fi
MOUNT_PATH=$2
TMPDIR=$(mktemp -d)
mount tmpfs $TMPDIR -t tmpfs -o size=32m
dd if=/dev/urandom of=$TMPDIR/disk.pwd bs=512 count=4 status=none iflag=fullblock
chmod 600 $TMPDIR/disk.pwd
COUNT=1
while [ -e /dev/mapper/e$COUNT ]; do
  COUNT=$(($COUNT + 1))
done
CRYPTDEV=e$COUNT
umount -f $DEVPATH
cryptsetup --cipher=aes-xts-plain64 --key-file=$TMPDIR/disk.pwd --key-size=512 \
open --type=plain $DEVPATH $CRYPTDEV
umount -f $TMPDIR
umount -f $MOUNT_PATH
mkfs.ext4 /dev/mapper/$CRYPTDEV
mount /dev/mapper/$CRYPTDEV $MOUNT_PATH

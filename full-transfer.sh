#!/bin/bash

remote_dir=rcs-ajt208-server-mirror/
dest_dir=/home/ubuntu/volume-mount/full-transfer

function echo-log() {
  time=$(date '+%Y-%m-%d %H:%M:%S')
  printf "%s SCRIPT-OUT: %s\n" "$time" "$1"
  printf "%s SCRIPT-OUT: %s\n" "$time" "$1" | gzip -9 > script-out.gz
}

function echo-status() {
  time=$(date '+%Y-%m-%d %H:%M:%S')
  printf "%s SCRIPT-OUT: \n\tAMOUNT TRANSFERRED: %s\n\t%s\n" "$time" "$1" "$2"
  printf "%s SCRIPT-OUT: \n\tAMOUNT TRANSFERRED: %s\n\t%s\n" "$time" "$1" "$2" | gzip -9 > script-out.gz
}

echo-log "BEGINNING TRANSFER: $remote_dir -> $dest_dir"
sshpass -p "$1" rsync -P -av -h is525@rds.uis.cam.ac.uk:$remote_dir $dest_dir &
transferPID=$!

while [ "$(ps -p $transferPID | wc -l)" == "2" ]; do
  size=$(du -sh . | cut -f1)
  inodes=$(df -i ~/volume-mount/ | awk '{print $3}')
  echo-status "$size" "$inodes"
  sleep 15
done

echo-log "TRANSFER DIED"




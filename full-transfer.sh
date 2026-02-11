#!/bin/bash

remote_dir=/rcs/project/ajt208/rcs-ajt208-server-mirror
dest_dir=/home/ubuntu/volume-mount/full-transfer

function echo-log() {
  time=$(date '+%Y-%m-%d %H:%M:%S')
  printf "%s SCRIPT-OUT: %s\n" "$time" "$1"
  printf "%s SCRIPT-OUT: %s\n" "$time" "$1" | gzip -9 >> script-out.gz
}

function echo-status() {
  time=$(date '+%Y-%m-%d %H:%M:%S')
  printf "%s SCRIPT-OUT: \nAMOUNT TRANSFERRED: %s\n%s\n" "$time" "$1" "$2"
  printf "%s SCRIPT-OUT: \nAMOUNT TRANSFERRED: %s\n%s\n" "$time" "$1" "$2" | gzip -9 >> script-out.gz
}


function heartbeat() {
  sleep 30
  while sleep 15; do
    if [ "$(pgrep rsync | wc -l)" -gt 0 ]; then
      size=$(du -sh $dest_dir | cut -f1)
      inodes=$(df -i $dest_dir | awk '{print $3}')
      echo-status "$size" "$inodes"
    else
      echo-log "TRANSFER DIED"
      exit
    fi
  done
}

heartbeat &
echo-log "BEGINNING TRANSFER: $remote_dir -> $dest_dir"
sshpass -p "$1" rsync -a -v --stats --partial --progress -h -r --block-size=131072 --protocol=29 is525@rds.uis.cam.ac.uk:$remote_dir $dest_dir 1> >(gzip -9 >> res.gz) 2> >(gzip -9 >> errors.gz)



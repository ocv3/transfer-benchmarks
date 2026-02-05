#!/bin/bash

directories=('rcs-ajt208-server-mirror/cashew/home/sanbot/HAP1HCT' 'rcs-ajt208-server-mirror/coconut/var/www/tom/Logos/' 'rcs-ajt208-server-mirror/nutcase/wrk/data/bsahu/LoVo_Hep-TF_ChIP-seq/macs2/')

function test_transfer() {
  c=0
  avg=0
  for remote_dir in "${directories[@]}"; do
    sleep 1
    startTime=$(date +%s)

    sshpass -p "$2" rsync -a -h --dry-run is525@rds.uis.cam.ac.uk:"$remote_dir" "$1"

    delta=$(("$(date +%s) - $startTime"))
    ((avg+=delta))
    ((c+=1))
    echo "RUN $((c))/${#directories[@]}($delta): $remote_dir -> $1"
  done
  echo "DOWNLOAD AVG FOR Tape station -> $1: $(( avg / ${#directories[@]})) seconds"
}

function clean_dir() {
  echo "CLEANING: Removing $1..."
  rm -r "$1"
}



if [[ $1 == "openstack" ]]; then
  # Will test
  #   Tape station -> openstack VM volume
  #   Tape station -> openstack VM ssd (eg. /tmp)
  dest_dirs=("/tmp/test-transfer" "/home/ubuntu/volume-mount/test-transfer")
  for dest in "${dest_dirs[@]}"; do
    echo "TEST FOR: Tape station -> $dest"
    mkdir -p "$dest"
    test_transfer "$dest" "$2"
    clean_dir "$dest"
  done
elif [[ $1 == "headnode" ]]; then
  # Will test
  #   Tape station -> head node lustre
  dest="/lustre/scratch126/gengen/teams/hgi/ov3/taipale_tapestation/test-transfer"
  echo "TEST FOR: Tape station -> $dest"
  test_transfer "$dest" "$2"
  clean_dir "$dest"
fi

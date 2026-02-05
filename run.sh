#!/bin/bash

dir=$(dirname "$0")
transfer_dest_dir=~/transfer
directories=('rcs-ajt208-server-mirror/cashew/home/sanbot/HAP1HCT' 'rcs-ajt208-server-mirror/coconut/var/www/tom/Logos/' 'rcs-ajt208-server-mirror/nutcase/wrk/data/bsahu/LoVo_Hep-TF_ChIP-seq/macs2/')

function test_transfer() {
  c=0
  avg=0
  for remote_dir in "${directories[@]}"; do
    mkdir -p "$1"
    sleep 1
    startTime=$(date +%s)

    sshpass -p "$2" rsync -a -h --dry-run is525@rds.uis.cam.ac.uk:"$remote_dir" "$1"

    delta=$(("$(date +%s) - $startTime"))
    ((avg+=delta))
    ((c+=1))
    echo "RUN $((c))/${#directories[@]}($delta): $remote_dir -> $1"
    echo "Cleaning transfer dir: $1..."
    rm -rf "$1"
  done
  echo $avg
}


if [[ $1 == "openstack" ]]; then
  # Will test
  #   Tape station -> openstack VM volume
  #   Tape station -> openstack VM ssd (eg. /tmp)
  dest_dirs=("/tmp/test-transfer" "/home/ubuntu/volume-mount/test-transfer")
  for dest in "${dest_dirs[@]}"; do
    echo "TEST FOR: Tape station -> $dest"
    test_transfer "$dest" "$2"
  done
elif [[ $1 == "headnode" ]]; then
  # Will test
  #   Tape station -> head node lustre
  dest="/lustre/scratch126/gengen/teams/hgi/ov3/taipale_tapestation/test-transfer"
  echo "TEST FOR: Tape station -> $dest"
  test_transfer "$dest" "$2"
fi




echo "$dir" $((avg/3)) "$transfer_dest_dir"


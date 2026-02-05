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

function returnDelta() {
    startTime=$(date +%s)
    $1
    delta=$(("$(date +%s) - $startTime"))
    echo $delta
}

function wrMount() {
  # 1: local path
  # 2: s3 path
  # 3: write
  # 4: cache
  json_mount=$(
  jq -nc \
    --arg Mount "$1" \
    --argjson Targets "[$(
      jq -nc \
      --arg Profile "default" \
      --arg Path "$2" \
      --arg Write "$3" \
      --arg Cache "$4" \
      '$ARGS.named'
    )]" '$ARGS.named'
  )
  wr mount -f -v --mount_json "$json_mount" & serverPID=$!
  echo $serverPID
}



function test_s3_tool() {
  # 1 Tool
  # 2 Source Local
  s3_path="ov3-transfer-test/test-transfer"

  if [ "$1" == "s5cmd" ]; then
    s5cmd \
      --endpoint-url https://cog.sanger.ac.uk \
      cp "$2" "s3://$s3_path/"
  elif [ "$1" == "rclone" ]; then
    echo "$1"
  elif [ "$1" == "aws" ]; then
    echo "$1"
  elif [ "$1" == "wrMount" ]; then
    wrMountPID=$(wrMount "$2" "$s3_path" "true" "false")

    kill "$wrMountPID"
  fi

}


if [ "$1" == "openstack" ]; then
  # Will test
  #   Tape station -> openstack VM volume
  #   Tape station -> openstack VM ssd (eg. /tmp)
  local_dest_dirs=("/tmp/test-transfer" "/home/ubuntu/volume-mount/test-transfer")
  for local_dest in "${local_dest_dirs[@]}"; do
    echo "TEST FOR: Tape station -> $local_dest"
    mkdir -p "$local_dest"
    test_transfer "$local_dest" "$2"
    clean_dir "$local_dest"
  done
elif [ "$1" == "headnode" ]; then
  # Will test
  #   Tape station -> head node lustre
  local_dest="/lustre/scratch126/gengen/teams/hgi/ov3/taipale_tapestation/test-transfer"
  echo "TEST FOR: Tape station -> $local_dest"
  test_transfer "$local_dest" "$2"
  clean_dir "$local_dest"
fi

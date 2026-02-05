#!/bin/bash

remote_test_dirs=('rcs-ajt208-server-mirror/cashew/home/sanbot/HAP1HCT' 'rcs-ajt208-server-mirror/coconut/var/www/tom/Logos/' 'rcs-ajt208-server-mirror/nutcase/wrk/data/bsahu/LoVo_Hep-TF_ChIP-seq/macs2/')
s3_path="ov3-transfer-test/test-transfer"

function test_transfer() {
  c=0
  avg=0
  for remote_dir in "${remote_test_dirs[@]}"; do
    sleep 1
    startTime=$(date +%s)

    sshpass -p "$2" rsync -a -h --dry-run is525@rds.uis.cam.ac.uk:"$remote_dir" "$1"

    delta=$(("$(date +%s) - $startTime"))
    ((avg+=delta))
    ((c+=1))
    echo "RUN $((c))/${#remote_test_dirs[@]}($delta): $remote_dir -> $1"
  done
  echo "DOWNLOAD AVG FOR Tape station -> $1: $(( avg / ${#remote_test_dirs[@]})) seconds"
}

function clean_dir() {
  echo "CLEANING: Removing $1..."
  rm -r "$1"
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
  # 3 Optional transfer
  startTime=$(date +%s)
  if [ "$1" == "s5cmd" ]; then
    s5cmd --dry-run --endpoint-url https://cog.sanger.ac.uk cp "$2" "s3://$s3_path/"
  elif [ "$1" == "rclone" ]; then
    rclone copy --dry-run "$2" ov3-s3:$s3_path
  elif [ "$1" == "aws" ]; then
    aws s3 --endpoint-url=https://cog.sanger.ac.uk cp --dryrun --recursive "$2" "s3://$s3_path"
  elif [ "$1" == "wrMount" ]; then
    wrMountPID=$(wrMount "$2" "$s3_path" "true" "false")
    $3
    kill "$wrMountPID"
  fi
  delta=$(("$(date +%s) - $startTime"))
  echo "UPLOAD TIME:$delta"
}


if [ "$1" == "openstack" ]; then
  # Will test
  #   Tape station -> openstack VM volume
  #   Tape station -> openstack VM ssd (eg. /tmp)
  #   Openstack Volume -> direct S3
  #   Openstack ssd -> direct S3
  local_dest_dirs=("/tmp/test-transfer" "/home/ubuntu/volume-mount/test-transfer")
  s3_tools=('rclone' 'aws' 's5cmd')

  for local_dest in "${local_dest_dirs[@]}"; do
    echo "TEST FOR: Tape station -> $local_dest"
    mkdir -p "$local_dest"
    test_transfer "$local_dest" "$2"

    for tool in "${s3_tools[@]}"; do
      echo "TESTING S3 TOOL $tool"
      test_s3_tool "$tool" "$local_dest/"
      rclone purge --dry-run "ov3-s3:$s3_path"
    done

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

#!/bin/bash

remote_test_dirs=('rcs-ajt208-server-mirror/cashew/home/sanbot/HAP1HCT' 'rcs-ajt208-server-mirror/coconut/var/www/tom/Logos/' 'rcs-ajt208-server-mirror/nutcase/wrk/data/bsahu/LoVo_Hep-TF_ChIP-seq/macs2/')
s3_path="ov3-transfer-test/test-transfer"
dry_run=$([ "$3" == "--dry-run" ] && echo "--dry-run")


function test_transfer() {
  # 1: local dest
  # 2: Password
  c=0
  avg=0
  for remote_dir in "${remote_test_dirs[@]}"; do
    ((c+=1))
    echo "RUN $((c))/${#remote_test_dirs[@]}: $remote_dir -> $1"
    sleep 1
    startTime=$(date +%s)

    sshpass -p "$2" rsync -av -h "$dry_run" is525@rds.uis.cam.ac.uk:"$remote_dir" "$1"

    delta=$(("$(date +%s) - $startTime"))
    ((avg+=delta))
    echo "RUN $((c))/${#remote_test_dirs[@]} TIME TOOK: $delta seconds: $remote_dir -> $1"
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

function prep_env() {
  if [ "$1" == "headnode" ]; then
    module load rclone-1.65.1/perl-5.38.0
  fi
}

function clear_s3_remote() {
  echo "CLEANING S3 REMOTE ON: $s3_path"
  rclone delete -v "$dry_run" "ov3-s3:$s3_path"
}

function test_s3_tool() {
  # 1 Tool
  # 2 Source Local
  # 3 Optional transfer
  echo "S3 TRANSFER TOOL TEST($1): $2 -> s3://$s3_path/"
  startTime=$(date +%s)
  if [ "$1" == "s5cmd" ]; then
    s5cmd "$dry_run" --endpoint-url https://cog.sanger.ac.uk cp "$2" "s3://$s3_path/"
  elif [ "$1" == "rclone" ]; then
    rclone copy "$dry_run" "$2" -v "ov3-s3:$s3_path"
  elif [ "$1" == "aws" ]; then
    dr2=$([ "$dry_run" == "--dry-run" ] && dr2="--dryrun")
    aws s3 --endpoint-url=https://cog.sanger.ac.uk cp "$dr2" --recursive "$2" "s3://$s3_path"
  elif [ "$1" == "wrMount" ]; then
    wrMountPID=$(wrMount "$2" "$s3_path" "true" "false")
    $3
    kill "$wrMountPID"
  fi
  delta=$(("$(date +%s) - $startTime"))
  echo "S3 TRANSFER TOOL TEST($1) TIME TOOK: $delta seconds : $2 -> s3://$s3_path/"
}


if [ "$1" == "openstack" ]; then
  # Will test
  #   Tape station -> openstack VM volume
  #   Tape station -> openstack VM ssd (eg. /tmp)
  #   Openstack Volume -> direct S3
  #   Openstack ssd -> direct S3
  local_dest_dirs=("/tmp/test-transfer" "/home/ubuntu/volume-mount/test-transfer")
  s3_tools=('rclone' 's5cmd')
  prep_env "$1"

  dir_num=0
  for local_dest in "${local_dest_dirs[@]}"; do
    ((dir_num++))
    echo "TEST FOR $1: Tape station -> $local_dest/$dir_num"
    mkdir -p "$local_dest"
    test_transfer "$local_dest/$dir_num" "$2"

    for tool in "${s3_tools[@]}"; do
      rclone copy test.txt "ov3-s3:$s3_path"
      test_s3_tool "$tool" "$local_dest/"
      clear_s3_remote
    done

    clean_dir "$local_dest"
  done
elif [ "$1" == "headnode" ]; then
  # Will test
  #   Tape station -> head node lustre
  #   Tape station -> ceph s3
  local_dest="/lustre/scratch126/gengen/teams/hgi/ov3/taipale_tapestation/test-transfer"
  s3_tools=('rclone' 'aws' 's5cmd')
  prep_env "$1"

  echo "TEST FOR $1: Tape station -> $local_dest"
  test_transfer "$local_dest" "$2"

  for tool in "${s3_tools[@]}"; do
    test_s3_tool "$tool" "$local_dest/"
    clear_s3_remote
  done

  clean_dir "$local_dest"
fi

#!/bin/bash
# 1 == openstack | headnode
# 2 == password

remote_test_dirs=(
'rcs-ajt208-server-mirror/cashew/home/sanbot/HAP1HCT'
'rcs-ajt208-server-mirror/coconut/var/www/jussi/data/HMG_svg/'
'rcs-ajt208-server-mirror/nutcase/wrk/data/genomic/GP5d/'
)
s3_path="ov3-transfer-test/test-transfer"

function echo-log() {
  echo "$1"
  echo "$1" >> "$(pwd)"/script-out.txt
}

function test_transfer() {
  # 1: local dest
  # 2: Password
  c=0
  avg=0
  for remote_dir in "${remote_test_dirs[@]}"; do
    ((c+=1))
    echo-log "SCRIPT-OUT: RUN $((c))/${#remote_test_dirs[@]}: $remote_dir -> $1"
    sleep 1
    startTime=$(date +%s)

    sshpass -p "$2" rsync -av -h is525@rds.uis.cam.ac.uk:"$remote_dir" "$1"

    delta=$(("$(date +%s) - $startTime"))
    ((avg+=delta))
    echo-log "SCRIPT-OUT: RUN $((c))/${#remote_test_dirs[@]} TIME TOOK: $delta seconds: $remote_dir -> $1"
  done
  echo-log "SCRIPT-OUT: DOWNLOAD AVG FOR Tape station -> $1: $(( avg / ${#remote_test_dirs[@]})) seconds"
}




function wrMount() {
  # 1: local path
  # 2: s3 path
  json_mount="[{\"Mount\":\"$1\",\"Targets\":[{\"Profile\":\"default\",\"Path\":\"$2\",\"Write\":true,\"Cache\":false}]}]"
  sleep 5
  wr mount -f -v --mount_json "$json_mount" & serverPID=$!
  echo $serverPID
}

function test_s3_tool() {
  # 1 Tool
  # 2 Source Local
  # 3 Optional transfer
  echo-log "SCRIPT-OUT: S3 TRANSFER TOOL TEST($1): $2 -> s3://$s3_path/"
  startTime=$(date +%s)
  if [ "$1" == "s5cmd" ]; then
    s5cmd --endpoint-url https://cog.sanger.ac.uk cp "$2" "s3://$s3_path/"
  elif [ "$1" == "rclone" ]; then
    rclone copy "$2" -v "ov3-s3:$s3_path"
  elif [ "$1" == "aws" ]; then
    aws s3 --endpoint-url=https://cog.sanger.ac.uk cp --recursive "$2" "s3://$s3_path"
  elif [ "$1" == "aws-headnode" ]; then
    /software/hgi/softpack/installs/groups/hgi//aws/1-scripts/aws s3 --endpoint-url=https://cog.sanger.ac.uk \
    cp --recursive "$2" "s3://$s3_path"
  elif [ "$1" == "wrMount" ]; then
    wrMountPID=$(wrMount "$2" "$s3_path")
    $3
    kill "$wrMountPID"
    umount $2
  fi
  delta=$(("$(date +%s) - $startTime"))
  echo-log "SCRIPT-OUT: S3 TRANSFER TOOL TEST($1) TIME TOOK: $delta seconds : $2 -> s3://$s3_path/"
}

function prep_env() {
  if [ "$1" == "headnode" ]; then
    module load rclone-1.65.1/perl-5.38.0
  fi
  clean_dir "$2"
  clear_s3_remote
}

function clean_dir() {
  echo-log "SCRIPT-OUT: SIZE OF LOCAL-DIR $(du -sh "$1")"
  echo-log "SCRIPT-OUT: CLEANING: Removing $1..."
  sudo rm -rf "$1"
}

function clear_s3_remote() {
  echo-log "SCRIPT-OUT: SIZE OF S3 REMOTE:$(rclone size "ov3-s3:$s3_path")"
  echo-log "SCRIPT-OUT: CLEANING S3 REMOTE ON: $s3_path"
  rclone delete -v "ov3-s3:$s3_path"
}



if [ "$1" == "openstack" ]; then
  # Will test
  #   Tape station -> openstack VM volume
  #   Tape station -> openstack VM ssd (eg. /tmp)
  #   Openstack Volume -> direct S3
  #   Openstack ssd -> direct S3
  local_dest_dirs=("/tmp/test-transfer" "/home/ubuntu/volume-mount/test-transfer")
  s3_tools=('rclone' 's5cmd')
  for local_dest in "${local_dest_dirs[@]}"; do
    prep_env "$1" "$local_dest"
  done

  dir_num=0
  for local_dest in "${local_dest_dirs[@]}"; do
    ((dir_num++))
    echo-log "SCRIPT-OUT: TEST FOR $1: Tape station -> $local_dest/$dir_num"
    mkdir -p "$local_dest"
    test_transfer "$local_dest/$dir_num" "$2"

    for tool in "${s3_tools[@]}"; do
      rclone copy test.txt "ov3-s3:$s3_path"
      test_s3_tool "$tool" "$local_dest/"
      clear_s3_remote
    done

    clean_dir "$local_dest"
  done

  wrMountDir="/home/ubuntu/wrMount"
  test_s3_tool "wrMount" "$wrMountDir" "test_transfer $wrMountDir $2"


elif [ "$1" == "headnode" ]; then
  # Will test
  #   Tape station -> head node lustre
  #   Tape station -> ceph s3
  local_dest="/lustre/scratch126/gengen/teams/hgi/ov3/taipale_tapestation/test-transfer"
  s3_tools=('rclone' 'aws-headnode')
  prep_env "$1"
  clean_dir "$local_dest"
  mkdir -p "$local_dest"

  echo-log "SCRIPT-OUT: TEST FOR $1: Tape station -> $local_dest"
  test_transfer "$local_dest" "$2"

  for tool in "${s3_tools[@]}"; do
    test_s3_tool "$tool" "$local_dest/"
    clear_s3_remote
  done

  clean_dir "$local_dest"
fi

#!/bin/bash
# 1 == openstack | headnode
# 2 == password

remote_test_dirs=(
'rcs-ajt208-server-mirror/cashew/home/sanbot/HAP1HCT'
'rcs-ajt208-server-mirror/coconut/var/www/jussi/data/HMG_svg/'
'rcs-ajt208-server-mirror/nutcase/wrk/data/genomic/GP5d/'
)
s3_path="ov3-transfer-test/test-transfer"
s3_remote="ov3-s3"

function echo-log() {
  echo "SCRIPT-OUT: $1"
  echo "SCRIPT-OUT: $1" >> "$(pwd)"/script-out.txt
}

function test_transfer() {
  # 1: local dest
  # 2: Password
  c=0
  avg=0
  for remote_dir in "${remote_test_dirs[@]}"; do
    ((c+=1))
    echo-log "RUN $((c))/${#remote_test_dirs[@]}: $remote_dir -> $1"
    sleep 1
    startTime=$(date +%s)

    sshpass -p "$2" rsync -rtv -h is525@rds.uis.cam.ac.uk:"$remote_dir" "$1"

    delta=$(("$(date +%s) - $startTime"))
    ((avg+=delta))
    echo-log "RUN $((c))/${#remote_test_dirs[@]} TIME TOOK: $delta seconds: $remote_dir -> $1"
  done
  echo-log "BENCHMARK FOR Tape station -> $1:"
  rate=$(( $(du -sb "$1" | cut -f1 | numfmt --from=iec --to=none) / avg ))
  echo-log "TOTAL TIME TAKEN: $avg - RATE: $rate bytes/second - SIZE: $(du -s "$1")"
  echo-log "DOWNLOAD AVG FOR Tape station -> $1: $( echo $rate | numfmt --to=iec )/second"
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
  echo-log "S3 TRANSFER TOOL TEST($1): $2 -> s3://$s3_path/"
  startTime=$(date +%s)
  if [ "$1" == "s5cmd" ]; then
    s5cmd --endpoint-url https://cog.sanger.ac.uk cp "$2" "s3://$s3_path/"
  elif [ "$1" == "rclone" ]; then
    rclone copy "$2" -v "$s3_remote:$s3_path"
  elif [ "$1" == "aws" ]; then
    aws s3 --endpoint-url=https://cog.sanger.ac.uk cp --recursive "$2" "s3://$s3_path"
  elif [ "$1" == "aws-headnode" ]; then
    /software/hgi/softpack/installs/groups/hgi//aws/1-scripts/aws s3 --endpoint-url=https://cog.sanger.ac.uk \
    cp --recursive "$2" "s3://$s3_path"
  elif [ "$1" == "wrMount" ]; then
    wrMountPID=$(wrMount "$2" "$s3_path")
    $3
    kill "$wrMountPID"
    umount "$2"
  fi
  delta=$(("$(date +%s) - $startTime"))
  echo-log "S3 TRANSFER TOOL TEST($1) TIME TOOK: $delta seconds : $2 -> s3://$s3_path/"
  rate=$(( $(du -s "$2" | cut -f1) / delta ))
  echo-log "S3 TRANSFER TOOL TEST($1) SPEED TRANSFER: $( echo $rate | numfmt --to=iec )/second"
}

function prep_env() {
  if [ "$1" == "headnode" ]; then
    module load /software/spack_environments/default/00/share/spack/modules/linux-ubuntu22.04-x86_64_v3/rclone-1.65.1/perl-5.38.0
  fi
  if [ "$1" == "openstack" ]; then
    clean_dir "$2"
    clear_s3_remote
    mkdir -p "$2"
  fi
}

function clean_dir() {
  echo-log "SIZE OF LOCAL-DIR $(du -sh "$1")"
  echo-log "CLEANING: Removing $1..."
  sudo rm -rf "$1"
}

function clear_s3_remote() {
  echo-log "SIZE OF S3 REMOTE:$(rclone size "$s3_remote:$s3_path")"
  echo-log "CLEANING S3 REMOTE ON: $s3_path"
  rclone delete -v "$s3_remote:$s3_path"
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
    echo-log "TEST FOR $1: Tape station -> $local_dest/$dir_num"
    mkdir -p "$local_dest"
    test_transfer "$local_dest/$dir_num" "$2"

    for tool in "${s3_tools[@]}"; do
      rclone copy test.txt "$s3_remote:$s3_path"
      test_s3_tool "$tool" "$local_dest/"
      clear_s3_remote
    done

    clean_dir "$local_dest"
  done

  wrMountDir="/home/ubuntu/wrMount"
  test_s3_tool "wrMount" "$wrMountDir" "test_transfer \"$wrMountDir\" \"$2\""
  clear_s3_remote

elif [ "$1" == "headnode" ]; then
  # Will test
  #   Tape station -> head node lustre
  #   Tape station -> ceph s3
  local_dest="/lustre/scratch126/gengen/teams/hgi/ov3/taipale_tapestation/test-transfer"
  s3_tools=('rclone' 'aws-headnode')
  prep_env "$1"

  echo-log "TEST FOR $1: Tape station -> $local_dest"
  test_transfer "$local_dest" "$2"

  for tool in "${s3_tools[@]}"; do
    test_s3_tool "$tool" "$local_dest/"
    clear_s3_remote
  done

  clean_dir "$local_dest"
fi

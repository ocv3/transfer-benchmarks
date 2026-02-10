#!/bin/bash

remote_dir="rcs-ajt208-server-mirror/"
dest_dir="/home/ubuntu/volume-mount/full-transfer"

sshpass -p "$1" rsync -P -av -h is525@rds.uis.cam.ac.uk:"$remote_dir" "$dest_dir"


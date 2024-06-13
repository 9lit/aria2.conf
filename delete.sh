#!/bin/bash

HOME=$(dirname "$(realpath -es "$0")")
source "${HOME}/Core"

gid="$1"
path="$3"
secret=$(get_config_multiple  aria2 secret)
aria2_urls="http://$(get_config_multiple aria2 server):$(get_config_multiple aria2 port)/jsonrpc"


function aria2_rpc() {
  local method=$1
  local gid=$2

  curl -X POST -d '{"jsonrpc":"2.0","method":"'$method'","id": null,
    "params":["token:'$secret'", "'$gid'"]}' $aria2_urls

}

function aria2_delete() {

  local gid=$1
  aria2_rpc aria2.removeDownloadResult "$gid"

}


# 从内存中删除已完成的任务
aria2_delete "$gid"

# 从储存空间中删除已完成的任务

rm -rf "$path"

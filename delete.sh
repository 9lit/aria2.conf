#!/bin/bash

HOME=$(dirname "$(realpath -es "$0")")
source "${HOME}/core"

function aria2_cofig() {
  get_config_multiple aria2 "$1"
}

function aria2_rpc() {
  local method=$1 gid=$2

  curl -X POST -d '{"jsonrpc":"2.0","method":"'$method'","id": null,
    "params":["token:'$secret'", "'$gid'"]}' $aria2_urls

}

function aria2_delete() {

  local gid=$1
  aria2_rpc aria2.removeDownloadResult "$gid"

}

gid="$1"; path="$3"
secret=$(aria2_cofig secret); protocol=$(aria2_cofig protocol) 
server=$(aria2_cofig server); port=$(aria2_cofig port)
aria2_urls="${protocol}://${server}:${port}/jsonrpc"

# 从内存中删除已完成的任务, 从储存空间中删除已完成的任务
aria2_delete "$gid"; rm -rf "$path"

LOG_INFO "文件${path} 下载完成,已被删除"




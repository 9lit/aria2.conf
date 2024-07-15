#!/bin/bash

HOME=$(dirname "$(realpath -es "$0")")
source "${HOME}/core" "$HOME"

SERVER=$(GetConfig "aria2.server")
TOKEN=$(GetConfig "aria2.token")
PARAMS=$1; FILE_PATH=$2


function Aria2(){
  local method=$1 params=$2
  curl -X POST -d '{"jsonrpc":"2.0","method":"'$method'","id": null, "params":["token:'$TOKEN'", '$params']}' $SERVER
}

function Delete(){ Aria2 aria2.removeDownloadResult '"'$PARAMS'"'
}

# # function Stoplist(){ Aria2 aria2.tellStopped "$PARAMS" }

# Delete && rm -rf "$FILE_PATH"

# # Stoplist '-1,1000' | jq .
GetConfig "anime | length"
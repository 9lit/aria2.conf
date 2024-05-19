#!/bin/bash

upload=$(./upload.sh "$3")
echo "$upload"

target=$(echo "$upload" | sed -n '$p')
./scrape.sh "$target"
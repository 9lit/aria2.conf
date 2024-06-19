#!/bin/bash

# 准备初始变量
HOME=$(dirname "$(realpath -es "$0")")
source "${HOME}/core" "$HOME"

LOG_INFO "执行脚本文件upload.sh, 获取文件:$3"

SOURCE_DIR=$3

function upload() {

    local mode=$1 source=$2
    local target config 
    
    target="$(get_config_multiple rclone name):$1"
    config="$(get_config_multiple rclone config)"

    rclone -vP $mode "$source" "$target" --log-file="$log_file" --config="$config"

    LOG_DEBUG "upload(), 上传模式$mode"
    LOG_DEBUG "upload(), 本地文件地址 $source"
    LOG_DEBUG "upload(), 远程路径$target"
    LOG_DEBUG "upload(), rclone 配置文件路径 $config"
    LOG_INFO "upload(), 文件成功上传至网盘"
}

source_file_name=$(basename "$SOURCE_DIR")
LOG_INFO "源文件名称$source_file_name"
ext="${source_file_name##*.}"
episode=$(echo "$source_file_name" | grep -oP '\[\d{2}\]|-\s\d+|E\d+|\[\d{2}v2\]' | grep -oP '\d+')

content="视频集号${episode}或者后缀名称${ext}获取失败, 脚本退出"
if [[ ! "$episode" && "$ext" ]]; then LOG_INFO "$content"; exit 0; fi

# 获取远程路径
IFS=$'\r\n' read -ra tasks -d $"\0" <<< "$(get_task_name)"
for task in "${tasks[@]}"; do
LOG_DEBUG "任务编号${animation}"
animation=$(get_config_multiple  "$task" video)
LOG_DEBUG "视频关键词${animation}"

if [[ "$source_file_name"^^ =~ $"$animation" ]]; then
    target_dir=$(get_config_multiple "$task" path)
    LOG_DEBUG "视频文件的远程上传路径文件夹${target_dir}"
    break
else
target_dir=0
fi

done

LOG_DEBUG "视频文件的远程上传路径文件夹${target_dir}"
#如果没有获取到目标目录, 则上传至网盘的临时文件夹,并退出脚本
if [ "$target_dir" -eq 0 ]; then
  spare=$(get_config_multiple rclone spare)
  LOG_INFO "文件不在追番列表中,上传到远程临时目录${spare}"
#   upload copyto "$SOURCE_DIR" "$spare"
  LOG_INFO "文件上传成功"
  exit 0
fi

season=$(basename "$target_dir" | grep -oP '\d+')
LOG_DEBUG "视频文件的季节号为${season}"
if [ ${#season} -eq 1 ]; then season="0$season";fi
LOG_DEBUG "视频文件的季节号格式化为${season}"

target="$(get_config_multiple rclone target)${target_dir}/S${season}E${episode}.${ext}"
LOG_INFO "文件的远程上传路径(最终地址)${target}"

# 上传文件
# upload copyto "$SOURCE_DIR" "$target" 


# 是否调用 scrape.sh 脚本文件
if [ "$(get_config_multiple scrape flag)" -eq 0 ]; then 
    LOG_INFO "scrape 的 flag 等于 0, 调用脚本文件 scrape.sh 准备刮削远程视频文件" 0
    "${HOME}"/scrape.sh "$target"
    LOG_DEBUG "执行文件地址${HOME}/scrape.sh $target"
else
    LOG_INFO "scrape 的 flae 不为 0, 退出脚本"
fi
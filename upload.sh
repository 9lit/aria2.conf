#!/bin/bash

# 准备初始变量
HOME=$(dirname "$(realpath -es "$0")")
source "${HOME}/Core"
SOURCE_DIR=$3


ulog "执行脚本文件upload.sh, 获取文件:$3" 0

# 获取输入文件信息, 视频文件名称, 后缀名, 集号
source_file_name=$(basename "$SOURCE_DIR")
ext="${source_file_name##*.}"
episodes=$(echo "$source_file_name" | grep -oP '\[\d{2}\]|-\s\d+|E\d+|\[\d{2}v2\]' | grep -oP '\d+')

if [ "$source_file_name" ]; then ulog "视频文件名称${source_file_name}和后缀名${ext}获取成功" 0; fi
if [ "$episodes" ]; then ulog "集号:${episodes}获取" 0; else ulog "集号${episodes}获取失败,脚本退出" 2; exit 0;fi


IFS=$'\r\n' read -ra tasks -d $"\0" <<< "$(get_task_name)"

# 获取远程路径
for task in "${tasks[@]}"; do
animation=$(get_config_multiple  "$task" video)

if [[ "$source_file_name"^^ =~ $"$animation" ]]; then
    target_dir=$(get_config_multiple "$task" path)
    ulog 远程路径["${target_dir}"]获取成功,准备上传文件 0
    break
else
    target_dir=0
fi

done

#如果没有获取到目标目录, 则上传至网盘的临时文件夹,并退出脚本
if [ "$target_dir" == 0 ]; then
    spare=$(get_config_multiple rclone spare)
    ulog "文件${source_file_name}不在追番列表中, 上传到远程目录${spare}, 并退出脚本" 1
    copyto "$SOURCE_DIR" "$spare" 
    exit 0 
fi

# 向目标目录中获取季节号,并格式化为 "00"
season=$(basename "$target_dir" | grep -oP '\d+')
if [ ${#season} -eq 1 ]; then season="0$season";fi

# 获取远程路径, 格式化目标文件名称 "S00E00.ext"
target="$(get_config_multiple rclone target)${target_dir}/S${season}E${episodes}.${ext}"
ulog "目标地址获取成功:${target}, 准备移动文件" 0

#移动并重命名
copyto "$SOURCE_DIR" "$target" 
ulog "文件上传至网盘${target}成功,准备刮削数据" 0

# 是否调用 scrape.sh 脚本文件
if [ "$(get_config_multiple scrape flag)" -eq 0 ]; then 
    ulog "scrape 的 flage 等于 0, 调用脚本文件 scrape.sh 准备刮削远程视频文件" 0
    "${HOME}/scrape.sh $target"; 
else
    ulog "scrape 的 flage 不为 0, 退出脚本"
fi
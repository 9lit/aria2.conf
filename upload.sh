#!/bin/bash

# 准备初始变量
HOME=$(dirname "$(realpath -es "$0")")
source "${HOME}/Core"
SOURCE_DIR=$1


btlog "脚本开始执行, 执行的文件为$3"

# 获取输入文件信息, 视频文件名称, 后缀名, 集号
source_file_name=$(basename "$SOURCE_DIR")
ext="${source_file_name##*.}"
e=$(echo "$source_file_name" | grep -oP '\[\d{2}\]|-\s\d+|E\d+' | grep -oP '\d+')

if [ "$source_file_name" ]; then btlog "视频文件名称${source_file_name}和后缀名${ext}获取成功" 400; fi
if [ "$e" ]; then btlog "集号:${e}获取" 400; else btlog "集号${e}获取失败,脚本退出" 420; exit 0;fi


tasks=$(get_task_name)
IFS=$'\r\n' read -ra tasks -d $"\0" <<< "$tasks"

# 获取远程路径
for task in "${tasks[@]}"; do
animation=$(get_config_multiple  "$task" video)

if [[ "$source_file_name"^^ =~ $"$animation" ]]; then
    target_dir=$(get_config_multiple "$task" path)
    btlog 远程路径["${target_dir}"]获取成功,准备上传文件 400
    break
else
    target_dir=0
fi

done

#如果没有获取到目标目录, 则上传至网盘的临时文件夹,并退出脚本
if [ "$target_dir" == 0 ]; then
    spare=$(get_config_multiple rclone spare)
    # cp "$SOURCE_DIR" "$PATH2"
    cp "$SOURCE_DIR" "$spare"
    btlog "文件${source_file_name}不在追番列表中, 上传到远程目录${spare}, 并退出脚本" 420
    exit 0 
fi


# 向目标目录中获取季节号,并格式化为 "00"
s=$(basename "$target_dir")
s=$(echo "$s" | grep -oP '\d+')
if [ ${#s} -eq 1 ]; then
    s="0$s"
fi

# 格式化目标文件名称 "S00E00.ext"
format_file_name="S${s}E${e}.${ext}"
btlog "文件格式化成功:${format_file_name}" 400

# 获取远程路径,
remote=$(get_config_multiple rclone remote)

target="${remote}${target_dir}/${format_file_name}"
btlog "目标地址获取成功:${target}, 准备移动文件" 400

#移动并重命名

cp "$SOURCE_DIR" "$target"
btlog "文件上传至网盘${target}成功,准备刮削数据" 400

echo "$target"
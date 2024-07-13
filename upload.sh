#!/bin/bash

# 准备初始变量
HOME=$(dirname "$(realpath -es "$0")")
source "${HOME}/core" "$HOME"

ALIST_URL=$(get_config_multiple alist url)
RCLONE_SPARE=$(get_config_multiple rclone spare)
RCLONE_TRAGE=$(get_config_multiple rclone target)
RCLONE_NAME=$(get_config_multiple rclone name)
EMAIL_SENDER=$(get_config_multiple sendmail sender)
EMAIL_PASSWD=$(get_config_multiple sendmail passwd)
EMAIL_RECIPIENT=$(get_config_multiple sendmail recipient)
EMAIL_FLAG=$(get_config_multiple sendmail flag)
SOURCE_DIR=$3

function get_file_info() {
    source_file_name=$(basename "$SOURCE_DIR")
    ext="${source_file_name##*.}"
    episode=$(echo "$source_file_name" | grep -oP '\[\d{2}\]|-\s\d+|E\d+|\[\d{2}v2\]' | grep -oP '\d+')
}

function get_remote_path() {
    # 获取远程路径
    IFS=$'\r\n' read -ra tasks -d $"\0" <<< "$(get_task_name)"
    for task in "${tasks[@]}"; do
        animation=$(get_config_multiple  "$task" video) && target_dir=$(get_config_multiple "$task" path) && animation_name=$(get_config_multiple "$task" name)
        if [[ "$source_file_name"^^ =~ $"$animation" ]]; then break; else target_dir=0; fi
    done

}

function animation_list() {
    season=$(basename "$target_dir" | grep -oP '\d+')
    if [ ${#season} -eq 1 ]; then season="0$season";fi
    target="${RCLONE_TRAGE}/${target_dir}/S${season}E${episode}.${ext}"
    rclone_path="${RCLONE_NAME}:$target" 
}

function sendmail() {
    # 发送推送成功的电子邮件
    local status
    if [ $EMAIL_FLAG -ne 0 ]; then exit 0; fi
    # /home/kuma/venvs/bin/python3 sendmail.py "$title" "$"
    message=$(python /c/Users/lain/test.py)

    if [ $message == "邮件发送成功！" ]; then status="成功"; else status="失败";fi
    mailmessage="
===邮件发送信息
发件人: $EMAIL_SENDER
收件人: $EMAIL_RECIPIENT
是否发送成功: $status
"
    LOG "$mailmessage" "$source_file_name"
}

get_file_info && get_remote_path

#如果没有获取到目标目录, 则上传至网盘的临时文件夹,并退出脚本
if [ "$target_dir" -eq 0 ]; then 
  rclone_path="${RCLONE_SPARE}/${source_file_name}"
  url="${ALIST_URL}${rclone_path}" && title="$source_file_name"
  animation_name=""
else 
  animation_list 
  url="${ALIST_URL}${target}" && title="$animation_name"
fi

UPLOAD copyto "$SOURCE_DIR" "${RCLONE_NAME}:${rclone_path}"

string="
===输入视频文件信息
输入文件路径: $SOURCE_DIR
文件名称: $source_file_name
文件后缀: $ext
视频集号: $episode
文件大小: $(du -h "$SOURCE_DIR" | cut -d '/' -f1)

===rclone 远程路径信息
视频系列名称: $animation_name
rclone 名称: $RCLONE_NAME
上传路径: $rclone_path

===alist 在线观看地址
$(URLENCODE "$url")
"

sendmail

LOG "$string" "$source_file_name"

# # 是否调用 scrape.sh 脚本文件
# if [ "$(get_config_multiple main scrape_flag)" -eq 0 ]; then 
#     "${HOME}"/scrape.sh "$target"
#     LOG_DEBUG "执行文件地址${HOME}/scrape.sh $target"
# else
#     LOG_INFO "scrape 的 flae 不为 0, 退出脚本"
# fi
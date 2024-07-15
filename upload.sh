#!/bin/bash

# 准备初始变量
HOME=$(dirname "$(realpath -es "$0")")
source "${HOME}/core" "$HOME"

ONLINE_URL=$(GetConfig "other.online_url")
# rclone 信息
RCLONE_SPARE=$(GetConfig "rclone.spare")
RCLONE_TRAGE=$(GetConfig "rclone.target")
RCLONE_NAME=$(GetConfig "rclone.name")
# 邮箱信息
EMAIL_SENDER=$(GetConfig "email.sender")
EMAIL_PASSWD=$(GetConfig "email.passwd")
EMAIL_RECIPIENT=$(GetConfig "email.recipient")
EMAIL_FLAG=$(GetConfig "email.flag")
EMAIL_PYTHON_FILE="${HOME}/$(GetConfig email.path)"
SOURCE_DIR=$3

function get_file_info() {
    source_file_name=$(basename "$SOURCE_DIR")
    ext="${source_file_name##*.}" && include_ext=".mkv.mp4" && if [ ! $include_ext^^ =~ $ext^^ ]; then return 0; fi
    episode=$(echo "$source_file_name" | grep -oP '\[\d{2}\]|-\s\d+|E\d+|\[\d{2}v2\]' | grep -oP '\d+')
}

function get_remote_path() {
    anime_len=$(GetConfig "anime | length")
    for ((i = 0; i < anime_len; i++)); do
        anime=$(GetConfig "anime.[$i]"); anime_title=$($anime | jq .title); anime_name=$($anime | jq .name)
        if [ "$source_file_name"^^ =~ "$anime_title" ]; then target_dir=$($anime | jq .path); break else target_dir=0; fi
    done
}

function animation_list() {
    season=$(basename "$target_dir" | grep -oP '\d+')
    if [ ${#season} -eq 1 ]; then season="0$season";fi
    rclone_path="${RCLONE_TRAGE}/${target_dir}/S${season}E${episode}.${ext}"
}

function sendmail() {
    # 发送推送成功的电子邮件
    local status
    if [ $EMAIL_FLAG -ne 0 ]; then exit 0; fi
    message=$(python3  "$EMAIL_PYTHON_FILE" "$EMAIL_SENDER" "$EMAIL_PASSWD" "$EMAIL_SENDER" "$source_file_name" "$string")

    if [ $message -eq 0 ]; then status="成功"; else status="失败";fi
    mailmessage="
===邮件发送信息
发件人: $EMAIL_SENDER
收件人: $EMAIL_RECIPIENT
是否发送成功: $status
"
    LOG "$mailmessage" "$source_file_name"
}

get_file_info && if [ $? -eq 0 ]; then LOG "文件不符合, 停止上传到网盘" "$source_file_name"; exit 0; else get_remote_path; fi

#如果没有获取到目标目录, 则上传至网盘的临时文件夹,并退出脚本
if [ "$target_dir" -eq 0 ]; then rclone_path="${RCLONE_SPARE}/${source_file_name}"; anime_name=""
else animation_list; fi

UPLOAD copyto "$SOURCE_DIR" "${RCLONE_NAME}:${rclone_path}"

string="
===输入视频文件信息
输入文件路径: $SOURCE_DIR
文件名称: $source_file_name
文件后缀: $ext
视频集号: $episode
文件大小: $(du -h "$SOURCE_DIR" | cut -d '/' -f1)

===rclone 远程路径信息
视频系列名称: $anime_name
rclone 名称: $RCLONE_NAME
上传路径: $rclone_path
是否上传成功: $? 成功:0, 失败:1

===alist 在线观看地址
$(URLENCODE "${ONLINE_URL}${rclone_path}")
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
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
EMAIL_DOWNLOAD_URL="$(GetConfig email.download_url)"
SOURCE_DIR=$3

function get_file_info() {
    source_file_name=$(basename "$SOURCE_DIR")
    ext="${source_file_name##*.}" && include_ext=".mkv.mp4" && if [[ ! "$include_ext"^^ =~ $ext ]]; then return 1; fi
    episode=$(echo "$source_file_name" | grep -oP '\[\d{2}\]|-\s\d+|E\d+|\[\d{2}v2\]' | grep -oP '\d+')
}

function get_remote_path() {
    anime_len=$(GetConfig "anime | length")
    for ((i = 0; i < anime_len; i++)); do
        anime=$(GetConfig "anime.[$i]")
        anime_title_list=$(echo $anime | jq .title) && anime_title_len=$(echo $anime_title_list | jq length)
        for ((y = 0; y < anime_title_len; y++)); do anime_title=$(echo $anime_title_list | jq -r .[$y])
            if [[ "$source_file_name"^^ =~ $anime_title ]]; then anime_name=$(echo $anime | jq -r .name); anime_dir=$(echo $anime | jq -r .path); return 0; fi
        done
    done; return 1
}

function video_trage_dir() {
    # 获取视频在网盘的位置, 如果 get_remote_path 函数返回的是0 则使用此函数
    # 通过远程路径获取到季节号, 并将视频文件名格式化为 S00E00.mp4 格式
    if [ $? -ne 0 ]; then return 1; fi
    season=$(basename "$anime_dir" | grep -oP '\d+')
    if [ ${#season} -eq 1 ]; then season="0$season";fi
    rclone_path="${RCLONE_TRAGE}${anime_dir}/S${season}E${episode}.${ext}"
}

function video_spare_dir() {
    # 获取视频文件在网盘的临时文件位置, 即 配置文件中 anime 没有匹配此视频文件信息
    # 上一个函数返回的值为 1  时, 调用此函数, 否者返回 0 .
    if [ $? -eq 0 ]; then return 0; fi
    rclone_path="${RCLONE_SPARE}/${source_file_name}"
}

function sendmail() {
    # 发送电子邮件, 使用自定义的 py 脚本, 由 EMAIL_FLAG(配置 json 文本中的 email.flag) 变量 控制是否使用此功能, 0:启用, 1:关闭
    # 如果 没有此脚本文件,则从 GitHub 仓库获取,并下载
    # 发送邮件后, 返回状态信息, 并写入到日志文件中
    local status
    if [ $EMAIL_FLAG -ne 0 ]; then exit 1; fi
    if [ ! -f "$EMAIL_PYTHON_FILE" ]; then $(curl -o "$EMAIL_PYTHON_FILE" "$EMAIL_DOWNLOAD_URL"); fi
    message=$(python  "$EMAIL_PYTHON_FILE" "$EMAIL_SENDER" "$EMAIL_PASSWD" "$EMAIL_SENDER" "$source_file_name" "$string")

    if [ $message -eq 0 ]; then status="成功"; else status="失败: $message";fi
    mailmessage="
===邮件发送信息
发件人: $EMAIL_SENDER
收件人: $EMAIL_RECIPIENT
是否发送成功: $status
"
    LOG "$mailmessage" "$source_file_name"
}

# 获取文件信息, 如果后缀名不符合,即不为 mp4 和 mkv 则停止上传到网盘, 并退出脚本 
get_file_info; if [ $? -eq 1 ]; then LOG "文件不符合, 停止上传到网盘" "$source_file_name"; exit 1; else get_remote_path; fi

#如果没有获取到目标目录, 则上传至网盘的临时文件夹
video_trage_dir; video_spare_dir

# 上传到网盘
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
$(URLENCODE "${ONLINE_URL}/${rclone_path}")
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
#!/bin/bash

# 准备初始变量
HOME=$(pwd)
source "${HOME}/config.sh"
source "${HOME}/urlencode.sh"
SOURCE_DIR=$3
DATE=$(date "+%Y-%m-%d %H:%M:%S")
LOG="${HOME}/bt.script.log"

log() {
    echo -e "$2${DATE}++++$1" | tee -a $LOG
}

log "脚本开始执行, ${SOURCE_DIR}" '\r'

# 获取输入文件信息, 视频文件名称, 后缀名, 集号
source_file_name=$(basename "$SOURCE_DIR")
ext="${source_file_name##*.}"
episode=$(echo "$source_file_name" | grep -oP '\[\d{2}\]|-\s\d+')
episode=$(echo "$episode" | grep -oP '\d+')

log "视频名称:${source_file_name}\r集号:${episode}\r文件扩展名称:${ext}"

# 获取目标目录
for key in "${!ANIMATION[@]}"; do 
    if [[ ${source_file_name^^} =~ ${key^^} ]]; then
        target_dir=${ANIMATION[$key]}
        log "获取目标目录成功, ${target_dir}"
        break
    else
        target_dir=0
    fi
done

#如果没有获取到目标目录, 则上传至网盘的临时文件夹,并退出脚本
if [ "$target_dir" == 0 ]; then
    # cp "$SOURCE_DIR" "$PATH2"
    log "获取目标目录失败, 上传到临时目录${SPARE_DIR}"
    exit 0 
fi


# 向目标目录中获取季节号,并格式化为 "00"
season=$(basename "$target_dir")
season=$(echo "$season" | grep -oP '\d+')
if [ ${#season} -eq 1 ]; then
    season="0$season"
fi

# 格式化目标文件名称 "S00E00.ext"
format_file_name="S${season}E${episode}.${ext}"
target="${TARGET}${target_dir}/${format_file_name}"

log "文件格式化成功:${format_file_name},目标地址获取成功:${target}"

#移动并重命名
cp "$SOURCE_DIR" "$target"

log "文件上传成功, 开始刮削视频信息"

# 刮削视频信息

# 分割字符串
## 去掉头文件, 获取tv文件夹名称
target_dir=${target_dir:1} 
video_info=$(dirname "$target_dir")

IFS='.'; read -ra name_and_year <<<"$video_info"

# 获取剧集名称和年份
title=${name_and_year[0]}
year=${name_and_year[-1]}

log "剧集名称[${title}]和年份[${year}]获取成功 "

# 对视频名称进行编码
title=$(urlencode "$title")

id=$(curl --request GET \
     --url "https://api.themoviedb.org/3/search/tv?query=${title}&include_adult=false&language=${TMDB_LANG}&page=1&year=${year}" \
     --header "$HEADERS" | jq ".results[0].id")

# 获取集信息
episodeinfo=$(curl --request GET \
     --url "https://api.themoviedb.org/3/tv/${id}/season/${season}/episode/${episode}?language=${TMDB_LANG}" \
     --header "$HEADERS")


nfo_outpath=${target/%.m*/.nfo}
thumb_outpath=${target/%.m*/-thumb.jpg}
tmp_nfo="/root/.aria2c/nfo.nfo"
tmp_thumb="/root/.aria2c/thumb.jpg"


xml() {
    echo "$1" >> "$tmp_nfo"
}

tag() {
    echo "$episodeinfo" | jq -r ".$1"
}

list_xml() {
    
    a=$(echo "$episodeinfo" | jq -r '.crew[] | select( .job == "'$1'" ) | .name')
    IFS=$'\r\n' read -ra ADDR -d $'\0' <<< "$a"

    for i in "${ADDR[@]}"; do
        if [ "$1" == "Writer" ]; then
            xml "   <credits>${i}</credits>"
        else
            xml "   <director>${i}</director>"
        fi
    done

}

actor() {
    num=$(echo "$episodeinfo" | jq -r ".$1 | length")
    number=0
    if [ $num -eq 0 ]; then
        exit 0
    fi
    while [ $number -lt $num ]; do
        profile_path="${PROFILE_URL}$(tag guest_stars[$number].profile_path)"
        xml "   <actor>"
        xml "       <name>$(tag guest_stars[$number].name)</name>"
        xml "       <role>$(tag guest_stars[$number].character)</role>"
        xml "       <thumb>${profile_path}</thumb>"
        xml "       <order>$(tag guest_stars[$number].order)</order>"
        xml "   </actor>"
    number=$((number + 1))
    echo $number
    done
}

image_url="${IMAGE_URL}$(tag still_path)"
xml '<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>'
xml '<episodedetails>'
xml "   <title>$(tag name)</title>"
xml "   <plot>$(tag overview)</plot>"
xml "   <runtime>$(tag runtime)</runtime>"
xml "   <thumb aspect='thumb' preview=${image_url}></thumb>"
xml "   <uniqueid type='imdb' default='true'>$(tag id)</uniqueid> "
list_xml "Writer"
list_xml "Director"
actor guest_stars
xml "   <aired>$(tag air_date)</aired>" 
xml '<episodedetails>'

# 下载缩略图文件
curl -o "$tmp_thumb" "$image_url"

mv "$tmp_thumb" "$thumb_outpath"
mv "$tmp_nfo" "$nfo_outpath"

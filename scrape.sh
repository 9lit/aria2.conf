#!/bin/bash

# 使用 tmdb api 对视频文件进行信息刮削
#获取目标目录, 设置家目录, 打印日志
TARGET=$1
HOME=$(dirname "$(realpath -es "$0")")
source "${HOME}/core" "$HOME"
LOG_INFO "执行脚本文件scrape.sh, 刮削文件$TARGET"

# 对字符串进行 16 进制编码
function urlencode() {
  local length="${#1}"
  for (( i = 0; i < length; i++ )); do
    local c="${1:i:1}"
    case $c in
      [a-zA-Z0-9.~_-]) printf "$c" ;;
    *) printf "$c" | xxd -p -c1 | while read x;do printf "%%%s" "$x";done
  esac
done
}

function curl_get() {

    local url=$1
    local headers
    headers="Authorization: Bearer $(printenv tmdb_auth)"

    curl --request GET --url "$url" --header "$headers"

}

cache=$(get_config_multiple scrape nfo_cache)
function xml() {
    echo "$1" >> "$cache"
}

# ((meta))
function tag() {
  local node="$1"
  echo "$meta" | jq -r ".$node"
}

function xml_completion() {
    local element="$1"; local text="$2"; local empty="$3"; local attr="$4"
    content="$empty<${element}${attr}>$text</$element>"
    xml "$content"
    LOG_DEBUG "格式化xml $content"
}

# 将演员信息添加到 xml 文件中的方法
# ((index))
function actor_tag() {
    # 从 tmdb 等接口中获取演员信息
    local node="$1"
    tag "guest_stars[$index].$node"
}

function actor_xml_completion() {
# 将获取到的演员信息,格式化为 xml 格式
  local text prefix
  local empty="    ";
  declare -A actor=(["name"]="name" ["role"]="character" ["thumb"]="profile_path" ["order"]="order")

  for element in ${!actor[*]}; do
    node=${actor[$element]}; prefix=""
    if [ "$element" = "thumb" ]; then prefix=$(get_config_multiple tmdb profile); fi
    text="${prefix}$(actor_tag $node)"
    xml_completion "$element" "$text" "$empty"
  done
}

function actor() {
  LOG_INFO "刮削演员信息"
  meta="$1"; index=0
  num=$(echo "$meta" | jq -r ".guest_stars | length")
  if [ "$num" -eq 0 ]; then return 0; fi
  while [ $index -lt "$num" ]; do
    xml "  <actor>"; actor_xml_completion; xml "  </actor>"
    index=$((index + 1))
  done
}

## 刮削工作人员信息

function staff_xml_completion() {
# 获取演员姓名, 并格式化演员信息
  local element=""; local empty="  ";
  if [ "$staff_post" = "Writer" ]; then element="credits"; else element="director"; fi
  LOG_DEBUG "staff_xml_completion() 工作职位 ${element}, 工作人员名字${staff_name}"
  xml_completion "$element" "$staff_name" "$empty"
}

function staff_name() {
#获取工作人员,导演和脚本家的姓名列表
  local staff_name
  # local post="$1"
  name_string=$(echo "$episode_meta" | jq -r '.crew[] | select( .job == "'$staff_post'" ) | .name')
  IFS=$'\r\n' read -ra ADDR -d $'\0' <<< "$name_string"
  for staff_name in "${ADDR[@]}"; do staff_xml_completion; done

}

function staff() {
#刮削工作人员信息主方法
  LOG_INFO "刮削工作人员信息"
  local staff_post
  posts=("Writer" "Director")
  for staff_post in "${posts[@]}"; do staff_name; done
}

function base_is_attr() {
  local attr=""
  if [ "$element" = "thumb" ]; then
    thumb_url="$(get_config_multiple tmdb image)$text"
    attr=" aspect='thumb' preview='${thumb_url}'"
  elif [ "$element" = "uniqueid" ]; then
    attr=" type='imdb' default='true'"
  fi
  echo "$attr"
}

function base_xml_completion() {
    local element="$1"; node="$2"
    local empty="  "; local attr=""
    local text
    text="$(tag $node)"; attr="$(base_is_attr $element)"
    LOG_DEBUG "xml 标签内容${text}, 属性值${attr}"
    xml_completion "$element" "$text" "$empty" "$attr"

}

function base() {
  LOG_INFO "开始刮削元数据的基本信息"
  meta="$1"
  declare -A base=(["title"]="name" ["plot"]="overview" ["runtime"]="runtime" ["thumb"]="still_path")
  base["uniqueid"]="id"; base["aired"]="air_date"

  for element in ${!base[*]}; do
    LOG_DEBUG "xml 元素名称 ${element}"
    node=${base[$element]}
    LOG_DEBUG "元数据中的键 ${node}"
    base_xml_completion "$element" "$node"
  done
}

# 获取文件路径和文件名称
filename=$(basename "$TARGET")
dir_name=$(dirname "$TARGET")

# 获取剧集名称以及年份信息
IFS='/'; read -ra episode_path <<<"$TARGET"
episode_folder="${episode_path[-3]}"
LOG_DEBUG "剧集文件夹为${episode_folder}"
IFS='.'; read -ra name_and_year <<<"${episode_folder}"
title=${name_and_year[0]}; year=${name_and_year[-1]}
if [[ ! "$title" && "$year" ]]; then LOG_DEBUG "电视剧名称${title}, 电视剧年份${year}"  ; exit 0; fi

title=$(urlencode "$title")
LOG_DEBUG "对电视剧名称进行编码处理${title}"

# 获取刮削信息. 语言, 缩略图地址以及演员缩略图地址
lang=$(get_config_multiple tmdb lang)
LOG_INFO "刮削语言${lang}"
# 获取剧集的季节号以及剧集号
se=$(echo "$filename" | grep -oP "\d{2}")
season=$(echo "$se" | sed -n 1p)
episode=$(echo "$se" | sed -n 2p)
LOG_DEBUG "剧集季节号${season}, 剧集集号${episode}"

# 获取剧集的 tmdb id, 以及根据 id 号获取当前剧集元数据
url="https://api.themoviedb.org/3/search/tv?query=${title}&include_adult=false&language=${lang}&year=${year}"
id=$(curl_get "$url" | jq ".results[0].id")
if [ ! "$id" ]; then LOG_DEBUG "剧集 tmdb id ${id}"; exit 2; fi
url="https://api.themoviedb.org/3/tv/${id}/season/${season}/episode/${episode}?language=${lang}"
LOG_DEBUG "请求地址${episode_meta}"
episode_meta="$(curl_get "$url")"
LOG_DEBUG "剧集元数据${episode_meta}"

LOG_INFO "开始刮削视频元数据"
xml '<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>'
xml '<episodedetails>'
base "$episode_meta"; staff "$episode_meta"; actor "$episode_meta"
xml '</episodedetails>'
LOG_INFO "视频元数据刮削成功"

LOG_INFO "开始下载集缩略图"
tmdb_image=$(get_config_multiple tmdb image)
LOG_DEBUG "集缩略图下载网址${tmdb_image}"
thumb_cache=$(get_config_multiple scrape thumb_cache)
LOG_INFO "集缩略图缓存地址 ${thumb_cache}"
thumb_url="${tmdb_image}$(tag still_path)"
curl -o "$thumb_cache" "$thumb_url"
LOG_INFO "缩略图成功下载成功"

LOG_INFO "开始将将刮削后的信息上传到远程路径"
nfo_cache=$(get_config_multiple scrape nfo_cache)
LOG_INFO "集元数据缓存地址${nfo_cache}"
nfo="${dir_name}/${filename/%.*/.nfo}"
LOG_INFO "集元数据上传地址${nfo_cache}"
thumb="${dir_name}/${filename/%.*/-thumb.jpg}"
LOG_INFO "集缩略图远程地址, ${thumb}"

upload moveto "$nfo_cache" "$nfo"; upload moveto "$thumb_cache" "$thumb"
LOG_INFO "集缩略图和集信息成功上传至远程路径"

rm -rf "$nfo_cache" "$thumb_cache"
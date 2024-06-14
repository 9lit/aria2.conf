#!/bin/bash

# 使用 tmdb api 对视频文件进行信息刮削
#获取目标目录, 设置家目录, 打印日志
target=$1
HOME=$(dirname "$(realpath -es "$0")")
source "${HOME}/Core"
slog "执行脚本文件scrape.sh, 刮削文件$target" 0

# 获取文件路径和文件名称
filename=$(basename "$target")
dir_name=$(dirname "$target")
# 设置视频缩略图名称
thumb="${dir_name}/${filename/%.*/.jpg}"
slog "设置缩略图地址${thumb}" 0

# 获取剧集名称以及年份信息
IFS='/'; read -ra tv_name <<<"$target"
IFS='.'; read -ra name_and_year <<<"${tv_name[-3]}"
title=${name_and_year[0]}
year=${name_and_year[-1]}
if [[ "$title" && "$year" ]]; then slog "剧集名称${title}和年份${year}获取成功" 0; else slog "剧集名称${title}或年份${year}获取失败" 2; exit 0; fi

# 对视频名称进行编码
title=$(urlencode "$title")

# 获取刮削信息. 语言, 缩略图地址以及演员缩略图地址
lang=$(get_config_multiple tmdb lang)
tmdb_image=$(get_config_multiple tmdb image)
# 获取剧集的季节号以及剧集号
se=$(echo "$filename" | grep -oP "\d{2}")
season=$(echo "$se" | sed -n 1p)
episodes=$(echo "$se" | sed -n 1p)

# 获取剧集的 tmdb id, 以及根据 id 号获取当前剧集元数据
url="https://api.themoviedb.org/3/search/tv?query=${title}&include_adult=false&language=${lang}&year=${year}"
id=$(echo "$(curl_get "$url")" | jq ".results[0].id")
if [ "$id" ]; then slog "tv系列 id 为${id}" 0; else slog "tv系列id获取失败,程序退出"; exit 2; fi
url="https://api.themoviedb.org/3/tv/${id}/season/${season}/episode/${episodes}?language=${lang}"
episode_meta="$(curl_get "$url")"

slog "开始刮削视频元数据" 0
xml '<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>'
xml '<episodedetails>'
base "$episode_meta"; staff "$episode_meta"; actor "$episode_meta"
xml '</episodedetails>'
slog "视频元数据刮削成功" 0

slog "开始下载集缩略图" 0
thumb_cahce=$(get_config_multiple scrape thumb_cahce)
slog "集缩略图地址获取成功 ${thumb_cahce}" 0
thumb_url="${tmdb_image}$(tag still_path)"
curl -o "$thumb_cahce" "$thumb_url"
slog "缩略图成功下载成功" 0

slog "开始将将刮削后的信息上传到远程路径中" 0
nfo_cache=$(get_config_multiple scrape nfo_cache)
nfo="${dir_name}/${filename/%.*/.nfo}"
thumb="${dir_name}/${filename/%.*/.jpg}"
slog "集元数据缓存获取成功, ${nfo_cache}" 0
slog "集元数据远程地址获取成功, ${nfo}" 0
slog "缩略图缓存获取成功, ${thumb_cahce}" 0
slog "缩略图远程地址获取成功, ${thumb}" 0

moveto "$nfo_cache" "$nfo"; moveto "$thumb_cahce" "$thumb"
slog "集缩略图和集信息成功上传至远程路径"

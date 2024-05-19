#!/bin/bash
# 使用 tmdb api 对视频文件进行信息刮削

target=$1
HOME=$(dirname "$(realpath -es "$0")")
source "${HOME}/Core"

xml(){ 
  echo "$1" >> "$cache_nfo" 
}

tag() {
  echo "$ep" | jq -r ".$1"
}

list_xml() {
  local tag=$1

  a=$(echo "$ep" | jq -r '.crew[] | select( .job == "'$tag'" ) | .name')
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
    num=$(echo "$ep" | jq -r ".$1 | length")
    number=0
    if [ "$num" -eq 0 ]; then
        return 0
    fi
    while [ $number -lt "$num" ]; do
        profile_path="${tmdb_profile}$(tag guest_stars[$number].profile_path)"
        xml "   <actor>"
        xml "       <name>$(tag guest_stars[$number].name)</name>"
        xml "       <role>$(tag guest_stars[$number].character)</role>"
        xml "       <thumb>${profile_path}</thumb>"
        xml "       <order>$(tag guest_stars[$number].order)</order>"
        xml "   </actor>"
    number=$((number + 1))
    done
}


btlog "开始执行视频刮削脚本"

filename=$(basename "$target")
dir_name=$(dirname "$target")
thumb="${dir_name}/${filename/%.*/.jpg}"

btlog "设置缩略图地址${thumb}"

IFS='/'; read -ra tv_name <<<"$target"
IFS='.'; read -ra name_and_year <<<"${tv_name[-3]}"
title=${name_and_year[0]}
year=${name_and_year[-1]}
if [[ "$title" && "$year" ]]; then btlog "剧集名称${title}和年份${year}获取成功" 400; else btlog "剧集名称${title}或年份${year}获取失败" 420; exit 0; fi

# 对视频名称进行编码
title=$(urlencode "$title")

lang=$(get_config_multiple tmdb lang)
tmdb_image=$(get_config_multiple tmdb image)
tmdb_profile=$(get_config_multiple tmdb profile)
se=$(echo "$filename" | grep -oP "\d{2}")
s=$(echo "$se" | sed -n 1p)
e=$(echo "$se" | sed -n 1p)

url="https://api.themoviedb.org/3/search/tv?query=${title}&include_adult=false&language=${lang}&year=${year}"
id=$(echo "$(curl_get "$url")" | jq ".results[0].id")

if [ "$id" ]; then btlog "tv系列 id 为${id}" 400; else btlog "tv系列id获取失败,程序退出"; exit 0; fi

url="https://api.themoviedb.org/3/tv/${id}/season/${s}/episode/${e}?language=${lang}"
ep="$(curl_get "$url")"


# 刮削视频元数据
cache_nfo="${HOME}/nfo"
nfo="${dir_name}/${filename/%.*/.nfo}"
btlog "设置视频信息地址${nfo}"
thumb_tmdb_url="${tmdb_image}$(tag still_path)"
xml '<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>'
xml '<episodedetails>'
xml "   <title>$(tag name)</title>"
xml "   <plot>$(tag overview)</plot>"
xml "   <runtime>$(tag runtime)</runtime>"
xml "   <thumb aspect='thumb' preview=${thumb_tmdb_url}></thumb>"
xml "   <uniqueid type='imdb' default='true'>$(tag id)</uniqueid> "
list_xml "Writer"
list_xml "Director"
actor guest_stars
xml "   <aired>$(tag air_date)</aired>" 
xml '</episodedetails>'
mv "$cache_nfo" "$nfo"

# 下载集缩略图
thumb_cahce="${HOME}/thumb_cahce"
thumb="${dir_name}/${filename/%.*/.jpg}"

curl -o "$thumb_cahce" "$thumb_tmdb_url"

mv "$thumb_cahce" "$thumb"
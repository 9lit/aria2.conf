#!/bin/bash
HOME=$(dirname "$(realpath -es "$0")")
source "${HOME}/Core"
# source $conf

aria2_urls="http://$(get_config_multiple aria2 server):$(get_config_multiple aria2 port)/jsonrpc"
secret=$(get_config_multiple  aria2 secret)
path=$(get_config_multiple  aria2 path)

((md5s))
IFS=$'\r\n' read -ra md5s -d $"\0" <<< "$(cat md5)"

tasks=$(get_task_name)
IFS=$'\r\n' read -ra tasks -d $"\0" <<< "$tasks"

((old_url))
((old_xml))
for task in "${tasks[@]}"; do
    include_title=$(get_config_multiple "$task" title)
    rss_url=$(get_config_multiple "$task" url)
    rss_name=$(get_config_multiple "$task" name)

    # 获取订阅地址,和订阅规则
    if [[ "$rss_url" == "rss1" ]]; then 
      rss_url=$(get_config rss1)
      rss_rule="rss/channel/item[contains(title, '$include_title')][position()=1]/enclosure/@url"
    elif  [[ "$rss_url" == "rss2" ]]; then
      rss_url=$(get_config rss2)
      rss_rule="rss/channel/item[contains(title, '$include_title')][position()=1]/link"
    fi

    #如果旧链接和新新链接不一致, 则对xml进行跟新
    if [[ $rss_url != "$old_url" ]]; then xml="$(curl "$rss_url" )"; old_url="$rss_url"; old_xml="$xml"; fi

    # 获取下载链接
    link=$(echo "$xml" | xmlstarlet select -E "uft-8" -t -v "$rss_rule" -nl)

    # 推送到 aria2 rpc服务器 进行下载
    #检查下载链接的 md5 值, 如果不一致则停止下载
    link_md5=$(md5 "$link" )
    if [[ "${md5s[*]}" =~  $link_md5 ]]; then
        rsslog "Aria2 停止下载任务, 任务GID: ${link_md5} 任务名称: ${rss_name}" 300
    else
        rsslog "Aria2 开始下载任务, 任务GID: ${link_md5} 任务名称: ${rss_name}, 下载链接:${link}" 200
        # curl -X POST -d '{"jsonrpc":"2.0","method":"aria2.addUri","id":"'$link_md5'", \
        #     "params":["token:'$secret'",["'$link'"],{"dir":"'$path'"}]}' $aria2_urls
        echo  "$link_md5" >> md5
    fi
    index=$((index+1))

done
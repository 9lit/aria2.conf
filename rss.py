
import feedparser
import time
import datetime
import yaml
import re
import xmlrpc.client

# 网站种子解析
# rss_oschina = feedparser.parse('https://mikanani.hacgn.fun/RSS/MyBangumi?token=eoz1ajGuXAaU7LmsDmWKMw%3d%3d')
rss_oschina = feedparser.parse("./rss1", )
# 抓取内容 ， depth 抓取深度
# pprint.pprint(rss_oschina,depth=3)
rss = rss_oschina["entries"]

# 工具方法
def read(path) -> dict:
    with open(path, 'r', encoding='utf-8') as f:
        return yaml.safe_load(f)
    
def write(content, path):
    with open(path, 'w', encoding='utf-8') as f:
        yaml.safe_dump(content, f, encoding='utf-8', allow_unicode=True)
    
def string_to_list(string:str):
    return string.split(",")


def rss_time_range():
    """ rss 时间范围"""
    current_date = datetime.date.today()
    delta = datetime.timedelta(days=7)
    results = datetime.datetime.strftime(current_date - delta, "%Y-%m-%d")
    return time.strptime(results, "%Y-%m-%d")

class GetRss:

    def __init__(self, item:dict) -> None:
        
        self.item = item

    def url(self):
        url = self.item["link"]
        links = self.item['links']
        if ".torrent" in url: return url

        for link in links:
            href = link['href']
            if ".torrent" in href: return href

    def title(self):
        return self.item["title"]

    def episode(self):
        """获取视频集数, 去除合集"""
        pattern = r'\[\d{2}\]|-\s\d+|E\d+|\[\d{2}v2\]'
        pattern_collection = r' \d+[-|~]\d+ |E\d+[-|~]E\d+'
        episode = re.findall(pattern, self.title())
        collection = re.findall(pattern_collection, self.title())

        return re.findall(r"\d+", episode[0])[0] if episode and not collection else False

    def published_parsed(self):
        return self.item["published_parsed"]

class Filter:
    """过滤器"""

    def __init__(self, meta:dict, config) -> None:
        self.meta = meta
        self.config = config

    def set_date(self, rss_published):
        """过滤发布于七天前的 rss 种子"""
        # 种子发布时间小于规定时间
        return True if rss_time_range() < rss_published else False

    def set_whitelist(self, rss_title):
        """白名单"""
        for name, item in self.config.items():
            whitelist = string_to_list(item["whitelist"])
            for white in whitelist: 
                if white in rss_title: return name

        return False

    def set_blacklist(self, config_name, rss_title):
        """黑名单"""

        def blacklist():
        # 返回黑名单集合, 如果黑名单为 False 则返回空集合
            blacklist = self.config[config_name]['blacklist']
            return string_to_list(blacklist) if blacklist else []

        for black in blacklist():
            if black in rss_title:
                return True
            
        return False

    def emphasize_episode(self, config_name, rss_episode):
        """集数排重, 已下载的集数返回 False 否则返回 True"""
        def episodes():
            episodes = self.config[config_name]['episode']
            return string_to_list(episodes) if episodes else []
        
        return True if rss_episode not in episodes() else False

    
    def run(self):
        """设置下载名单, 排除已下载的集数, 和黑名单"""
        
        download_list = {}
        white_list = {}

        def set_list(_list) -> None:
            
            try:
                _list[whitelist][gr.episode()] = gr.url()
            except KeyError:
                _list[whitelist] = {}
                _list[whitelist][gr.episode()] = gr.url()

        def flag() -> bool:
            """下载标志"""
            blacklist = self.set_blacklist(whitelist, gr.title())
            episode_flag = self.emphasize_episode(whitelist, gr.episode())  if gr.episode() else False
            date_flag = self.set_date(gr.published_parsed())
            date_flag = True

            return not blacklist and episode_flag and date_flag


        for item in self.meta:
            gr = GetRss(item)

            whitelist = self.set_whitelist(gr.title()) 
            if not whitelist: continue
            # 白名单
            set_list(white_list)
            # 下载名单
            if flag(): set_list(download_list)

        return download_list

class Aria2:

    def __init__(self, download_list, config) -> None:
        self.download_list = download_list
        server = config['server']
        port = config['port']

        self.server = f"http://{server}:{port}/rpc"
        self.secret = config['secret']
        self.downpath = config['path']

        
    def write(self, name, episode):
    # 将已下载的集数写入到配置文件中去

        def format_episode():
            # 格式化集数, 如果集数格式为 1 则格式化为 01
            return episode if len(str(episode)) > 1 else f"0{episode}"
        
        def alter():
            #将新的集数写入到字典中去
            config = read(config_path)
            episode_config = config["animation"][name]["episode"]
            new_episode = episode_config + f",{episode}" if episode_config else episode
            config["animation"][name]["episode"] = new_episode
            return config

        episode= format_episode()
        write(content=alter(), path=config_path)

    def download(self, link):
        # server = xmlrpc.client.ServerProxy(self.server)
        # server.aria2.addUri(f'token:{self.secret}', [link], dict(dir=self.downpath))
        pass
    
    def run(self):

        for name in self.download_list: 
            torrent = self.download_list[name]
            for episode, link in torrent.items():
                self.download(link)
                self.write(name, episode)

def main():

    config = read(config_path)
    animation_config = config["animation"]
    aria2_config = config['aria2']
    download_list = Filter(rss, animation_config).run()
    print(download_list)
    aria2 = Aria2(download_list, aria2_config).run()


if __name__ == "__main__":

    # js = json.dumps(item, sort_keys=True, indent=4, separators=(',', ':'))
    # print(read())
    config_path = "./config_rss.yml"
    main()
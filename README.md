# aria2

由于 [Aria2 完美配置](https://github.com/P3TERX/aria2.conf) 大部分功能我不需要, 所以自己编写了一个符合自己需求的脚本
如需要更加全功能的 aria2 配置则可以直接 完美配置脚本.

+ 一款 Aria2 配置方案, 包含 aria2 配置, 和自动上传网盘的脚本;
+ 基于 Rclone, TMDB 和 Kodi;

## 1. 一键执行脚本

### 1.1 使用 nginx 进行代理
~~~bash
curl sudo curl -fsSL "http://text.1210923.xyz/aria2/config_aria2.sh" | bash -s nginx
~~~
### 1.2 不使用 代理
~~~bash
sudo curl -fsSL "http://text.1210923.xyz/aria2/config_aria2.sh" | bash
~~~

## 2. 前提

1. 下载 [RClone](https://rclone.org/rc/), 并对网盘进行挂载到本地文件中;
2. 下载并配置 [a2ra2](https://github.com/aria2/aria2), 并在配置文件 aria2.conf 中配置 on-bt-download-complete=your_config_path/upload.sh
3. 如果需要对文件信息进行自动刮削, 需要去 [Tmdb](https://www.themoviedb.org/) 申请 api 密钥
4. 由于是针对 bt 的配置文件, 文件上传后不会删除下载完成的文件

## 3. 文件说明

### 3.1 config.sh (配置文件)

+ ANIMATION: 设置追番列表, 需要手动创建字典. 下载后的剧集名称为键, 上传路劲为值
> ["Ookami to Koushinryou"]="/MERCHANT MEETS THE WISE WOLF.狼与香辛料 行商邂逅贤狼.2024/Season 1"
+ TARGET: 特定上传路径, 根据 ANIMATION 自动上传到此路径, 上传成功后会刮削此剧集数据
> TARGET="/path/your_folder/"
+ SPARE_DIR: 临时文件夹, 不在追番列表 ANIMATION 的视频会自动上传到此路径下, 上传后不会进行剧集刮削
+ TMDB_LANG: Tmdb 的刮削语言
> zh-CN, en-US
+ AUTH: Tmdb 的 api 密钥, 读取系统的环境变量 tmdb_auth, 当然也可以直接写入
+ IMAGE_URL: tmdb 的图片网址

### 3.2 urlencode.sh (对搜索的 tmdb 字符,进行 url 编码)




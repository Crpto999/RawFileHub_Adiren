import urllib.parse

# 基本URL
base_url = "http://124.70.139.101:25500/"

# 参数列表
params = {
    "target": "clash",
    "new_name": "true",
    "url": "https://d3g6o.no-mad-world.club/link/oLPizs0HwDrDB85K?clash=3&extend=1",
    "insert": "false",
    "config": "https://raw.githubusercontent.com/Crpto999/clash_adrien/main/RULES.ini",
    "append_type": "true",
    "emoji": "true",
    "list": "false",
    "tfo": "false",
    "scv": "false",
    "fdn": "false",
    "sort": "false",
    "udp": "true"
}

# 对需要编码的参数进行URLEncode处理
params["url"] = urllib.parse.quote(params["url"], safe='')
params["config"] = urllib.parse.quote(params["config"], safe='')

# 将参数拼接成查询字符串
query_string = "&".join([f"{key}={value}" for key, value in params.items()])

# 最终的URL
final_url = f"{base_url}?{query_string}"

print(final_url)

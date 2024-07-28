#!/bin/bash

# 定义颜色变量
huang='\033[1;33m'
bai='\033[0m'
lv='\033[0;32m'
lan='\033[0;34m'
hong='\033[31m'
zi='\033[1;35m'
hui='\e[37m'

# 检查是否以 sudo 运行
if [[ $EUID -ne 0 ]]; then
   echo -e "${hong}请使用 sudo 运行此脚本${bai}"
   exit 1
fi

# 定义提示信息数组
messages=()

# 获取用户主目录的完整路径
USER_HOME=$(eval echo ~$SUDO_USER)

mkdir -p $USER_HOME/.t/script_tools
cd $USER_HOME/.t/script_tools

curl -sS -O https://raw.githubusercontent.com/kejilion/sh/main/auto_cert_renewal.sh
chmod +x auto_cert_renewal.sh

# 打印脚本完整路径
messages+=("${lv}certbot证书申请脚本已创建:${bai} $USER_HOME/.t/script_tools/auto_cert_renewal.sh")
messages+=("${huang}auto_cert_renewal.sh脚本需自行编辑后再使用,建议加入定时任务${bai}")
messages+=("=============================================")

mkdir -p $USER_HOME/.t/nginx_docker/html $USER_HOME/.t/nginx_docker/certs $USER_HOME/.t/nginx_docker/conf.d $USER_HOME/.t/nginx_docker/log/nginx
touch $USER_HOME/.t/nginx_docker/docker-compose.yml

# 下载 Nginx 配置文件
messages+=("${zi}Nginx 默认文件已成功部署！${bai}")
if wget -O $USER_HOME/.t/nginx_docker/nginx.conf https://raw.githubusercontent.com/Crpto999/RawFileHub_Adiren/main/Nginx_docker/nginx.conf; then
    messages+=("${lv}      主配置文件：${bai} $USER_HOME/.t/nginx_docker/nginx.conf")
else
    messages+=("${hong}      主配置文件下载失败！${bai}")
fi

if wget -O $USER_HOME/.t/nginx_docker/conf.d/debug.conf https://raw.githubusercontent.com/Crpto999/RawFileHub_Adiren/main/Nginx_docker/conf.d/default.conf; then
    messages+=("${lv}      默认站点配置文件：${bai} $USER_HOME/.t/nginx_docker/conf.d/default.conf")
else
    messages+=("${hong}      默认站点配置文件下载失败！${bai}")
fi

if wget -O $USER_HOME/.t/nginx_docker/html/404.html https://raw.githubusercontent.com/Crpto999/RawFileHub_Adiren/main/Nginx_docker/html/404.html; then
    messages+=("${lv}      404.html：${bai} $USER_HOME/.t/nginx_docker/html/404.html")
else
    messages+=("${hong}      404.html文件下载失败！${bai}")
fi


if wget -O $USER_HOME/.t/nginx_docker/html/index10443.html https://raw.githubusercontent.com/Crpto999/RawFileHub_Adiren/main/Nginx_docker/html/index10443.html; then
    messages+=("${lv}      index10443.html：${bai} $USER_HOME/.t/nginx_docker/html/index10443.html")
else
    messages+=("${hong}      index10443.html文件下载失败！${bai}")
fi

if wget -O $USER_HOME/.t/nginx_docker/html/index1080.html https://raw.githubusercontent.com/Crpto999/RawFileHub_Adiren/main/Nginx_docker/html/index1080.html; then
    messages+=("${lv}      index1080.html文件：${bai} $USER_HOME/.t/nginx_docker/html/index1080.html")
else
    messages+=("${hong}      index1080.html文件下载失败！${bai}")
fi
# 检查并安装 openssl
if ! command -v openssl &> /dev/null; then
    if command -v apt &> /dev/null; then
        apt update && apt install -y openssl
    elif command -v dnf &> /dev/null; then
        dnf install -y openssl
    elif command -v yum &> /dev/null; then
        yum install -y openssl
    else
        messages+=("${hong}不支持的包管理器。请手动安装 openssl。${bai}")
        exit 1
    fi
    messages+=("${lv}openssl 已成功安装${bai}")
fi

CERTS_DIR="$USER_HOME/.t/nginx_docker/certs"

# 生成自签名证书
openssl req -x509 -nodes -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -keyout "$CERTS_DIR/default_server.key" -out "$CERTS_DIR/default_server.crt" -days 5475 -subj "/C=JP/ST=Tokyo/L=Tokyo/O=喜顺有限公司/OU=AthenaX/CN=Adrien"

messages+=("${lv}自签名证书已生成并存储在${huang} $CERTS_DIR ${lv}目录中${bai}")

# 获取宿主机的 IP 地址
HOST_IP=$(hostname -I | awk '{print $1}')

# 提示用户后端 FastAPI 端口
messages+=("${hong}请确保 AthenaX_API 地址为：${lan}$HOST_IP:7777${bai}")

docker run -d --name nginx --restart always -p 1080:80 -p 10443:443 -p 10443:443/udp \
  -v $USER_HOME/.t/nginx_docker/nginx.conf:/etc/nginx/nginx.conf \
  -v $USER_HOME/.t/nginx_docker/conf.d:/etc/nginx/conf.d \
  -v $USER_HOME/.t/nginx_docker/certs:/etc/nginx/certs \
  -v $USER_HOME/.t/nginx_docker/html:/var/www/html \
  -v $USER_HOME/.t/nginx_docker/log/nginx:/var/log/nginx \
  -e TZ=Asia/Shanghai \
  -e ATHENAX_API=$HOST_IP \
  nginx:alpine

# 获取 Nginx 版本
nginx_version=$(docker exec nginx nginx -v 2>&1)
nginx_version=$(echo "$nginx_version" | grep -oP "nginx/\K[0-9]+\.[0-9]+\.[0-9]+")
messages+=("${lv}nginx已安装完成并启动${bai}")
messages+=("当前版本: ${huang}v$nginx_version${bai}")

# 清除终端屏幕
clear

# 统一输出所有提示信息
for msg in "${messages[@]}"; do
    echo -e "$msg"
done

echo ""

#!/bin/bash

# 定义颜色变量（加粗）
huang='\033[1;33m'
bai='\033[0m'
lv='\033[0;32m'
lan='\033[0;34m'
hong='\033[31m'
zi='\033[1;35m'
hui='\033[1;37m'

# 获取脚本所在目录
SCRIPT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
USER_HOME=$(eval echo ~$SUDO_USER)
CERTS_DIR="$USER_HOME/.t/nginx_docker/certs"

# 检查并安装所需的软件包
install_package() {
    package=$1
    if command -v $package &> /dev/null; then
        echo -e "${huang}$package 已就绪${bai}"
    else
        if command -v apt &> /dev/null; then
            apt update && apt install -y $package && echo -e "${lv}$package 已部署${bai}"
        elif command -v dnf &> /dev/null; then
            dnf install -y $package && echo -e "${lv}$package 已部署${bai}"
        elif command -v yum &> /dev/null; then
            yum install -y $package && echo -e "${lv}$package 已部署${bai}"
        else
            echo -e "${hong}不支持的包管理器。请手动安装 $package。${bai}"
            exit 1
        fi
    fi
}

# 等待用户按任意键继续
any_key_back() {
    echo "按任意键继续..."
    read -n 1 -s -r -p ""
    echo ""
    clear
}

# 检查是否具有 root 权限
root_use() {
    clear
    [ "$EUID" -ne 0 ] && echo -e "${huang}提示: ${bai}该功能需要root用户才能运行！" && any_key_back && start_menu
}

# 主菜单函数
start_menu() {
    clear
    echo -e "${huang}==================================================${bai}"
    echo -e "${lan}AthenaX 部署工具${bai}"
    echo -e "${huang}==================================================${bai}"
    echo -e "${lv}1. 南墙Web应用防火墙 ▶${bai}"
    echo -e "${lv}2. Nginx ▶${bai}"
    echo -e ""
    echo -e "${lv}0. 退出${bai}"
    echo
    read -p "请输入: " num
    case "$num" in
        1)
            install_waf
            ;;
        2)
            check_waf_and_deploy_nginx_menu
            ;;
        0)
            exit 0
            ;;
        *)
            start_menu
            ;;
    esac
}

# 安装南墙Web应用防火墙函数
install_waf() {
    root_use
    cd $SCRIPT_PATH
    curl https://waf.uusec.com/waf.tgz -o waf.tgz && tar -zxf waf.tgz && rm waf.tgz && sudo bash ./waf/uuwaf.sh
    any_key_back
    start_menu
}

# 部署 Nginx 函数
deploy_nginx() {
    root_use
    messages=()

    # 创建所需目录
    mkdir -p $USER_HOME/.t/nginx_docker/html
    mkdir -p $USER_HOME/.t/nginx_docker/certs
    mkdir -p $USER_HOME/.t/nginx_docker/conf.d
    mkdir -p $USER_HOME/.t/nginx_docker/log/nginx
    touch $USER_HOME/.t/nginx_docker/docker-compose.yml

    # 下载 Nginx 配置文件
    download_file() {
        local url=$1
        local destination=$2
        local description=$3
        if wget -O $destination $url; then
            messages+=("${lv}${description}：${bai} $destination")
        else
            messages+=("${hong}${description}下载失败！${bai}")
        fi
    }

    download_file "https://raw.githubusercontent.com/Crpto999/RawFileHub_Adiren/main/Nginx_docker/nginx.conf" "$USER_HOME/.t/nginx_docker/nginx.conf" "主配置文件"
    download_file "https://raw.githubusercontent.com/Crpto999/RawFileHub_Adiren/main/Nginx_docker/conf.d/default.conf" "$USER_HOME/.t/nginx_docker/conf.d/default.conf.template" "默认站点配置文件"
    download_file "https://raw.githubusercontent.com/Crpto999/RawFileHub_Adiren/main/Nginx_docker/html/404.html" "$USER_HOME/.t/nginx_docker/html/404.html" "404.html文件"
    download_file "https://raw.githubusercontent.com/Crpto999/RawFileHub_Adiren/main/Nginx_docker/html/index10443.html" "$USER_HOME/.t/nginx_docker/html/index10443.html" "index10443.html文件"
    download_file "https://raw.githubusercontent.com/Crpto999/RawFileHub_Adiren/main/Nginx_docker/html/index1080.html" "$USER_HOME/.t/nginx_docker/html/index1080.html" "index1080.html文件"

    # 检查并安装 openssl
    install_package "openssl"

    # 生成自签名证书
    openssl req -x509 -nodes -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -keyout "$CERTS_DIR/default_server.key" -out "$CERTS_DIR/default_server.crt" -days 5475 -subj "/C=JP/ST=Tokyo/L=Tokyo/O=Xishun.co../OU=AthenaX/CN=Adrien"
    messages+=("${lv}自签名证书已生成并存储在${huang} $CERTS_DIR ${lv}目录中${bai}")
    # 删除旧的镜像文件
    docker rmi nginx nginx:alpine >/dev/null 2>&1
    messages+=("")
    messages+=("===================================================")

    if [[ "$(docker ps -a --filter "name=uuwaf" --format '{{.Names}}')" == "uuwaf" ]]; then
        docker run -d --name nginx --network wafnet --restart always -p 1080:80 -p 10443:443 -p 10443:443/udp \
          -v $USER_HOME/.t/nginx_docker/nginx.conf:/etc/nginx/nginx.conf \
          -v $USER_HOME/.t/nginx_docker/conf.d:/etc/nginx/templates/ \
          -v $USER_HOME/.t/nginx_docker/certs:/etc/nginx/certs \
          -v $USER_HOME/.t/nginx_docker/html:/var/www/html \
          -v $USER_HOME/.t/nginx_docker/log/nginx:/var/log/nginx \
          -e TZ=Asia/Shanghai \
          -e ATHENAX_API=$HOST_IP \
          nginx:alpine
    else
        docker run -d --name nginx --restart always -p 1080:80 -p 10443:443 -p 10443:443/udp \
          -v $USER_HOME/.t/nginx_docker/nginx.conf:/etc/nginx/nginx.conf \
          -v $USER_HOME/.t/nginx_docker/conf.d:/etc/nginx/templates/ \
          -v $USER_HOME/.t/nginx_docker/certs:/etc/nginx/certs \
          -v $USER_HOME/.t/nginx_docker/html:/var/www/html \
          -v $USER_HOME/.t/nginx_docker/log/nginx:/var/log/nginx \
          -e TZ=Asia/Shanghai \
          -e ATHENAX_API=$HOST_IP \
          nginx:alpine
    fi

    nginx_version=$(docker exec nginx nginx -v 2>&1 | grep -oP "nginx/\K[0-9]+\.[0-9]+\.[0-9]+")
    messages+=("${lv}nginx已安装完成并启动${bai}")
    messages+=("当前版本: ${huang}v$nginx_version${bai}")

    HOST_IP=$(curl -s ifconfig.me)

    messages+=("")
    messages+=("${hong}请打开10443和1080端口 查看测试页面：${bai}")
    messages+=("${lan}https://$HOST_IP:10443")
    messages+=("${lan}http://$HOST_IP:1080")
    messages+=("${lan}http://$HOST_IP:1080/wrong_page")
    messages+=("===================================================")
    clear
    for msg in "${messages[@]}"; do
        echo -e "$msg"
    done

    echo ""
    any_key_back
    start_menu
}

# 检查 WAF 并选择部署 Nginx 的方法
check_waf_and_deploy_nginx_menu() {
    if [[ "$(docker ps -a --filter "name=uuwaf" --format '{{.Names}}')" != "uuwaf" ]]; then
        clear
        echo -e "${huang}=========================${bai}"
        echo -e "${hong}未检测到 【南墙 WEB 应用防火墙】${bai}"
        echo -e "${huang}=========================${bai}"
        echo -e "${lv}1. 安装南墙Web应用防火墙${bai}"
        echo -e "${lv}2. 直接安装Nginx${bai}"
        echo -e ""
        echo -e "${lv}0. 返回上级${bai}"
        echo
        read -p "请输入: " num
        case "$num" in
            1)
                install_waf
                ;;
            2)
                deploy_nginx
                ;;
            0)
                start_menu
                ;;
            *)
                check_waf_and_deploy_nginx_menu
                ;;
        esac
    else
        clear
        echo -e "${huang}=========================${bai}"
        echo -e "${hong}已安装 【南墙 WEB 应用防火墙】${bai}"
        echo -e "${huang}=========================${bai}"
        echo -e "${lv}1. 安装Nginx${bai}"
        echo -e "${lv}2. 证书管理${bai}"
        echo -e ""
        echo -e "${lv}0. 返回上级${bai}"
        echo
        read -p "请输入: " num
        case "$num" in
            1)
                deploy_nginx
                ;;
            2)
                show_certbot_menu
                ;;
            0)
                start_menu
                ;;
            *)
                check_waf_and_deploy_nginx_menu
                ;;
        esac
    fi
}

# certbot证书管理菜单函数
show_certbot_menu() {
    clear
    echo -e "${huang}=========================${bai}"
    echo -e "${lan}HTTPS证书管理${bai}"
    install_package "openssl"
    echo -e "${huang}=========================${bai}"
    echo -e "${lv}1. 申请自签证书${bai}"
    echo -e "${lv}2. 查看证书${bai}"
    echo -e ""
    echo -e "${lv}0. 返回上级${bai}"
    echo
    read -p "请输入: " num
    case "$num" in
        1)
            request_self_signed_cert
            ;;
        2)
            list_certificates
            ;;
        0)
            check_waf_and_deploy_nginx_menu
            ;;
        *)
            show_certbot_menu
            ;;
    esac
}

request_self_signed_cert() {
    root_use

    echo -e "${lv}生成自签名证书。输入 Q 退出。${bai}"

    while :; do
        echo -e "${huang}请输入证书名称：${bai}"
        read cert_name
        if [ "$cert_name" = "Q" ]; then
            show_certbot_menu
            return
        elif [ -n "$cert_name" ]; then
            break
        else
            echo -e "${hong}证书名称不能为空，请重新输入。${bai}"
        fi
    done

    echo -e "${huang}请输入国家代码（默认：JP）：${bai}"
    read country_code
    if [ "$country_code" = "Q" ]; then
        show_certbot_menu
        return
    elif [ -z "$country_code" ]; then
        country_code="JP"
        echo -e "${zi}使用默认：$country_code ${bai}"
    fi

    echo -e "${huang}请输入省份（默认：Tokyo）：${bai}"
    read state
    if [ "$state" = "Q" ]; then
        show_certbot_menu
        return
    elif [ -z "$state" ]; then
        state="Tokyo"
        echo -e "${zi}使用默认：$state ${bai}"
    fi

    echo -e "${huang}请输入城市（默认：Tokyo）：${bai}"
    read city
    if [ "$city" = "Q" ]; then
        show_certbot_menu
        return
    elif [ -z "$city" ]; then
        city="Tokyo"
        echo -e "${zi}使用默认：$city ${bai}"
    fi

    echo -e "${huang}请输入组织名称（默认：Xishun.co..）：${bai}"
    read organization
    if [ "$organization" = "Q" ]; then
        show_certbot_menu
        return
    elif [ -z "$organization" ]; then
        organization="Xishun.co.."
        echo -e "${zi}使用默认：$organization ${bai}"
    fi

    echo -e "${huang}请输入组织单位名称（默认：AthenaX）：${bai}"
    read organizational_unit
    if [ "$organizational_unit" = "Q" ]; then
        show_certbot_menu
        return
    elif [ -z "$organizational_unit" ]; then
        organizational_unit="AthenaX"
        echo -e "${zi}使用默认：$organizational_unit ${bai}"
    fi

    echo -e "${huang}请输入常用名（默认：Adrien）：${bai}"
    read common_name
    if [ "$common_name" = "Q" ]; then
        show_certbot_menu
        return
    elif [ -z "$common_name" ]; then
        common_name="Adrien"
        echo -e "${zi}使用默认：$common_name ${bai}"
    fi

    CERTS_DIR="$USER_HOME/.t/nginx_docker/certs"
    mkdir -p "$CERTS_DIR"
    openssl req -x509 -nodes -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -keyout "$CERTS_DIR/${cert_name}.key" -out "$CERTS_DIR/${cert_name}.crt" -days 5475 -subj "/C=$country_code/ST=$state/L=$city/O=$organization/OU=$organizational_unit/CN=$common_name"

    if [ -f "$CERTS_DIR/${cert_name}.crt" ] && [ -f "$CERTS_DIR/${cert_name}.key" ]; then
        echo -e "${lv}证书已生成: ${huang} ${CERTS_DIR}/${cert_name}.crt "
        echo -e "${lv}密钥已生成: ${huang} ${CERTS_DIR}/${cert_name}.key "
    else
        echo -e "${hong}证书生成失败，请检查 openssl 命令输出。${bai}"
    fi

    any_key_back
    show_certbot_menu
}


# 解析并显示证书信息函数
display_certificate_info() {
    cert_file=$1
    crt_file="${cert_file%.key}.crt"
    echo "=========================================================="
    echo -e "${huang}证书文件名:${bai} $cert_file"
    echo ""

    # 获取签名算法
    signature_algorithm=$(openssl x509 -in "$crt_file" -noout -text | grep "Signature Algorithm" | head -1 | awk -F: '{print $2}' | xargs)
    echo -e "${huang}签名算法:${bai} $signature_algorithm"
    echo ""
    # 获取主体信息
    subject=$(openssl x509 -in "$crt_file" -noout -subject -nameopt RFC2253 | sed 's/subject= //')


    country=$(echo "$subject" | grep -oP '(?<=C=)[^,]*')
    state=$(echo "$subject" | grep -oP '(?<=ST=)[^,]*')
    organization=$(echo "$subject" | grep -oP '(?<=O=)[^,]*')
    organizational_unit=$(echo "$subject" | grep -oP '(?<=OU=)[^,]*')
    common_name=$(echo "$subject" | grep -oP '(?<=CN=)[^,]*')

    echo -e "${huang}地区:${bai} ${country:-无}.${state:-无}"
    echo -e "${huang}组织:${bai} ${organization:-无}"
    echo -e "${huang}项目:${bai} ${organizational_unit:-无}"
    echo -e "${huang}常用名:${bai} ${common_name:-无}"
    echo ""

    # 获取有效期信息
    not_before=$(openssl x509 -in "$crt_file" -noout -startdate | cut -d= -f2)
    not_after=$(openssl x509 -in "$crt_file" -noout -enddate | cut -d= -f2)

    not_before_formatted=$(date -d "$not_before" +"%Y-%m-%d %H:%M:%S")
    not_after_formatted=$(date -d "$not_after" +"%Y-%m-%d %H:%M:%S")

    echo -e "${huang}注册时间:${bai} $not_before_formatted"
    echo -e "${huang}到期时间:${bai} $not_after_formatted"
    echo ""

    # 获取数字签名
    signature=$(openssl x509 -in "$crt_file" -noout -text | sed -n '/Signature Value/,/-----BEGIN/p' | sed '1d;$d')

    echo -e "${huang}数字签名:${bai}"
    echo "$signature"
    echo "=========================================================="
}

# 列出并查看证书函数
list_certificates() {
    clear
    CERTS_DIR="$USER_HOME/.t/nginx_docker/certs"
    cert_files=($(ls $CERTS_DIR/*.key))
    if [ ${#cert_files[@]} -eq 0 ]; then
        echo -e "${hong}未找到任何证书${bai}"
        show_certbot_menu
    fi
    echo -e "${huang}当前目录下的证书列表:${bai}"
    for i in "${!cert_files[@]}"; do
        cert_file=$(basename "${cert_files[$i]}")
        echo -e "${lv}$((i+1)). ${cert_file%.key}${bai}"
    done
    echo ""
    read -p "请输入要查看的证书编号: " cert_num
    if [[ "$cert_num" =~ ^[0-9]+$ ]] && [ "$cert_num" -gt 0 ] && [ "$cert_num" -le ${#cert_files[@]} ]; then
        cert_file="${cert_files[$((cert_num-1))]}"
        display_certificate_info "$cert_file"

        echo -e "${huang}输入D 删除证书，输入任意其他键继续...${bai}"
        read -n 1 -s -r -p "" user_action
        echo ""
        if [ "$user_action" == "D" ] || [ "$user_action" == "d" ]; then
            # shellcheck disable=SC1073
            read -p "$(echo -e "${hong}确认删除证书 ${cert_file%.key} 吗? (Y/N):${bai}")" confirm_delete

            if [ "$confirm_delete" == "Y" ] || [ "$confirm_delete" == "y" ]; then
                rm -f "$cert_file" "${cert_file%.key}.crt"
                echo -e "${lv}证书已删除${bai}"
            else
                echo -e "${lv}删除命令已取消${bai}"
            fi
        fi
    else
        echo -e "${hong}无效的编号${bai}"
    fi

    show_certbot_menu
}

# 运行主菜单
start_menu

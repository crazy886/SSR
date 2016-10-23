#! /bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
#=================================================================#
#   系统要求:  CentOS 6,7, Debian, Ubuntu                         #
#   描述: 一键安装 ShadowsocksR 服务器                            #
#   作者: DengXizhen                                              #
#   联系方式： 1613049323@qq.com                                  #
#=================================================================#
clear
yum -y install git
echo -e "\033[34m================================================================\033[0m

                欢迎使用 Shadowsocks-R 一键脚本

            系统要求:  CentOS 6,7, Debian, Ubuntu
            描述: 一键安装 ShadowsocksR 服务器
            作者: DengXizhen
            联系方式： 1613049323@qq.com

\033[34m================================================================\033[0m";

echo
echo "脚本支持CentOS 6,7, Debian, Ubuntu系统(如遇到卡住，请耐心等待5-7分钟)"
echo

#Current folder
cur_dir=`pwd`
# Get public IP address
IP=$(ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1)
if [[ "$IP" = "" ]]; then
    IP=$(wget -qO- -t1 -T2 ipv4.icanhazip.com)
fi

# Make sure only root can run our script
function rootness(){
    if [[ $EUID -ne 0 ]]; then
        echo -e "\033[31m 错误：本脚本必须以root用户执行！\033[0m" 1>&2
        exit 1
    fi
}

# Check OS
function checkos(){
    if [ -f /etc/redhat-release ];then
        OS='CentOS'
    elif [ ! -z "`cat /etc/issue | grep bian`" ];then
        OS='Debian'
    elif [ ! -z "`cat /etc/issue | grep Ubuntu`" ];then
        OS='Ubuntu'
    else
        echo -e "\033[31m 不支持该操作系统，请重新安装并重试！\033[0m"
        exit 1
    fi
}

# Get version
function getversion(){
    if [[ -s /etc/redhat-release ]];then
        grep -oE  "[0-9.]+" /etc/redhat-release
    else
        grep -oE  "[0-9.]+" /etc/issue
    fi
}

# CentOS version
function centosversion(){
    local code=$1
    local version="`getversion`"
    local main_ver=${version%%.*}
    if [ $main_ver == $code ];then
        return 0
    else
        return 1
    fi
}

# Disable selinux
function disable_selinux(){
    if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
}

# Pre-installation settings
function pre_install(){
    # Not support CentOS 5
    if centosversion 5; then
        echo -e "\033[31m 不支持 CentOS 5, 请更新操作系统至 CentOS 6+/Debian 7+/Ubuntu 12+ 并重试。\033[0m"
        exit 1
    fi
    # Set ShadowsocksR config password
    echo "请输入SSR连接密码:"
    read -p "(默认密码: 123456):" shadowsockspwd
    [ -z "$shadowsockspwd" ] && shadowsockspwd="123456"
    echo
    echo "---------------------------"
    echo "成功设置密码 = $shadowsockspwd"
    echo "---------------------------"
    echo
    # Set ShadowsocksR config port
    while true
    do
        echo -e "请输入SSR连接端口,不设置将默认138端口:"
        read -p "(默认自动设置SS免流端口为138):" shadowsocksport
        [ -z "$shadowsocksport" ] && shadowsocksport="138"
        expr $shadowsocksport + 0 &>/dev/null
        if [ $? -eq 0 ]; then
            if [ $shadowsocksport -ge 1 ] && [ $shadowsocksport -le 65535 ]; then
                echo
                echo "---------------------------"
                echo "成功设置SSR端口 = $shadowsocksport"
                echo "---------------------------"
                echo
                break
            else
                echo -e "\033[31m 输入错误，请输入1-65535之间的数字！\033[0m"
            fi
        else
            echo -e "\033[31m 你看不懂人话吗！\033[0m"
        fi
    done
    get_char(){
        SAVEDSTTY=`stty -g`
        stty -echo
        stty cbreak
        dd if=/dev/tty bs=1 count=1 2> /dev/null
        stty -raw
        stty echo
        stty $SAVEDSTTY
    }
    echo
    echo "请回车继续安装，或者Ctrl+C 停止安装。"
    char=`get_char`
    # Install necessary dependencies
    if [ "$OS" == 'CentOS' ]; then
        yum install -y wget unzip openssl-devel gcc swig python python-devel python-setuptools autoconf libtool libevent git ntpdate busybox
        yum install -y m2crypto automake make curl curl-devel zlib-devel perl perl-devel cpio expat-devel gettext-devel
    else
        apt-get -y update
        apt-get -y install python python-dev python-pip python-m2crypto curl wget unzip gcc swig automake make perl cpio build-essential git ntpdate busybox
    fi
    cd $cur_dir
}

# Download files
function download_files(){
    #Download libsodium file
    if ! wget --no-check-certificate -O libsodium-1.0.10.tar.gz https://github.com/crazy886/SSR/releases/download/libsodium1.0.10/libsodium-1.0.10.tar.gz; then
        echo -e "\033[31m 下载 libsodium 文件失败！\033[0m"
        exit 1
    fi
    # Download ShadowsocksR file
    # if ! wget --no-check-certificate -O manyuser.zip https://github.com/crazy886/SSR/releases/download/libsodium1.0.10/shadowsocks-manyuser.zip; then
        # echo "Failed to download ShadowsocksR file!"
        # exit 1
    # fi
    # Download ShadowsocksR chkconfig file
    if [ "$OS" == 'CentOS' ]; then
        if ! wget --no-check-certificate https://github.com/crazy886/SSR/releases/download/libsodium1.0.10/ShadowsocksR -O /etc/init.d/shadowsocks; then
            echo -e "\033[31m 下载 ShadowsocksR 文件失败！\033[0m"
            exit 1
        fi
    else
        if ! wget --no-check-certificate https://github.com/crazy886/SSR/releases/download/libsodium1.0.10/ShadowsocksR-debian -O /etc/init.d/shadowsocks; then
            echo -e "\033[31m 下载 ShadowsocksR-debian 文件失败！\033[0m"
            exit 1
        fi
    fi
}

# firewall set
function firewall_set(){
    echo "正在设置防火墙..."
    if centosversion 6; then
        /etc/init.d/iptables status > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            iptables -L -n | grep '${shadowsocksport}' | grep 'ACCEPT' > /dev/null 2>&1
            if [ $? -ne 0 ]; then
                iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport ${shadowsocksport} -j ACCEPT
                iptables -I INPUT -m state --state NEW -m udp -p udp --dport ${shadowsocksport} -j ACCEPT
                /etc/init.d/iptables save
                /etc/init.d/iptables restart
            else
                echo "端口 ${shadowsocksport} 已设置。"
            fi
        else
            echo -e "\033[31m 警告：iptables 看起来好像已关闭或未安装，如果必要的话请手动设置它。\033[0m"
        fi
    elif centosversion 7; then
        systemctl status firewalld > /dev/null 2>&1
        if [ $? -eq 0 ];then
            firewall-cmd --permanent --zone=public --add-port=${shadowsocksport}/tcp
            firewall-cmd --permanent --zone=public --add-port=${shadowsocksport}/udp
            firewall-cmd --reload
        else
            echo "Firewalld 看起来好像未运行，正在启动..."
            systemctl start firewalld
            if [ $? -eq 0 ];then
                firewall-cmd --permanent --zone=public --add-port=${shadowsocksport}/tcp
                firewall-cmd --permanent --zone=public --add-port=${shadowsocksport}/udp
                firewall-cmd --reload
            else
                echo -e "\033[31m 警告：启动 firewalld 失败。如果必要的话请手动确保端口${shadowsocksport}能使用。\033[0m"
            fi
        fi
    fi
    echo "firewall 设置完毕..."
}

# Config ShadowsocksR
function config_shadowsocks(){
    cat > /etc/shadowsocks.json<<-EOF
{
    "server": "0.0.0.0",
    "server_ipv6": "[::]",
    "server_port": ${shadowsocksport},
    "local_address": "127.0.0.1",
    "local_port": 1080,
    "password": "${shadowsockspwd}",
    "timeout": 120,
    "udp_timeout": 60,
    "method": "chacha20",
    "protocol": "auth_sha1_compatible",
    "protocol_param": "",
    "obfs": "http_simple_compatible",
    "obfs_param": "",
    "dns_ipv6": false,
    "connect_verbose_info": 0,
    "redirect": "",
    "fast_open": false,
    "workers": 1

}
EOF
}

# Install ShadowsocksR
function install_ss(){
    # Install libsodium
    tar zxf libsodium-1.0.10.tar.gz
    cd $cur_dir/libsodium-1.0.10
    ./configure && make && make install
    echo "/usr/local/lib" > /etc/ld.so.conf.d/local.conf
    ldconfig
    # Install ShadowsocksR
    cd $cur_dir
    # unzip -q manyuser.zip
    # mv shadowsocks-manyuser/shadowsocks /usr/local/
    git clone -b manyuser https://github.com/crazy886/shadowsocks.git /usr/local/shadowsocks
    if [ -f /usr/local/shadowsocks/server.py ]; then
        chmod +x /etc/init.d/shadowsocks
        # Add run on system start up
        if [ "$OS" == 'CentOS' ]; then
            chkconfig --add shadowsocks
            chkconfig shadowsocks on
        else
            update-rc.d -f shadowsocks defaults
        fi
        # Run ShadowsocksR in the background
        /etc/init.d/shadowsocks start
        clear
        echo
        echo "恭喜你，shadowsocksr安装完成！"
        echo -e "服务器IP: \033[41;37m ${IP} \033[0m"
        echo -e "远程连接端口: \033[41;37m ${shadowsocksport} \033[0m"
        echo -e "远程连接密码: \033[41;37m ${shadowsockspwd} \033[0m"
        echo -e "本地监听IP: \033[41;37m 127.0.0.1 \033[0m"
        echo -e "本地监听端口: \033[41;37m 1080 \033[0m"
        echo -e "认证方式: \033[41;37m auth_sha1 \033[0m"
        echo -e "协议: \033[41;37m http_simple \033[0m"
        echo -e "加密方法: \033[41;37m chacha20 \033[0m"
        echo
        echo "如果你想改变认证方式和协议，请参考网址"
        echo "https://github.com/breakwa11/shadowsocks-rss/wiki/Server-Setup"
        echo
        echo "安装完毕！去享受这种愉悦感吧！"
        echo
    else
        echo -e "\033[31m Shadowsocks安装失败！\033[0m"
        install_cleanup
        exit 1
    fi
}

#改成北京时间
function check_datetime(){
    rm -rf /etc/localtime
    ln -s /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
    ntpdate 1.cn.pool.ntp.org
}

# Install cleanup
function install_cleanup(){
    cd $cur_dir
    rm -f manyuser.zip
    rm -rf shadowsocks-manyuser
    rm -f libsodium-1.0.10.tar.gz
    rm -rf libsodium-1.0.10
}

# Install Action
function install_action(){
    checkos
    rootness
    disable_selinux
    pre_install
    download_files
    config_shadowsocks
    install_ss
    if [ "$OS" == 'CentOS' ]; then
        firewall_set > /dev/null 2>&1
    fi
    check_datetime
    install_cleanup
}

# Uninstall Action
function uninstall_action(){
    /etc/init.d/shadowsocks status > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        /etc/init.d/shadowsocks stop
    fi
    checkos
    if [ "$OS" == 'CentOS' ]; then
        chkconfig --del shadowsocks
    else
        update-rc.d -f shadowsocks remove
    fi
    rm -f /etc/shadowsocks.json
    rm -f /etc/init.d/shadowsocks
    rm -rf /usr/local/shadowsocks
}

# Uninstall ShadowsocksR
function uninstall_shadowsocks(){
    printf "你确定卸载shadowsocksr？ (y/n) "
    printf "\n"
    read -p "(默认: n):" answer
    if [ -z $answer ]; then
        answer="n"
    fi
    if [ "$answer" = "y" ]; then
        uninstall_action
        echo "ShadowsocksR 卸载成功!"
    else
        echo "卸载取消..."
    fi
}

# Install ShadowsocksR
function install_shadowsocks(){
    if [ -e /usr/local/shadowsocks ]; then
        printf "ShadowsocksR已安装，是否重新安装？ (y/n) "
        printf "\n"
        read -p "(默认: n):" answer
        if [ -z $answer ]; then
            answer="n"
        fi
        if [ "$answer" = "y" ]; then
            #卸载
            uninstall_action
            #安装
            install_action
        else
            echo "已取消重新安装..."
        fi
    else
        install_action
    fi
}

function change_port(){
    if [ ! -e /usr/local/shadowsocks ]; then
        echo -e "\033[31m 尚未安装 ShadowsocksR！\033[0m"
    else
        a=1
        while [ $a -le 3 ]
        do
            echo "请输入SSR连接端口:"
            read shadowsocksport
            expr $shadowsocksport + 0 &>/dev/null
            if [ $? -eq 0 ] && [ $shadowsocksport -ge 1 ] && [ $shadowsocksport -le 65535 ]; then
                echo -e "当前新端口: \033[41;37m $shadowsocksport \033[0m"
                sed -i 's/"server_port": [0-9]*,/"server_port": '$shadowsocksport',/' /etc/shadowsocks.json
                if [ "$OS" == 'CentOS' ]; then
                    firewall_set > /dev/null 2>&1
                fi
                echo "正在重启ShadowsocksR..."
                /etc/init.d/shadowsocks restart &>/dev/null
                echo "当前ShadowsocksR状态："
                /etc/init.d/shadowsocks status
                exit
            else
                [ $a -lt 3 ] && echo -e "\033[31m 输入错误，请输入1-65535之间的数字！\033[0m" || echo -e "\033[31m 输入次数已达3次，操作结束！\033[0m"
            fi
            a=$((a+1))
        done
    fi
}

function change_password(){
    if [ ! -e /usr/local/shadowsocks ]; then
        echo -e "\033[31m 尚未安装 ShadowsocksR！\033[0m"
    else
        a=1
        while [ $a -le 3 ]
        do
            echo "请输入SSR连接密码:"
            read new_password
            if [ -z $new_password ]; then
                [ $a -lt 3 ] && echo -e "\033[31m 密码不能为空，请重新输入！\033[0m" || echo -e "\033[31m 输入次数已达3次，操作结束！\033[0m" 
            else
                echo -e "当前新密码: \033[41;37m $new_password \033[0m"
                sed -i 's/"password": .*,/"password": "'$new_password'",/' /etc/shadowsocks.json
                echo "正在重启ShadowsocksR..."
                /etc/init.d/shadowsocks restart &>/dev/null
                echo "当前ShadowsocksR状态："
                /etc/init.d/shadowsocks status
                exit
            fi
            a=$((a+1))
        done
    fi
}

# Initialization step
action=$1
[ -z $1 ] && action=install
case "$action" in
install)
    install_shadowsocks
    ;;
uninstall)
    uninstall_shadowsocks
    ;;
changeport)
    change_port
    ;;
changepassword)
    change_password
    ;;
*)
    echo "参数错误! [${action} ]"
    echo "Usage: `basename $0` {install|uninstall}"
    ;;
esac

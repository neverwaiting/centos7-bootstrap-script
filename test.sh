#!/bin/sh

BEGIN_TIME=$(date +%s)

# change by yourself
name="wintersun"
password="zdy.1234"
GIT_USER_NAME="wintersun"
GIT_USER_EMAIL="nerverstop@163.com"

TMP_DIR=/root/tmp

color_print()
{
  case $1 in 
    "info") printf "\e[39m%s\e[0m\n" "$2"; ;;
    "warn") printf "\e[33m%s\e[0m\n" "$2" ;;
    "error") printf "\e[31m%s\e[0m\n" "$2" ;;
    "success") printf "\e[92m%s\e[0m\n" "$2" ;;
    *) echo "unkonw level, exit"; exit ;;
  esac
}

error_exit()
{
  color_print "error" "$1 failed!" && exit 1
}

# function detect_exec_and_install
# purpose: yum install program
# arg1: detect_exec_name
# arg2: to_install_exec_name (can ignore)
detect_exec_and_install()
{
	if [ $# -lt 1 ]; then
		return
	fi

	detect_exec=$1
	if [ $# == 1 ]; then
		install_exec=$1
	else
		install_exec=$2
	fi

	if [ ! -x "$(command -v $detect_exec)" ]; then
		yum install -y $install_exec
	fi
}

# create a user
create_user()
{
  [ -x /bin/zsh ] || yum install -y zsh
  if [ ! -d "/home/$name" ]; then
    useradd -m -g wheel -s /bin/zsh "$name" > /dev/null 2>&1
    echo "$name:$password" | chpasswd
  fi
  echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/temp
  chsh -s /bin/zsh "$name" > /dev/null 2>&1
}

# set static ip address
set_static_ip_address()
{
  color_print "warn" "please input static ip address:"
  read address

  IP="192.168.235.10"
  [ -z "$address" ] || IP="$address"
  GATEWAY="192.168.235.2"
  NETMASK="255.255.255.0"
  DNS1="8.8.8.8"
  DNS2="144.144.144.144"
  IPV6_PRIVACY="no"
  NETWORK_CONFIG_FILE="/etc/sysconfig/network-scripts/ifcfg-ens33"

  sed -i -e 's/BOOTPROTO="dhcp"/BOOTPROTO="static"/' \
         -e "/^IPADDR/d" \
         -e "/^GATEWAY/d" \
         -e "/^NETMASK/d" \
         -e "/^DNS1/d" \
         -e "/^DNS2/d" \
         -e "/^IPV6_PRIVACY/d" $NETWORK_CONFIG_FILE

  cat << EOF >> "$NETWORK_CONFIG_FILE"
IPADDR="$IP"
GATEWAY="$GATEWAY"
NETMASK="$NETMASK"
DNS1="$DNS1"
DNS2="$DNS2"
IPV6_PRIVACY="$IPV6_PRIVACY"
EOF

  systemctl restart network
}

# change fd-max limit
maxfdlimit()
{
  if [ -z "$(sed -n '/fs.file-max/p' /etc/sysctl.conf)" ]; then
    echo -e "*\thard\tnofile\t1000000\n*\tsoft\tnofile\t1000000" >> /etc/security/limits.conf
    echo "fs.file-max=1000000" >> /etc/sysctl.conf
    sysctl -p
  fi
}

### change yum source
yum_source_change()
{
  ALIYUN_REPOS_CENTOS="http://mirrors.aliyun.com/repo/Centos-7.repo"
  ALIYUN_REPOS_EPEL="http://mirrors.aliyun.com/repo/epel-7.repo"
  REPOS_DIR="/etc/yum.repos.d"
  BACKUP_REPOS_DIR="$REPOS_DIR/repo-bak"
  if [ ! -d "$BACKUP_REPOS_DIR" ]; then
    mkdir -p $BACKUP_REPOS_DIR
    mv $REPOS_DIR/*.repo $BACKUP_REPOS_DIR
    yum clean all
    wget -O "$REPOS_DIR/CentOS-Base.repo" $ALIYUN_REPOS_CENTOS
    wget -O "$REPOS_DIR/epel.repo" $ALIYUN_REPOS_EPEL
    yum makecache -y
    yum update -y
  fi
}

### add github ipaddress to /etc/hosts
add_resolve_github()
{
  sed -i '/github.com$/d' /etc/hosts
  sed -i '/raw.githubusercontent.com$/d' /etc/hosts
  cat << EOF >> /etc/hosts
140.82.112.4    github.com
185.199.108.133 raw.githubusercontent.com
EOF
}

# add pip3 conf
set_pipconf()
{
  PIPCONF="/home/$name/.pip/pip.conf"
  if [ ! -f "PIPCONF" ]; then
    [ -d "/home/$name/.pip" ] || mkdir -p "/home/$name/.pip"
    cat << EOF >> "$PIPCONF"
[global]
index-url=http://pypi.douban.com/simple
[install]
use-mirrors=true
mirrors=http://pypi.douban.com/simple/
trusted-host=pypi.douban.com
EOF
    chown "$name:wheel" "$PIPCONF"
  fi
}

set_npmrc()
{
  NPMRC="/home/$name/.npmrc"
	echo "registry=https://registry.npm.taobao.org/" >> "$NPMRC"
	chown "$name:wheel" "$NPMRC"
}

# set gitconfig
set_gitconfig()
{
  git config --global init.defaultbranch "master"
  git config --global user.name $GIT_USER_NAME
  git config --global user.email $GIT_USER_EMAIL
}

### install neovim
nvim_install()
{
  [ -d "$TMP_DIR" ] || mkdir -p "$TMP_DIR"
  if [ ! -x "$(command -v nvim)" ]; then
    wget -O "$TMP_DIR/nvim-linux64.tar.gz" "$GITHUB_URL/neovim/neovim/releases/download/v0.8.0/nvim-linux64.tar.gz"
    tar -zxvf "$TMP_DIR/nvim-linux64.tar.gz" -C "$TMP_DIR"
    cp -r "$TMP_DIR/nvim-linux64/*" /usr/local/
    pip3 install neovim
    echo "alias vim='nvim'" >> /etc/profile
  fi
}

### install node-v16.17.0
node_install()
{
  [ -d "$TMP_DIR" ] || mkdir -p "$TMP_DIR"
  if [ ! -x "$(command -v node)" ]; then
    wget -O "$TMP_DIR/node-v16.17.0-linux-x64.tar.xz https://nodejs.org/dist/v16.17.0/node-v16.17.0-linux-x64.tar.xz"
    tar -xvf "$TMP_DIR/node-v16.17.0-linux-x64.tar.xz" -C "$TMP_DIR"
    cp -r "$TMP_DIR/node-v16.17.0-linux-x64/*" /usr/local/

  npm install yarn -g
  npm install neovim -g
  fi
}

### install devtoolset-8(gcc g++ gdb valgrind ...)
devtoolset8_install()
{
  if [ ! -x "$(command -v gcc)" ]; then
    yum install -y centos-release-scl
    yum install -y devtoolset-8
    source /opt/rh/devtoolset-8/enable
    echo -e "\nsource /opt/rh/devtoolset-8/enable" >> /etc/profile
    source /opt/rh/devtoolset-8/enable
  fi
}

### install cmake
cmake_install()
{
  if [ ! -x "$(command -v cmake)" ]; then
    wget -O $TMP_DIR/cmake-v3.23.3.tar.gz $GITHUB_URL/Kitware/CMake/archive/refs/tags/v3.23.3.tar.gz
    tar -zxvf $TMP_DIR/cmake-v3.23.3.tar.gz -C $TMP_DIR
    pushd $TMP_DIR/CMake-3.23.3
    ./configure && make -j$(nproc) && make install
    popd
  fi
}

# install zsh with oh-my-zsh and powerlevel10k theme
zsh_install()
{
  USER_HOME="/home/$name"
  MIRROR_RAW_GITHUB_URL="https://github.91chi.fun/https://raw.github.com"
  sudo -u "$name" curl -fsL "$MIRROR_RAW_GITHUB_URL/ohmyzsh/ohmyzsh/master/tools/install.sh" | \
  sed 's/https:\/\/github.com/https:\/\/github.91chi.fun\/https:\/\/github.com/g' > "$USER_HOME/omzinstall.sh"
  sudo -u "$name" sh "$USER_HOME/omzinstall.sh" --unattended && \
  sudo -u "$name" git clone --depth=1 "$GITHUB_URL/romkatv/powerlevel10k.git" "$USER_HOME/.oh-my-zsh/custom/themes/powerlevel10k"
  # TODO: cp .zshrc .p10k-zsh
}

color_print "success" "##################################################"
color_print "success" "##################################################"
color_print "success" "####### Welcome to Wintersun's bootstrap! ########"
color_print "success" "##################################################"
color_print "success" "##################################################"

# comment to disable github proxy
PROXY_GITHUB_URL="https://github.91chi.fun/https://github.com"
GITHUB_URL="https://github.com"
[ -z "$PROXY_GITHUB_URL" ] || GITHUB="$PROXY_GITHUB_URL"

color_print "warn" "Are you change your ip address? yes(y)/no(n)"
read is_change_ip_address
[ "$is_change_ip_address" == "n" ] || set_static_ip_address || error_exit "set static ip address"

maxfdlimit || error_exit "max fd limit"

detect_exec_and_install wget

color_print "warn" "Are you change yum source? yes(y)/no(n)"
read is_change_yum_source
[ "$is_change_yum_source" == "n" ] || yum_source_change || error_exit "change yum source"

# install openssl-devel zlib-devel curl-devel python3
yum install -y openssl-devel zlib-devel curl-devel autoconf boost-devel || error_exit "install some package with yum"

create_user || error_exit "create user"

### install git wget net-tools zip python3 ctags
detect_exec_and_install git
detect_exec_and_install ifconfig net-tools
detect_exec_and_install zip
detect_exec_and_install python3
detect_exec_and_install ctags

add_resolve_github
set_pipconf
set_npmrc
set_gitconfig

# disable firewalld service
systemctl stop firewalld

nvim_install || error_exit "install nvim"

node_install || error_exit "install node"

devtoolset8_install || error_exit "install devtoolset8" 

cmake_install || error_exit "install cmake "

# install zsh with oh-my-zsh and powerlevel10k theme
zsh_install || error_exit "install zsh"

[ ! -d "$TMP_DIR" ] || rm -rf $TMP_DIR

END_TIME=$(date +%s)
SPEND_TIME=`expr $END_TIME - $BEGIN_TIME`
if [ $SPEND_TIME -ge 60 ]; then
	SPEND_TIME_STRING=`expr $SPEND_TIME / 60` "m" `expr $SPEND_TIME % 60` "s"
else
	SPEND_TIME_STRING="$SPEND_TIME s"
fi

color_print "success" "##################################################"
color_print "success" "##################################################"
color_print "success" "install finished! spend $SPEND_TIME_STRING" 
color_print "success" "##################################################"
color_print "success" "##################################################"

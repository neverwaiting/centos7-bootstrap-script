#!/usr/bin/sh

echo "Welcome to Wintersun's bootstrap!"

if [ $(whoami) != "root" ]; then
	echo "Please make sure user is root!"
	exit 1
fi

BEGIN_TIME=$(date +%s)

### username passwd
USER_NAME="wintersun"
PASSWD="root"
if [ $USER_NAME != "root" -a -z "$(cat /etc/passwd | grep $USER_NAME)" ]; then
	useradd -d /home/$USER_NAME -m $USER_NAME
	echo $USER_NAME:$PASSWD | chpasswd
fi

### git config: username email
GIT_USER_NAME="wintersun"
GIT_USER_EMAIL="nerverstop@163.com"

### is enable proxy github website
ENABLE_PROXY=1
PROXY_GITHUB_URL="https://github.91chi.fun/https://github.com"
GITHUB_URL="https://github.com"
if test $ENABLE_PROXY -eq 0; then
	REAL_GITHUB_URL=$GITHUB_URL
else
	REAL_GITHUB_URL=$PROXY_GITHUB_URL
fi

### network config
IP="192.168.235.40"
GATEWAY="192.168.235.2"
DOMAIN="192.168.235.2"
NETMASK="255.255.255.0"
DNS1="8.8.8.8"
DNS2="144.144.144.144"
IPV6_PRIVACY="no"
NETWORK_CONFIG_FILE="/etc/sysconfig/network-scripts/ifcfg-ens33"

sed -i -e "s/BOOTPROTO='dhcp'/BOOTPROTO='static'/" \
       -e "/^IPADDR/d" \
       -e "/^GATEWAY/d" \
       -e "/^DOMAIN/d" \
       -e "/^NETMASK/d" \
       -e "/^DNS1/d" \
       -e "/^DNS2/d" \
       -e "/^IPV6_PRIVACY/d" $NETWORK_CONFIG_FILE

echo -e "IPADDR='$IP'\nGATEWAY='$GATEWAY'\nDOMAIN='$DOMAIN'\nNETMASK='$NETMASK'\nDNS1='$DNS1'\nDNS2='$DNS2'\nIPV6_PRIVACY='$IPV6_PRIVACY'" >> $NETWORK_CONFIG_FILE
systemctl restart network

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

### install wget
detect_exec_and_install wget

### change yum repo to aliyun repo
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

### add github ipaddress to /etc/hosts
sed -i '/github.com$/d' /etc/hosts
sed -i '/raw.githubusercontent.com$/d' /etc/hosts
echo -e "140.82.112.4\tgithub.com" >> /etc/hosts
echo -e "185.199.108.133\traw.githubusercontent.com" >> /etc/hosts

### install net-tools zip python3 ctags
detect_exec_and_install ifconfig net-tools
detect_exec_and_install zip
detect_exec_and_install python3
detect_exec_and_install ctags

### install git
if [ ! -x "$(command -v git)" ]; then
	yum install -y git
fi
git config --global user.name $GIT_USER_NAME
git config --global user.email $GIT_USER_EMAIL

### change to aliyun pip3 
if [ ! -f "/root/.pip/pip.conf" ]; then
	mkdir -p /root/.pip
	echo "[global]" >> /root/.pip/pip.conf
	echo "index-url=http://pypi.douban.com/simple" >> /root/.pip/pip.conf
	echo "[install]" >> /root/.pip/pip.conf
	echo "use-mirrors=true" >> /root/.pip/pip.conf
	echo "mirrors=http://pypi.douban.com/simple/" >> /root/.pip/pip.conf
	echo "trusted-host=pypi.douban.com" >> /root/.pip/pip.conf
	mkdir -p /home/$USER_NAME/.pip
	cp /root/.pip/pip.conf /home/$USER_NAME/.pip 
	chown -R $USER_NAME:$USER_NAME /home/$USER_NAME/.pip
fi

# install openssl-devel zlib-devel curl-devel python3
yum install -y openssl-devel zlib-devel curl-devel

### create third_party env directory
THIRD_ENV_DIR="/apps/$USER_NAME"
if [ ! -d "$THIRD_ENV_DIR" ]; then
	mkdir -p $THIRD_ENV_DIR
	mkdir -p $THIRD_ENV_DIR/bin
	mkdir -p $THIRD_ENV_DIR/include
	mkdir -p $THIRD_ENV_DIR/lib
	mkdir -p $THIRD_ENV_DIR/lib64
	mkdir -p $THIRD_ENV_DIR/share
fi

### add self path to env path
if [ -z "$(sed -n '/^export PATH=/p' /etc/profile)" ]; then
	echo -e "export PATH=$THIRD_ENV_DIR/bin:\$PATH" >> /etc/profile
	source /etc/profile
else
	if [ -z "$(sed -n '/^export PATH=/p' /etc/profile | grep "$THIRD_ENV_DIR/bin")" ]; then
		sed -i "s#export PATH=#export PATH=$THIRD_ENV_DIR/bin:#" /etc/profile
		source /etc/profile
	fi
fi

### create tmp directory
TMP_DIR=/root/tmp
if [ ! -d "$TMP_DIR" ]; then
	mkdir -p $TMP_DIR
fi

### install neovim
if [ ! -x "$(command -v nvim)" ]; then
	wget -O $TMP_DIR/nvim-linux64.tar.gz $REAL_GITHUB_URL/neovim/neovim/releases/download/v0.7.2/nvim-linux64.tar.gz
	tar -zxvf $TMP_DIR/nvim-linux64.tar.gz -C $TMP_DIR
	mv $TMP_DIR/nvim-linux64/bin/* $THIRD_ENV_DIR/bin
	mv $TMP_DIR/nvim-linux64/lib/* $THIRD_ENV_DIR/lib
	mv $TMP_DIR/nvim-linux64/share/* $THIRD_ENV_DIR/share
	
	mkdir -p /root/.config/nvim
	mkdir -p /home/$USER_NAME/.config/nvim
	git clone $REAL_GITHUB_URL/neverwaiting/vimrc.git
	cp vimrc/init.vim /root/.config/nvim/
	cp vimrc/coc-settings.json /root/.config/nvim/
	cp vimrc/init.vim /home/$USER_NAME/.config/nvim/
	cp vimrc/coc-settings.json /home/$USER_NAME/.config/nvim/
	chown -R $USER_NAME:$USER_NAME /home/$USER_NAME/.config
	rm -rf vimrc
	pip3 install neovim
	alias vim='nvim'

	echo "alias vim='nvim'" >> /etc/profile
fi

### install node-v16.17.0
if [ ! -x "$(command -v node)" ]; then
	wget -O $TMP_DIR/node-v16.17.0-linux-x64.tar.xz https://nodejs.org/dist/v16.17.0/node-v16.17.0-linux-x64.tar.xz
	tar -xvf $TMP_DIR/node-v16.17.0-linux-x64.tar.xz -C $TMP_DIR
	mv $TMP_DIR/node-v16.17.0-linux-x64/bin/* $THIRD_ENV_DIR/bin
	mv $TMP_DIR/node-v16.17.0-linux-x64/include/* $THIRD_ENV_DIR/include
	mv $TMP_DIR/node-v16.17.0-linux-x64/lib/* $THIRD_ENV_DIR/lib
	mv $TMP_DIR/node-v16.17.0-linux-x64/share/* $THIRD_ENV_DIR/share

	# change to aliyun npm repo
	echo "registry=https://registry.npm.taobao.org/" >> /root/.npmrc
	echo "coc.nvim:registry=https://registry.npm.taobao.org/" >> /root/.npmrc

	cp /root/.npmrc /home/$USER_NAME/.npmrc
	chown $USER_NAME:$USER_NAME /home/$USER_NAME/.npmrc

	npm install yarn -g
	npm install neovim -g
fi

### install devtoolset-8(gcc g++ gdb valgrind ...)
if [ ! -x "$(command -v gcc)" ]; then
	yum install -y centos-release-scl
	yum install -y devtoolset-8
	scl enable devtoolset-8 bash
	echo -e "\nscl enable devtoolset-8 bash" >> /etc/profile
fi

### install cmake
if [ ! -x "$(command -v cmake)" ]; then
	wget -O $TMP_DIR/cmake-v3.23.3.tar.gz $REAL_GITHUB_URL/Kitware/CMake/archive/refs/tags/v3.23.3.tar.gz
	tar -zxvf $TMP_DIR/cmake-v3.23.3.tar.gz -C $TMP_DIR
	pushd $TMP_DIR/CMake-3.23.3
	./configure --prefix=$THIRD_ENV_DIR && make -j$(nproc) && make install
	popd
fi

### install ccls
if [ ! -x "$(command -v ccls)" ]; then
	if [ -f "/etc/centos-release" -a \
		"$(cat /etc/centos-release)" == "CentOS Linux release 7.9.2009 (Core)" ]; then

		cp ccls $THIRD_ENV_DIR/bin/
		chmod a+x $THIRD_ENV_DIR/bin/ccls
	else
		if [ ! -x "$(command -v clang)" ]; then
			wget -O $TMP_DIR/llvmorg-11.0.0.tar.gz $REAL_GITHUB_URL/llvm/llvm-project/archive/refs/tags/llvmorg-11.0.0.tar.gz
			tar -zxvf $TMP_DIR/llvmorg-11.0.0.tar.gz -C $TMP_DIR
			mkdir -p $TMP_DIR/llvm-project-llvmorg-11.0.0/build
			pushd $TMP_DIR/llvm-project-llvmorg-11.0.0/build
			cmake -DLLVM_ENABLE_PROJECTS="clang;libcxx;libcxxabi" \
						-DCMAKE_BUILD_TYPE=Release \
						-DCMAKE_INSTALL_PREFIX=$THIRD_ENV_DIR ../llvm
			make -j$(nproc) && make install
			popd
		fi

		pushd $TMP_DIR
		git clone $REAL_GITHUB_URL/MaskRay/ccls
		pushd ccls
		sed -i "s#https://github.com#$REAL_GITHUB_URL#" .gitmodules
		git submodule update --init
		cmake -H. -BRelease \
					-DCMAKE_BUILD_TYPE=Release \
					-DCMAKE_PREFIX_PATH=$THIRD_ENV_DIR \
					-DCMAKE_INSTALL_PREFIX=$THIRD_ENV_DIR

		pushd Release && make -j$(nproc) && make install
		popd
		popd
		popd
	fi
fi

### remove tmp directory
if [ -d "$TMP_DIR" ]; then
	rm -rf $TMP_DIR
fi

END_TIME=$(date +%s)
SPEND_TIME=`expr $END_TIME - $BEGIN_TIME`
if [ $SPEND_TIME -ge 60 ]; then
	SPEND_TIME_STRING=`expr $SPEND_TIME / 60` "m" `expr $SPEND_TIME % 60` "s"
else
	SPEND_TIME_STRING="$SPEND_TIME s"
fi

echo "================================================"
echo "================================================"
echo "================================================"
echo -e "|| install finished! spend $SPEND_TIME_STRING ||" 
echo "================================================"
echo "================================================"
echo "================================================"

### install zsh and oh-my-zsh
if [ ! -x "$(command -v zsh)" ]; then
	yum install -y zsh && chsh -s /bin/zsh
	sh -c "$(curl -fsSL https://gitee.com/mirrors/oh-my-zsh/raw/master/tools/install.sh \
				| sed 's|^REPO=.*|REPO=${REPO:-mirrors/oh-my-zsh}|g' \
				| sed 's|^REMOTE=.*|REMOTE=${REMOTE:-https://gitee.com/${REPO}.git}|g')"
fi


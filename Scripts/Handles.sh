#!/bin/bash

PKG_PATH="$GITHUB_WORKSPACE/wrt/package/"

#预置HomeProxy数据
if [ -d *"homeproxy"* ]; then
	echo " "

	HP_RULE="surge"
	HP_PATH="homeproxy/root/etc/homeproxy"

	rm -rf ./$HP_PATH/resources/*

	git clone -q --depth=1 --single-branch --branch "release" "https://github.com/Loyalsoldier/surge-rules.git" ./$HP_RULE/
	cd ./$HP_RULE/ && RES_VER=$(git log -1 --pretty=format:'%s' | grep -o "[0-9]*")

	echo $RES_VER | tee china_ip4.ver china_ip6.ver china_list.ver gfw_list.ver
	awk -F, '/^IP-CIDR,/{print $2 > "china_ip4.txt"} /^IP-CIDR6,/{print $2 > "china_ip6.txt"}' cncidr.txt
	sed 's/^\.//g' direct.txt > china_list.txt ; sed 's/^\.//g' gfw.txt > gfw_list.txt
	mv -f ./{china_*,gfw_list}.{ver,txt} ../$HP_PATH/resources/

	cd .. && rm -rf ./$HP_RULE/

	cd $PKG_PATH && echo "homeproxy date has been updated!"
fi

# 预置OpenClash内核和数据
if [ -d *"OpenClash"* ]; then
# 	CORE_VER="https://raw.githubusercontent.com/vernesong/OpenClash/core/dev/core_version"
	CORE_TYPE=$(echo $WRT_CONFIG | grep -Eiq "64|86" && echo "amd64" || echo "arm64")
# 	CORE_TUN_VER=$(curl -sL $CORE_VER | sed -n "2{s/\r$//;p;q}")

	# 设置仓库信息
	OWNER="vernesong"
	REPO="mihomo"
	FILE_PATTERN="mihomo-linux-$CORE_TYPE-alpha-smart.*\\.gz"
	
	# 获取最新的预发布版本信息
	echo "正在获取最新预发布版本信息..."
	RELEASE_JSON=$(curl -s "https://api.github.com/repos/$OWNER/$REPO/releases?per_page=5")
	
	# 提取包含所需资源文件的最新预发布版本资源信息
	ASSET_URL=$(echo "$RELEASE_JSON" | jq -r --arg pattern "$FILE_PATTERN" \
	    '.[] | select(.prerelease == true) | .assets[] | select(.name | test($pattern)) | .browser_download_url' | head -n1)
	
	if [ -n "$ASSET_URL" ] && [ "$ASSET_URL" != "null" ]; then
	    echo "找到文件下载链接: $ASSET_URL"
	    FILENAME=$(basename "$ASSET_URL")
	    echo "文件名: $FILENAME"
	    
	    # 下载文件 (可根据需要取消以下注释)
	    # wget -O "/tmp/$FILENAME" "$ASSET_URL"
	    # echo "文件已下载到: /tmp/$FILENAME"
	else
	    echo "未找到匹配的预发布资源文件。"
	    echo "请确认: "
	    echo "  1. 项目 $OWNER/$REPO 是否存在包含 '$FILE_PATTERN' 文件的预发布版本。"
	    echo "  2. 或者尝试直接列出所有资源文件检查:"
	    echo "     curl -s 'https://api.github.com/repos/$OWNER/$REPO/releases?per_page=3' | jq -r '.[] | \"\\(.name):\", (.assets[] | \"  \\(.name)\")')'"
	fi

# 	CORE_DEV="https://github.com/vernesong/OpenClash/raw/core/dev/dev/clash-linux-$CORE_TYPE.tar.gz"
# 	CORE_MATE="https://github.com/vernesong/OpenClash/raw/core/dev/meta/clash-linux-$CORE_TYPE.tar.gz"
# 	CORE_TUN="https://github.com/vernesong/OpenClash/raw/core/dev/premium/clash-linux-$CORE_TYPE-$CORE_TUN_VER.gz"

# 	GEO_MMDB="https://github.com/alecthw/mmdb_china_ip_list/raw/release/lite/Country.mmdb"
# 	GEO_SITE="https://github.com/Loyalsoldier/v2ray-rules-dat/raw/release/geosite.dat"
# 	GEO_IP="https://github.com/Loyalsoldier/v2ray-rules-dat/raw/release/geoip.dat"

	cd ./OpenClash/luci-app-openclash/root/etc/openclash/
	curl -sL -o Model.bin https://github.com/vernesong/mihomo/releases/download/LightGBM-Model/Model.bin && echo "OpenClash smart Model.bin done!"
# 	curl -sL -o Country.mmdb $GEO_MMDB && echo "OpenClash Country.mmdb done!"
# 	curl -sL -o GeoSite.dat $GEO_SITE && echo "OpenClash GeoSite.dat done!"
# 	curl -sL -o GeoIP.dat $GEO_IP && echo "OpenClash GeoIP.dat done!"

	mkdir ./core/ && cd ./core/
	curl -sL -o $FILENAME $ASSET_URL && echo "OpenClash smart core done!"
# 	curl -sL -o meta.tar.gz $CORE_MATE && tar -zxf meta.tar.gz && mv -f clash clash_meta && echo "OpenClash meta done!"
# 	curl -sL -o tun.gz $CORE_TUN && gzip -d tun.gz && mv -f tun clash_tun && echo "OpenClash tun done!"
# 	curl -sL -o dev.tar.gz $CORE_DEV && tar -zxf dev.tar.gz && echo "OpenClash dev done!"

	chmod +x ./* && rm -rf ./*.gz

# 	cd $PKG_PATH && echo "OpenClash core and GEO data has been updated!"
fi

#修改argon主题字体和颜色
if [ -d *"luci-theme-argon"* ]; then
	echo " "

	cd ./luci-theme-argon/
	# 上传自己的 Argon 主题背景
	cp -f $GITHUB_WORKSPACE/pics/bg1.jpg ./htdocs/luci-static/argon/img/bg1.jpg
 	cd $PKG_PATH && echo "theme-argon background has been customized!"

 	cd ./luci-app-argon-config/
# 	sed -i '/font-weight:/ {/normal\|!important/! s/\(font-weight:\s*\)[^;]*;/\1normal;/}' $(find ./luci-theme-argon -type f -iname "*.css")
	sed -i "s/'0.5'/'0.3'/" ./root/etc/config/argon

	cd $PKG_PATH && echo "theme-argon-config has been customized!"
fi

#修改qca-nss-drv启动顺序
NSS_DRV="../feeds/nss_packages/qca-nss-drv/files/qca-nss-drv.init"
if [ -f "$NSS_DRV" ]; then
	echo " "

	sed -i 's/START=.*/START=85/g' $NSS_DRV

	cd $PKG_PATH && echo "qca-nss-drv has been fixed!"
fi

#修改qca-nss-pbuf启动顺序
NSS_PBUF="./kernel/mac80211/files/qca-nss-pbuf.init"
if [ -f "$NSS_PBUF" ]; then
	echo " "

	sed -i 's/START=.*/START=86/g' $NSS_PBUF

	cd $PKG_PATH && echo "qca-nss-pbuf has been fixed!"
fi

#修复TailScale配置文件冲突
TS_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/tailscale/Makefile")
if [ -f "$TS_FILE" ]; then
	echo " "

	sed -i '/\/files/d' $TS_FILE

	cd $PKG_PATH && echo "tailscale has been fixed!"
fi

#修复Rust编译失败Add commentMore actions
RUST_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/rust/Makefile")
if [ -f "$RUST_FILE" ]; then
	echo " "

	sed -i 's/ci-llvm=true/ci-llvm=false/g' $RUST_FILE

	cd $PKG_PATH && echo "rust has been fixed!"
fi
#修复DiskMan编译失败
DM_FILE="./luci-app-diskman/applications/luci-app-diskman/Makefile"
if [ -f "$DM_FILE" ]; then
	echo " "

	sed -i 's/fs-ntfs/fs-ntfs3/g' $DM_FILE
 	sed -i '/ntfs-3g-utils /d' $DM_FILE

	cd $PKG_PATH && echo "diskman has been fixed!"
fi

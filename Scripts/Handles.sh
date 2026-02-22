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

	cd $PKG_PATH && echo "✅ homeproxy date has been updated!"
fi

# 预置OpenClash smart内核和数据
if [ -d *"OpenClash"* ]; then
# 	CORE_VER="https://raw.githubusercontent.com/vernesong/OpenClash/core/dev/core_version"
	CORE_TYPE=$(echo $WRT_CONFIG | grep -Eiq "64|86" && echo "amd64" || echo "arm64")
# 	CORE_TUN_VER=$(curl -sL $CORE_VER | sed -n "2{s/\r$//;p;q}")

	# 设置仓库信息
	OWNER="vernesong"
	REPO="mihomo"
	FILE_PATTERN="mihomo-linux-$CORE_TYPE-alpha-smart.*\\.gz"
	
	# 获取最新的预发布的Smart核心版本信息
	echo "Retrieving the latest pre-release version information for OpenClash Smart Core..."
	RELEASE_JSON=$(curl -s "https://api.github.com/repos/$OWNER/$REPO/releases?per_page=5")
	
	# 提取包含所需资源文件的最新预发布版本资源信息
	ASSET_URL=$(echo "$RELEASE_JSON" | jq -r --arg pattern "$FILE_PATTERN" \
	    '.[] | select(.prerelease == true) | .assets[] | select(.name | test($pattern)) | .browser_download_url' | head -n1)
	
	if [ -n "$ASSET_URL" ] && [ "$ASSET_URL" != "null" ]; then
	    echo "✅ Find the Smart Core file download link: $ASSET_URL"
	    FILENAME=$(basename "$ASSET_URL")
	    echo "File Name: $FILENAME"
	    
	else
	    echo "No matching pre-release resource file found."
	    echo "Attempt to directly list all resource files for inspection:"
	    echo "     curl -s 'https://api.github.com/repos/$OWNER/$REPO/releases?per_page=3' | jq -r '.[] | \"\\(.name):\", (.assets[] | \"  \\(.name)\")')'"
		exit 0
	fi

	# 获取最新发布的Country.mmdb下载链接
	LATEST_MMDBURL=$(curl -s "https://api.github.com/repos/alecthw/mmdb_china_ip_list/releases/latest" | \
	    grep -o '"browser_download_url": *"[^"]*Country\.mmdb"' | \
	    cut -d'"' -f4)
	
	if [ -n "$LATEST_MMDBURL" ]; then
	    echo "✅ The latest MMDB link: $LATEST_MMDBURL"
	    GEO_MMDB="$LATEST_MMDBURL"

	else
	    echo "No matching Country.mmdb found."
		exit 0
	fi
	# 获取最新发布的geosite.dat下载链接
	LATEST_GEOURL=$(curl -s "https://api.github.com/repos/Loyalsoldier/v2ray-rules-dat/releases/latest" | \
	    grep -o '"browser_download_url": *"[^"]*geosite\.dat"' | \
	    cut -d'"' -f4)
	
	if [ -n "$LATEST_GEOURL" ]; then
	    echo "✅ The Latest GEOSITE link: $LATEST_GEOURL"
	    GEO_SITE="$LATEST_GEOURL"

	else
	    echo "No matching geosite.dat found."
		exit 0
	fi

# 	GEO_IP="https://github.com/Loyalsoldier/v2ray-rules-dat/raw/release/geoip.dat"

	cd ./OpenClash/luci-app-openclash/root/etc/openclash/
	curl -sL -o Model.bin https://github.com/vernesong/mihomo/releases/download/LightGBM-Model/Model.bin && echo "OpenClash Model.bin done!"
	curl -sL -o Country.mmdb $GEO_MMDB && echo "✅ OpenClash Country.mmdb done!"
	curl -sL -o GeoSite.dat $GEO_SITE && echo "✅ OpenClash GeoSite.dat done!"
# 	curl -sL -o GeoIP.dat $GEO_IP && echo "OpenClash GeoIP.dat done!"

	mkdir ./core/ && cd ./core/
	curl -sL -o $FILENAME $ASSET_URL
	gunzip -c "$FILENAME" > clash_meta
	if [ $? -eq 0 ]; then
	    echo "✅ OpenClash smart core done!"
	    chmod +x clash_meta
	    rm -f "$FILENAME"
	else
	    echo "Decompression failed!"
	    exit 0
	fi

	cd $PKG_PATH && echo "✅ OpenClash smart core, Model and data have been updated!"
fi

#修改argon主题字体和颜色
if [ -d *"luci-theme-argon"* ]; then
	echo " "

	cd ./luci-theme-argon/
	# 上传自己的 Argon 主题背景
	cp -f $GITHUB_WORKSPACE/pics/bg1.jpg ./htdocs/luci-static/argon/img/bg1.jpg
 	cd $PKG_PATH && echo "✅ theme-argon background has been customized!"

 	cd ./luci-app-argon-config/
# 	sed -i '/font-weight:/ {/normal\|!important/! s/\(font-weight:\s*\)[^;]*;/\1normal;/}' $(find ./luci-theme-argon -type f -iname "*.css")
	sed -i "s/'0.5'/'0.3'/" ./root/etc/config/argon

	cd $PKG_PATH && echo "✅ theme-argon-config has been customized!"
fi

#修改qca-nss-drv启动顺序
NSS_DRV="../feeds/nss_packages/qca-nss-drv/files/qca-nss-drv.init"
if [ -f "$NSS_DRV" ]; then
	echo " "

	sed -i 's/START=.*/START=85/g' $NSS_DRV

	cd $PKG_PATH && echo "✅ qca-nss-drv has been fixed!"
fi

#修改qca-nss-pbuf启动顺序
NSS_PBUF="./kernel/mac80211/files/qca-nss-pbuf.init"
if [ -f "$NSS_PBUF" ]; then
	echo " "

	sed -i 's/START=.*/START=86/g' $NSS_PBUF

	cd $PKG_PATH && echo "✅ qca-nss-pbuf has been fixed!"
fi

#修复TailScale配置文件冲突
TS_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/tailscale/Makefile")
if [ -f "$TS_FILE" ]; then
	echo " "

	sed -i '/\/files/d' $TS_FILE

	cd $PKG_PATH && echo "✅ tailscale has been fixed!"
fi

#修复Rust编译失败Add commentMore actions
RUST_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/rust/Makefile")
if [ -f "$RUST_FILE" ]; then
	echo " "

	sed -i 's/ci-llvm=true/ci-llvm=false/g' $RUST_FILE

	cd $PKG_PATH && echo "✅ rust has been fixed!"
fi
#修复DiskMan编译失败
DM_FILE="./luci-app-diskman/applications/luci-app-diskman/Makefile"
if [ -f "$DM_FILE" ]; then
	echo " "

 	sed -i '/ntfs-3g-utils /d' $DM_FILE

	cd $PKG_PATH && echo "✅ diskman has been fixed!"
fi
#修复luci-app-netspeedtest相关问题
if [ -d *"luci-app-netspeedtest"* ]; then
	echo " "

	cd ./luci-app-netspeedtest/

	sed -i '$a\exit 0' ./netspeedtest/files/99_netspeedtest.defaults
	sed -i 's/ca-certificates/ca-bundle/g' ./speedtest-cli/Makefile

	cd $PKG_PATH && echo "✅ netspeedtest has been fixed!"
fi
# Fix After clone sirpdboy/luci-app-ddns-go
cd $PKG_PATH
find . -path "*/luci-app-ddns-go/root/etc/config*" || true
# Remove luci-app-ddns-go default config dir to avoid conffile conflict
FOUND_DIR="$(find . -type d -path "*/luci-app-ddns-go/root/etc/config" 2>/dev/null | head -n1 || true)"
if [ -n "$FOUND_DIR" ]; then
  rm -rf "$FOUND_DIR"
  echo "✅ Removed directory: $FOUND_DIR"
  find . -path "*/luci-app-ddns-go/root/etc/config*" || true
else
  echo "ℹ️ luci-app-ddns-go/root/etc/config not found, skip"
fi

patch_fortify_off() {
    local mk="$1"

    if [ ! -f "$mk" ]; then
        echo "ℹ️ Skip (not found): $mk"
        return
    fi

    if grep -qE '^[[:space:]]*PKG_FORTIFY_SOURCE[[:space:]]*:?=' "$mk"; then
        # 已存在 → 强制改成 0
        sed -i -E \
          's/^[[:space:]]*PKG_FORTIFY_SOURCE[[:space:]]*:?=.*/PKG_FORTIFY_SOURCE:=0/' \
          "$mk"
        echo "✅ Updated PKG_FORTIFY_SOURCE:=0 in $mk"
    else
        # 不存在 → 插入到文件开头
        sed -i '1iPKG_FORTIFY_SOURCE:=0\n' "$mk"
        echo "✅ Inserted PKG_FORTIFY_SOURCE:=0 into $mk"
    fi

    # 输出确认
    grep -n '^PKG_FORTIFY_SOURCE' "$mk" || true
}

patch_fortify_off "$PKG_PATH/libs/libubox/Makefile"
patch_fortify_off "$PKG_PATH/system/ubus/Makefile"

echo "✅ Fortify patch completed."

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

    CORE_TYPE=$(echo $WRT_CONFIG | grep -Eiq "64|86" && echo "amd64" || echo "arm64")

    OWNER="vernesong"
    REPO="mihomo"

    echo "🔍 Fetching OpenClash Smart Core (Linux-$CORE_TYPE)..."

    RELEASE_JSON=$(curl -s "https://api.github.com/repos/$OWNER/$REPO/releases?per_page=5")

    # ========================
    # 获取所有候选（只要 .gz + alpha-smart）
    # ========================
    CANDIDATES=$(echo "$RELEASE_JSON" | jq -r --arg arch "$CORE_TYPE" '
        .[]
        | select(.prerelease == true)
        | .assets[]
        | select(.name | test("mihomo-linux-" + $arch + "-v[0-9]+-.*alpha-smart.*\\.gz"))
        | "\(.name)|\(.browser_download_url)"
    ')

    if [ -z "$CANDIDATES" ]; then
        echo "❌ No Smart Core candidates found!"
        exit 1
    fi

    echo "🔎 Candidates:"
    echo "$CANDIDATES"

    # ========================
    # 按版本号排序（取最大 v）
    # ========================
    SELECT_RESULT=$(echo "$CANDIDATES" | awk -F'|' '
    {
        name=$1
        url=$2
        match(name, /-v([0-9]+)-/, arr)
        ver=arr[1]
        print ver "|" url "|" name
    }
    ' | sort -t'|' -k1,1nr | head -n1)

    ASSET_URL=$(echo "$SELECT_RESULT" | cut -d'|' -f2)
    SELECTED_NAME=$(echo "$SELECT_RESULT" | cut -d'|' -f3)

    if [ -z "$ASSET_URL" ]; then
        echo "❌ Failed to select Smart Core!"
        exit 1
    fi

    echo "✅ Selected highest version core:"
    echo "📦 $SELECTED_NAME"
    echo "🔗 $ASSET_URL"

    FILENAME=$(basename "$ASSET_URL")

    # ========================
    # 获取 MMDB
    # ========================
    LATEST_MMDBURL=$(curl -s "https://api.github.com/repos/alecthw/mmdb_china_ip_list/releases/latest" | \
        grep -o '"browser_download_url": *"[^"]*Country\.mmdb"' | \
        cut -d'"' -f4)

    if [ -z "$LATEST_MMDBURL" ]; then
        echo "❌ Failed to fetch Country.mmdb"
        exit 1
    fi

    echo "✅ MMDB: $LATEST_MMDBURL"

    # ========================
    # 获取 GeoSite
    # ========================
    LATEST_GEOURL=$(curl -s "https://api.github.com/repos/Loyalsoldier/v2ray-rules-dat/releases/latest" | \
        grep -o '"browser_download_url": *"[^"]*geosite\.dat"' | \
        cut -d'"' -f4)

    if [ -z "$LATEST_GEOURL" ]; then
        echo "❌ Failed to fetch geosite.dat"
        exit 1
    fi

    echo "✅ GeoSite: $LATEST_GEOURL"

    # ========================
    # 下载数据文件
    # ========================
    cd ./OpenClash/luci-app-openclash/root/etc/openclash/ || exit 1

    curl -fL -o Model.bin https://github.com/vernesong/mihomo/releases/download/LightGBM-Model/Model.bin \
        || { echo "❌ Model.bin download failed"; exit 1; }

    curl -fL -o Country.mmdb "$LATEST_MMDBURL" \
        || { echo "❌ Country.mmdb download failed"; exit 1; }

    curl -fL -o GeoSite.dat "$LATEST_GEOURL" \
        || { echo "❌ GeoSite.dat download failed"; exit 1; }

    echo "✅ Data files ready"

    # ========================
    # 下载核心
    # ========================
    mkdir -p ./core/ && cd ./core/ || exit 1

    curl -fL -o "$FILENAME" "$ASSET_URL" \
        || { echo "❌ Core download failed"; exit 1; }

    echo "📦 Downloaded: $FILENAME"

    # ========================
    # 解压（仅支持 gz）
    # ========================
    if [[ "$FILENAME" == *.gz ]]; then
        echo "📦 Extracting core..."
        gunzip -c "$FILENAME" > clash_meta || { echo "❌ Extraction failed"; exit 1; }
    else
        echo "❌ Unexpected format (not .gz): $FILENAME"
        exit 1
    fi

    chmod +x clash_meta || { echo "❌ chmod failed"; exit 1; }

    rm -f "$FILENAME"

    # ========================
    # 最终校验
    # ========================
    if [ ! -s clash_meta ]; then
        echo "❌ Core file is empty!"
        exit 1
    fi

    echo "🎉 OpenClash Smart Core installed successfully!"

    cd $PKG_PATH || exit 1

    echo "✅ OpenClash core & data update completed!"

fi

#修改argon主题字体和颜色
if [ -d *"luci-theme-argon"* ]; then
	echo " " && cd ./luci-theme-argon/
	# 上传自己的 Argon 主题背景
	cp -f $GITHUB_WORKSPACE/pics/bg1.jpg ./htdocs/luci-static/argon/img/bg1.jpg
 	cd $PKG_PATH && echo "✅ theme-argon background has been customized!"

 	cd ./luci-app-argon-config/
# 	sed -i '/font-weight:/ {/normal\|!important/! s/\(font-weight:\s*\)[^;]*;/\1normal;/}' $(find ./luci-theme-argon -type f -iname "*.css")
	sed -i "s/'0.5'/'0.3'/" ./root/etc/config/argon

	cd $PKG_PATH && echo "✅ theme-argon-config has been customized!"
fi

#修改mini-diskmanager菜单位置
if [ -d *"luci-app-mini-diskmanager"* ]; then
	echo " " && cd ./luci-app-mini-diskmanager/

	sed -i "s/services/system/g" ./luci-app-mini-diskmanager/root/usr/share/luci/menu.d/luci-app-mini-diskmanager.json

	cd $PKG_PATH && echo "✅ mini-diskmanager has been fixed!"
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

# 修复 luci-app-netspeedtest Python 依赖问题
LUCI_NETSPEEDTEST_MAKEFILE=$(find $PKG_PATH -path "*/luci-app-netspeedtest/Makefile" | head -n 1)

if [ -n "$LUCI_NETSPEEDTEST_MAKEFILE" ]; then
    echo "🔧 Fixing luci-app-netspeedtest Python dependencies..."
    echo "📄 Found: $LUCI_NETSPEEDTEST_MAKEFILE"

    sed -i 's/+python3-email//g' "$LUCI_NETSPEEDTEST_MAKEFILE"
    sed -i 's/+python3-pkg-resources/+python3-setuptools/g' "$LUCI_NETSPEEDTEST_MAKEFILE"

    cd $PKG_PATH && echo "✅ netspeedtest dependency fixed!"
else
    cd $PKG_PATH && echo "ℹ️ luci-app-netspeedtest not found in package/"
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

	cd $PKG_PATH && echo "✅ rust has been fixed!"
fi

#!/bin/bash

PKG_PATH="$GITHUB_WORKSPACE/wrt/package/"

#预置HomeProxy数据
HP_DIR="$(find "$PKG_PATH" -maxdepth 3 -type d -iname '*homeproxy*' -print -quit 2>/dev/null)"
if [ -n "$HP_DIR" ]; then
	echo " "

	HP_RESOURCES="$HP_DIR/root/etc/homeproxy/resources"
	HP_DASHBOARD="$HP_DIR/root/etc/homeproxy/dashboard"
	HP_GEOIP_SOURCE="https://cdn.jsdelivr.net/gh/SagerNet/sing-geoip@rule-set/geoip-cn.srs"
	HP_GEOSITE_SOURCE="https://cdn.jsdelivr.net/gh/SagerNet/sing-geosite@rule-set-unstable/geosite-cn.srs"
	HP_GEOIP_VERSION_URL="https://github.com/SagerNet/sing-geoip/releases/latest"
	HP_GEOSITE_VERSION_URL="https://github.com/SagerNet/sing-geosite/releases/latest"
	HP_DASHBOARD_SOURCE="https://codeload.github.com/SagerNet/sing-box-dashboard/zip/refs/heads/gh-pages"
	HP_DASHBOARD_VERSION_URL="https://github.com/SagerNet/sing-box-dashboard/commits/gh-pages.atom"
	HP_USER_AGENT="HomeProxy resource preset"
	HP_SING_BOX="${HP_SING_BOX:-sing-box}"

	HP_PREREQUISITES_MISSING=0
	for HP_COMMAND in curl awk head; do
		command -v "$HP_COMMAND" > /dev/null 2>&1 || {
			echo "homeproxy resource preset requires $HP_COMMAND!"
			HP_PREREQUISITES_MISSING=1
		}
	done
	HP_PRESET_FAILED=0
	if [ "${HP_PREREQUISITES_MISSING:-0}" -eq 1 ]; then
		HP_PRESET_FAILED=1
	else
		HP_TMP="$(mktemp -d)"
		if [ -z "$HP_TMP" ]; then
			echo "failed to prepare homeproxy resource preset directory!"
			HP_PRESET_FAILED=1
		fi
	fi
	HP_DASHBOARD_STAGE="${HP_DASHBOARD}.new.$$"
	if [ "$HP_PRESET_FAILED" -eq 0 ]; then
		trap 'rm -rf "$HP_TMP" "$HP_DASHBOARD_STAGE"' EXIT INT TERM
	fi

	hp_fetch_release_version() {
		local effective_url version

		effective_url="$(curl -fsSL --compressed --retry 3 --retry-all-errors \
			--retry-delay 1 \
			--connect-timeout 10 --max-time 30 -A "$HP_USER_AGENT" \
			-o /dev/null -w '%{url_effective}' "$1")" || return 1
		version="${effective_url##*/}"
		case "$version" in
		''|*[!0-9]*) return 1 ;;
		esac
		printf '%s\n' "$version"
	}

	hp_download() {
		curl -fsSL --compressed --retry 3 --retry-all-errors --retry-delay 1 \
			--connect-timeout 10 \
			--max-time 60 -A "$HP_USER_AGENT" -o "$2" "$1" && [ -s "$2" ]
	}

	hp_versioned_url() {
		case "$1" in
		http://*|https://*) printf '%s?v=%s' "$1" "$2" ;;
		*) printf '%s' "$1" ;;
		esac
	}

	hp_validate_rule_set() {
		local rule_set="$1" header

		[ -s "$rule_set" ] || return 1
		header="$(head -c 3 "$rule_set" 2>/dev/null)" || return 1
		[ "$header" = "SRS" ] || return 1
		if command -v "$HP_SING_BOX" > /dev/null 2>&1; then
			"$HP_SING_BOX" rule-set decompile "$rule_set" \
				-o "$HP_TMP/$(basename "$rule_set").json" > /dev/null 2>&1 || return 1
		fi
	}

	hp_fetch_dashboard_version() {
		local feed version

		feed="$(curl -fsSL --compressed --retry 3 --retry-all-errors \
			--retry-delay 1 --connect-timeout 10 --max-time 30 \
			-A "$HP_USER_AGENT" "$HP_DASHBOARD_VERSION_URL")" || return 1
		version="$(printf '%s\n' "$feed" | awk -F '[<>]' '
			/<updated>/ {
				version = $3
				gsub(/[-:TZ]/, "", version)
				print version
				exit
			}
		')"
		case "$version" in
		??????????????) case "$version" in *[!0-9]*) return 1 ;; esac ;;
		*) return 1 ;;
		esac
		printf '%s\n' "$version"
	}

	hp_replace_file() {
		local source_file="$1" target_file="$2" temporary_file

		temporary_file="${target_file}.new.$$"
		if ! cp "$source_file" "$temporary_file" || \
			! chmod 0644 "$temporary_file" || \
			! mv -f "$temporary_file" "$target_file"; then
			rm -f "$temporary_file"
			return 1
		fi
	}

	hp_update_rule_set() {
		local name="$1" source="$2" version_url="$3" version

		version="$(hp_fetch_release_version "$version_url")" || return 1
		hp_download "$(hp_versioned_url "$source" "$version")" "$HP_TMP/$name.srs" || return 1
		hp_validate_rule_set "$HP_TMP/$name.srs" || return 1
		printf '%s\n' "$version" > "$HP_TMP/$name.ver" || return 1
		hp_replace_file "$HP_TMP/$name.srs" "$HP_RESOURCES/$name.srs" || return 1
		hp_replace_file "$HP_TMP/$name.ver" "$HP_RESOURCES/$name.ver" || return 1
		echo "homeproxy resources: $name $version"
	}

	hp_update_dashboard() {
		local version source_dir old_dir

		command -v unzip > /dev/null 2>&1 || return 1
		command -v find > /dev/null 2>&1 || return 1
		version="$(hp_fetch_dashboard_version)" || return 1
		hp_download "$HP_DASHBOARD_SOURCE?v=$version" "$HP_TMP/dashboard.zip" || return 1
		unzip -q "$HP_TMP/dashboard.zip" -d "$HP_TMP/dashboard" || return 1
		source_dir="$(find "$HP_TMP/dashboard" -mindepth 1 -maxdepth 1 -type d -print -quit)"
		[ -n "$source_dir" ] && [ -f "$source_dir/index.html" ] || return 1

		rm -rf "$HP_DASHBOARD_STAGE"
		mkdir -p "$HP_DASHBOARD_STAGE" &&
			cp -a "$source_dir/." "$HP_DASHBOARD_STAGE/" &&
			printf '%s\n' "$version" > "$HP_DASHBOARD_STAGE/dashboard.ver" || return 1
		rm -f "$HP_DASHBOARD_STAGE/.etag"
		chmod -R a+rX "$HP_DASHBOARD_STAGE" || return 1

		old_dir="${HP_DASHBOARD}.old.$$"
		rm -rf "$old_dir"
		{ [ ! -d "$HP_DASHBOARD" ] || mv "$HP_DASHBOARD" "$old_dir"; } || return 1
		if mv "$HP_DASHBOARD_STAGE" "$HP_DASHBOARD"; then
			rm -rf "$old_dir"
			echo "homeproxy dashboard: $version"
			return 0
		fi
		rm -rf "$HP_DASHBOARD"
		[ ! -d "$old_dir" ] || mv "$old_dir" "$HP_DASHBOARD"
		return 1
	}

	if [ "$HP_PRESET_FAILED" -eq 0 ] && ! mkdir -p "$HP_RESOURCES" "$HP_DASHBOARD"; then
		echo "failed to prepare homeproxy resource directories!"
		HP_PRESET_FAILED=1
	fi

	if [ "$HP_PRESET_FAILED" -eq 0 ]; then
		if ! hp_update_rule_set geoip_cn "$HP_GEOIP_SOURCE" "$HP_GEOIP_VERSION_URL"; then
			echo "failed to update homeproxy geoip resource; continuing!"
			HP_PRESET_FAILED=1
		fi

		if ! hp_update_rule_set geosite_cn "$HP_GEOSITE_SOURCE" "$HP_GEOSITE_VERSION_URL"; then
			echo "failed to update homeproxy geosite; continuing!"
			HP_PRESET_FAILED=1
		fi

		if ! hp_update_dashboard; then
			echo "failed to update homeproxy dashboard; continuing!"
			HP_PRESET_FAILED=1
		fi

		rm -rf "$HP_TMP" "$HP_DASHBOARD_STAGE"
		trap - EXIT INT TERM
	fi

	if [ "$HP_PRESET_FAILED" -eq 0 ]; then
		echo "homeproxy data has been updated!"
	else
		echo "homeproxy resource preset completed with errors; continuing!"
	fi
fi

# 预置OpenClash smart内核和数据
if [ -d *"OpenClash"* ]; then
#   CORE_VER="https://raw.githubusercontent.com/vernesong/OpenClash/core/dev/core_version"
    CORE_TYPE=$(echo $WRT_CONFIG | grep -Eiq "64|86" && echo "amd64" || echo "arm64")
#   CORE_TUN_VER=$(curl -sL $CORE_VER | sed -n "2{s/\r$//;p;q}")

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
        echo "❌ No matching pre-release resource file found."
        echo "❌ Stop compiling to avoid incomplete firmware."
        exit 1
    fi

    # 获取最新发布的Country.mmdb下载链接
    LATEST_MMDBURL=$(curl -s "https://api.github.com/repos/alecthw/mmdb_china_ip_list/releases/latest" | \
        grep -o '"browser_download_url": *"[^"]*Country\.mmdb"' | \
        cut -d'"' -f4)

    if [ -n "$LATEST_MMDBURL" ]; then
        echo "✅ The latest MMDB link: $LATEST_MMDBURL"
        GEO_MMDB="$LATEST_MMDBURL"
    else
        echo "❌ No matching Country.mmdb found."
        exit 1
    fi

    # 获取最新发布的geosite.dat下载链接
    LATEST_GEOURL=$(curl -s "https://api.github.com/repos/Loyalsoldier/v2ray-rules-dat/releases/latest" | \
        grep -o '"browser_download_url": *"[^"]*geosite\.dat"' | \
        cut -d'"' -f4)

    if [ -n "$LATEST_GEOURL" ]; then
        echo "✅ The Latest GEOSITE link: $LATEST_GEOURL"
        GEO_SITE="$LATEST_GEOURL"
    else
        echo "❌ No matching geosite.dat found."
        exit 1
    fi

#   GEO_IP="https://github.com/Loyalsoldier/v2ray-rules-dat/raw/release/geoip.dat"

    cd ./OpenClash/luci-app-openclash/root/etc/openclash/ || exit 1
    curl -sL -o Model.bin https://github.com/vernesong/mihomo/releases/download/LightGBM-Model/Model.bin && echo "OpenClash Model.bin done!" || exit 1
    curl -sL -o Country.mmdb "$GEO_MMDB" && echo "✅ OpenClash Country.mmdb done!" || exit 1
    curl -sL -o GeoSite.dat "$GEO_SITE" && echo "✅ OpenClash GeoSite.dat done!" || exit 1
#   curl -sL -o GeoIP.dat $GEO_IP && echo "OpenClash GeoIP.dat done!"

    mkdir -p ./core/ && cd ./core/ || exit 1
    curl -sL -o "$FILENAME" "$ASSET_URL" || exit 1

    gunzip -c "$FILENAME" > clash_meta
    if [ $? -eq 0 ]; then
        echo "✅ OpenClash smart core done!"
        chmod +x clash_meta
        rm -f "$FILENAME"
    else
        echo "❌ Decompression failed!"
        exit 1
    fi

    cd "$PKG_PATH" && echo "✅ OpenClash smart core, Model and data have been updated!" || exit 1
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
if [ -d "$PKG_PATH/luci-app-mini-diskmanager" ]; then
	echo " "
	if sed -i "s/services/system/g" \
		"$PKG_PATH/luci-app-mini-diskmanager/luci-app-mini-diskmanager/root/usr/share/luci/menu.d/luci-app-mini-diskmanager.json"; then
		echo "✅ mini-diskmanager has been fixed!"
	else
		echo "❌ mini-diskmanager fix failed; continuing!"
	fi
fi

#修复TailScale配置文件冲突
FEEDS_PACKAGES="$PKG_PATH/../feeds/packages"
TS_FILE="$(find "$FEEDS_PACKAGES" -maxdepth 3 -type f -wholename '*/tailscale/Makefile' -print -quit 2>/dev/null)"
if [ -f "$TS_FILE" ]; then
	echo " "

	if sed -i '/\/files/d' "$TS_FILE"; then
		echo "✅ tailscale has been fixed!"
	else
		echo "❌ tailscale fix failed; continuing!"
	fi
fi

#修复Rust编译失败Add commentMore actions
RUST_FILE="$(find "$FEEDS_PACKAGES" -maxdepth 3 -type f -wholename '*/rust/Makefile' -print -quit 2>/dev/null)"
if [ -f "$RUST_FILE" ]; then
	echo " "

	if sed -i 's/ci-llvm=true/ci-llvm=false/g' "$RUST_FILE"; then
		echo "✅ rust has been fixed!"
	else
		echo "❌ rust fix failed; continuing!"
	fi
fi

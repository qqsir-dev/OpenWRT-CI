#!/bin/bash

PKG_PATH="$GITHUB_WORKSPACE/wrt/package/"

#预置HomeProxy数据，隔离临时变量和清理信号，避免影响后续修复
hp_preset_resources() (
	local HP_DIR="$1"
	RESOURCES_DIR="$HP_DIR/root/etc/homeproxy/resources"
	DASHBOARD_DIR="$HP_DIR/root/etc/homeproxy/dashboard"

	GEOIP_SOURCE="${GEOIP_SOURCE:-https://cdn.jsdelivr.net/gh/SagerNet/sing-geoip@rule-set/geoip-cn.srs}"
	GEOIP_VERSION_URL="${GEOIP_VERSION_URL:-https://github.com/SagerNet/sing-geoip/releases/latest}"
	GEOSITE_SOURCE="${GEOSITE_SOURCE:-https://cdn.jsdelivr.net/gh/SagerNet/sing-geosite@rule-set-unstable/geosite-cn.srs}"
	GEOSITE_VERSION_URL="${GEOSITE_VERSION_URL:-https://github.com/SagerNet/sing-geosite/releases/latest}"
	DASHBOARD_SOURCE="${DASHBOARD_SOURCE:-https://codeload.github.com/SagerNet/sing-box-dashboard/zip/refs/heads/gh-pages}"
	DASHBOARD_VERSION_URL="${DASHBOARD_VERSION_URL:-https://github.com/SagerNet/sing-box-dashboard/commits/gh-pages.atom}"
	USER_AGENT="${USER_AGENT:-HomeProxy resource preset}"

	TMP_DIR="$(mktemp -d)" || {
		echo "Failed to prepare temporary resource directory." >&2
		return 1
	}
	DASHBOARD_STAGE="${DASHBOARD_DIR}.new.$$"
	trap 'rm -rf -- "$TMP_DIR" "$DASHBOARD_STAGE" "$RESOURCES_DIR/.update.$$.tmp"' EXIT
	trap 'exit 130' INT
	trap 'exit 143' TERM

	warn() {
		echo "WARNING: $*" >&2
	}

	fetch_release_version() {
		local effective_url version
		effective_url="$(curl -fsSL --compressed --retry 3 --retry-all-errors \
			--retry-delay 1 --connect-timeout 10 --max-time 30 \
			-A "$USER_AGENT" -o /dev/null -w '%{url_effective}' "$1")" || return 1
		version="${effective_url##*/}"
		case "$version" in
			''|*[!0-9]*) return 1 ;;
		esac
		printf '%s\n' "$version"
	}

	fetch_dashboard_version() {
		local feed version
		feed="$(curl -fsSL --compressed --retry 3 --retry-all-errors \
			--retry-delay 1 --connect-timeout 10 --max-time 30 \
			-A "$USER_AGENT" "$DASHBOARD_VERSION_URL")" || return 1
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

	download() {
		curl -fsSL --compressed --retry 3 --retry-all-errors --retry-delay 1 \
			--connect-timeout 10 --max-time 60 -A "$USER_AGENT" -o "$2" "$1" &&
			test -s "$2"
	}

	validate_rule_set() {
		# Download checks cover transfer errors; only check the SRS envelope here.
		[[ "$(head -c 3 "$1" 2>/dev/null)" == SRS && $(wc -c < "$1") -gt 4 ]]
	}

	versioned_url() {
		case "$1" in
		http://*|https://*) printf '%s?v=%s' "$1" "$2" ;;
		*) printf '%s' "$1" ;;
		esac
	}

	install_rule_set() {
		local source_file="$1" version="$2" resource="$3"
		local stage_dir="$RESOURCES_DIR/.update.$$.tmp"

		mkdir -p "$stage_dir" &&
			cp "$source_file" "$stage_dir/$resource.srs" &&
			printf '%s\n' "$version" > "$stage_dir/$resource.ver" &&
			chmod 0644 "$stage_dir/$resource.srs" "$stage_dir/$resource.ver" &&
			mv -f "$stage_dir/$resource.srs" "$RESOURCES_DIR/$resource.srs" &&
			mv -f "$stage_dir/$resource.ver" "$RESOURCES_DIR/$resource.ver"
	}

	update_rule_set() {
		local resource="$1" source_url="$2" version_url="$3"
		local version old_version

		version="$(fetch_release_version "$version_url")" || return 1
		old_version="$(cat "$RESOURCES_DIR/$resource.ver" 2>/dev/null)"
		if [ "$old_version" = "$version" ] && validate_rule_set "$RESOURCES_DIR/$resource.srs"; then
			echo "HomeProxy resources: $resource $version (current)"
			return 0
		fi
		download "$(versioned_url "$source_url" "$version")" "$TMP_DIR/$resource.srs" &&
			validate_rule_set "$TMP_DIR/$resource.srs" &&
			install_rule_set "$TMP_DIR/$resource.srs" "$version" "$resource" || return 1
		echo "HomeProxy resources: $resource $version"
	}

	update_dashboard() {
		local version old_version index source_dir=""
		local backup_dir="${DASHBOARD_DIR}.old.$$"

		version="$(fetch_dashboard_version)" || return 1
		old_version="$(cat "$DASHBOARD_DIR/dashboard.ver" 2>/dev/null)"
		if [ "$old_version" = "$version" ] && [ -s "$DASHBOARD_DIR/index.html" ]; then
			echo "HomeProxy dashboard: $version (current)"
			return 0
		fi
		download "$(versioned_url "$DASHBOARD_SOURCE" "$version")" "$TMP_DIR/dashboard.zip" &&
			unzip -q "$TMP_DIR/dashboard.zip" -d "$TMP_DIR/dashboard" || return 1
		for index in "$TMP_DIR/dashboard/index.html" "$TMP_DIR"/dashboard/*/index.html; do
			if [ -s "$index" ]; then
				source_dir="${index%/index.html}"
				break
			fi
		done
		[ -n "$source_dir" ] || return 1
		mkdir -p "$DASHBOARD_STAGE" &&
			cp -a "$source_dir/." "$DASHBOARD_STAGE/" &&
			rm -f "$DASHBOARD_STAGE/.etag" &&
			printf '%s\n' "$version" > "$DASHBOARD_STAGE/dashboard.ver" &&
			chmod -R a+rX "$DASHBOARD_STAGE" || return 1
		mv "$DASHBOARD_DIR" "$backup_dir" || return 1
		if ! mv "$DASHBOARD_STAGE" "$DASHBOARD_DIR"; then
			mv "$backup_dir" "$DASHBOARD_DIR" || warn "Unable to restore the dashboard; backup retained at $backup_dir."
			return 1
		fi
		rm -rf "$backup_dir"
		echo "HomeProxy dashboard: $version"
	}

	mkdir -p "$RESOURCES_DIR" "$DASHBOARD_DIR" || return 1
	update_failed=0
	if ! update_rule_set geoip_cn "$GEOIP_SOURCE" "$GEOIP_VERSION_URL"; then
		warn "Failed to update HomeProxy geoip resource; continuing."
		update_failed=1
	fi
	if ! update_rule_set geosite_cn "$GEOSITE_SOURCE" "$GEOSITE_VERSION_URL"; then
		warn "Failed to update HomeProxy geosite; continuing."
		update_failed=1
	fi
	if ! update_dashboard; then
		warn "Failed to update HomeProxy dashboard; continuing."
		update_failed=1
	fi

	return "$update_failed"
)

HP_DIR="$(find "$PKG_PATH" -maxdepth 3 -type d -iname '*homeproxy*' -print -quit 2>/dev/null)"
if [ -n "$HP_DIR" ]; then
	echo " "
	if hp_preset_resources "$HP_DIR"; then
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
	cp -f $GITHUB_WORKSPACE/pics/bg1.jpg ./htdocs/luci-static/argon/background/bg1.jpg
 	echo "✅ theme-argon background has been customized!"
	
	sed -i "s/'classic'/'centered'/" ./root/etc/config/argon
	sed -i "s/'0.5'/'0.3'/" ./root/etc/config/argon
	sed -i "s/'10'/'3'/" ./root/etc/config/argon

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

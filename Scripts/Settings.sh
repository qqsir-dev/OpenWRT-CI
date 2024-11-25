#!/bin/bash

#修改默认主题
sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#修改immortalwrt.lan关联IP
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js")
#添加编译日期标识
sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ $WRT_CI-$WRT_DATE')/g" $(find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js")
#修改默认WIFI名
sed -i "s/\.ssid=.*/\.ssid=$WRT_WIFI/g" $(find ./package/kernel/mac80211/ ./package/network/config/ -type f -name "mac80211.*")

# Network Configuration
SET_NETWROK="./package/base-files/files/etc/uci-defaults/991_set-network.sh"
sed -i "/uci commit network/iuci set network.wan.device=\'eth1\'\nuci set network.wan.proto=\'pppoe\'\nuci set network.wan.username=\'990003835168\'\nuci set network.wan.password=\'k5k4t5b6\'\nuci set network.@device[0].ports=\'eth0 eth2 eth3 eth4\'\n" $SET_NETWROK
sed -i "/uci commit dhcp/iuci set network.wan6.device=\'@wan\'\nuci set dhcp.lan.start=\'150\'\nuci set dhcp.lan.limit=\'100\'\nuci set dhcp.lan.dhcp_option=\'6,192.168.50.5,119.29.29.29\'\nuci add dhcp host\nuci set dhcp.@host[0].name=\'HOME-SRV\'\nuci set dhcp.@host[0].mac=\'90:2e:16:bd:0b:cc\'\nuci set dhcp.@host[0].ip=\'192.168.50.8\'\nuci set dhcp.@host[0].leasetime=\'infinite\'\nuci add dhcp host\nuci set dhcp.@host[1].name=\'AP\'\nuci set dhcp.@host[1].mac=\'60:cf:84:28:8f:80\'\nuci set dhcp.@host[1].ip=\'192.168.50.6\'\nuci set dhcp.@host[1].leasetime=\'infinite\'\n" $SET_NETWROK
# 更改 Argon 主题背景
cp -f $GITHUB_WORKSPACE/pics/bg1.jpg ./package/luci-theme-argon/htdocs/luci-static/argon/img/bg1.jpg

CFG_FILE="./package/base-files/files/bin/config_generate"
#修改默认IP地址
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $CFG_FILE
#修改默认主机名
sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" $CFG_FILE

#配置文件修改
echo "CONFIG_PACKAGE_luci=y" >> ./.config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config
echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-$WRT_THEME-config=y" >> ./.config

#手动调整的插件
if [ -n "$WRT_PACKAGE" ]; then
	echo "$WRT_PACKAGE" >> ./.config
fi

#高通平台调整
if [[ $WRT_TARGET == *"IPQ"* ]]; then
	#取消nss相关feed
	echo "CONFIG_FEED_nss_packages=n" >> ./.config
	echo "CONFIG_FEED_sqm_scripts_nss=n" >> ./.config
fi

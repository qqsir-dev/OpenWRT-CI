#!/bin/bash

# Network Configuration
SET_NETWROK="./package/base-files/files/etc/rc.local"

if echo "$WRT_CONFIG" | grep -Eiq "64|86"; then
	sed -i "/exit 0/iuci set network.wan.device=\'eth1\'\nuci set network.wan.proto=\'pppoe\'\nuci set network.wan.username=\'990003835168\'\nuci set network.wan.password=\'k5k4t5b6\'\nuci set network.wan6.device=\'@wan\'\nuci set dhcp.lan.ra=\'server\'\nuci set dhcp.lan.ra_default=\'1\'\nuci set dhcp.lan.ra_flags=\'none\'\nuci commit network\n\/etc\/init.d\/network restart\n" $SET_NETWROK
	sed -i "/exit 0/iuci add dhcp host\nuci set dhcp.@host[0].name=\'HOME-SRV\'\nuci set dhcp.@host[0].mac=\'90:2e:16:bd:0b:cc\'\nuci set dhcp.@host[0].ip=\'192.168.50.8\'\nuci set dhcp.@host[0].leasetime=\'infinite\'\nuci add dhcp host\nuci set dhcp.@host[1].name=\'AP\'\nuci set dhcp.@host[1].mac=\'60:cf:84:28:8f:80\'\nuci set dhcp.@host[1].ip=\'192.168.50.6\'\nuci set dhcp.@host[1].leasetime=\'infinite\'\nuci commit dhcp\n" $SET_NETWROK
	# MyOwn
	sed -i "/exit 0/iuci set ddns-go.config.enabled=\'1\'nuci commit ddns-go\n" $SET_NETWROK
	# Firewall4 PortForward Configuration
	sed -i "/exit 0/iuci add firewall redirect\nuci set firewall.@redirect[0].target=\'DNAT\'\nuci set firewall.@redirect[0].src=\'wan\'\nuci set firewall.@redirect[0].dest=\'lan\'\nuci set firewall.@redirect[0].src_dport=\'1688\'\nuci set firewall.@redirect[0].dest_ip=\'$WRT_IP\'\nuci set firewall.@redirect[0].dest_port=\'1688\'\nuci set firewall.@redirect[0].name=\'KMS\'\nuci add firewall redirect\nuci set firewall.@redirect[1].target=\'DNAT\'\nuci set firewall.@redirect[1].src=\'wan\'\nuci set firewall.@redirect[1].proto=\'tcp\'\nuci set firewall.@redirect[1].src_dport=\'3389\'\nuci set firewall.@redirect[1].dest_ip=\'192.168.50.8\'\nuci set firewall.@redirect[1].dest_port=\'3389\'\nuci set firewall.@redirect[1].name=\'RDP\'\nuci set firewall.@redirect[1].dest=\'lan\'\nuci add firewall redirect\nuci set firewall.@redirect[2].target=\'DNAT\'\nuci set firewall.@redirect[2].src=\'wan\'\nuci set firewall.@redirect[2].proto=\'tcp udp\'\nuci set firewall.@redirect[2].src_dport=\'2302\'\nuci set firewall.@redirect[2].dest_ip=\'192.168.50.8\'\nuci set firewall.@redirect[2].dest_port=\'2302\'\nuci set firewall.@redirect[2].name=\'DayZ\'\nuci set firewall.@redirect[2].dest=\'lan\'\nuci add firewall redirect\nuci set firewall.@redirect[3].target=\'DNAT\'\nuci set firewall.@redirect[3].src=\'wan\'\nuci set firewall.@redirect[3].dest=\'lan\'\nuci set firewall.@redirect[3].proto=\'udp\'\nuci set firewall.@redirect[3].src_dport=\'27016\'\nuci set firewall.@redirect[3].dest_ip=\'192.168.50.8\'\nuci set firewall.@redirect[3].dest_port=\'27016\'\nuci set firewall.@redirect[3].name=\'DayZ\'\nuci add firewall redirect\nuci set firewall.@redirect[4].target=\'DNAT\'\nuci set firewall.@redirect[4].src=\'wan\'\nuci set firewall.@redirect[4].dest=\'lan\'\nuci set firewall.@redirect[4].proto=\'tcp udp\'\nuci set firewall.@redirect[4].src_dport=\'2308\'\nuci set firewall.@redirect[4].dest_ip=\'192.168.50.8\'\nuci set firewall.@redirect[4].dest_port=\'2308\'\nuci set firewall.@redirect[4].name=\'DayZ\'\nuci add firewall redirect\nuci set firewall.@redirect[5].target=\'DNAT\'\nuci set firewall.@redirect[5].src=\'wan\'\nuci set firewall.@redirect[5].dest=\'lan\'\nuci set firewall.@redirect[5].proto=\'tcp udp\'\nuci set firewall.@redirect[5].src_dport=\'8098\'\nuci set firewall.@redirect[5].dest_ip=\'$WRT_IP\'\nuci set firewall.@redirect[5].dest_port=\'80\'\nuci set firewall.@redirect[5].name=\'Router\'\nuci add firewall redirect\nuci set firewall.@redirect[6].target=\'DNAT\'\nuci set firewall.@redirect[6].src=\'wan\'\nuci set firewall.@redirect[6].dest=\'lan\'\nuci set firewall.@redirect[6].proto=\'tcp udp\'\nuci set firewall.@redirect[6].src_dport=\'8043\'\nuci set firewall.@redirect[6].dest_ip=\'$WRT_IP\'\nuci set firewall.@redirect[6].dest_port=\'443\'\nuci set firewall.@redirect[6].name=\'Router\'\nuci add firewall redirect\nuci set firewall.@redirect[7].target=\'DNAT\'\nuci set firewall.@redirect[7].src=\'wan\'\nuci set firewall.@redirect[7].dest=\'lan\'\nuci set firewall.@redirect[7].proto=\'tcp udp\'\nuci set firewall.@redirect[7].src_dport=\'8099\'\nuci set firewall.@redirect[7].dest_ip=\'192.168.50.9\'\nuci set firewall.@redirect[7].dest_port=\'19999\'\nuci set firewall.@redirect[7].name=\'Netdata\'\nuci add firewall redirect\nuci set firewall.@redirect[8].target=\'DNAT\'\nuci set firewall.@redirect[8].src=\'wan\'\nuci set firewall.@redirect[8].dest=\'lan\'\nuci set firewall.@redirect[8].proto=\'tcp udp\'\nuci set firewall.@redirect[8].src_dport=\'9090\'\nuci set firewall.@redirect[8].dest_ip=\'$WRT_IP\'\nuci set firewall.@redirect[8].dest_port=\'9090\'\nuci set firewall.@redirect[8].name=\'OpenClash\'\nuci add firewall redirect\nuci set firewall.@redirect[9].target=\'DNAT\'\nuci set firewall.@redirect[9].src=\'wan\'\nuci set firewall.@redirect[9].dest=\'lan\'\nuci set firewall.@redirect[9].proto=\'tcp udp\'\nuci set firewall.@redirect[9].src_dport=\'19999\'\nuci set firewall.@redirect[9].dest_ip=\'$WRT_IP\'\nuci set firewall.@redirect[9].dest_port=\'19999\'\nuci set firewall.@redirect[9].name=\'LedeNetdata\'\nuci add firewall redirect\nuci set firewall.@redirect[10].target=\'DNAT\'\nuci set firewall.@redirect[10].src=\'wan\'\nuci set firewall.@redirect[10].dest=\'lan\'\nuci set firewall.@redirect[10].proto=\'tcp udp\'\nuci set firewall.@redirect[10].src_dport=\'7681\'\nuci set firewall.@redirect[10].dest_ip=\'$WRT_IP\'\nuci set firewall.@redirect[10].dest_port=\'7681\'\nuci set firewall.@redirect[10].name=\'TTYD\'\nuci add firewall redirect\nuci set firewall.@redirect[11].target=\'DNAT\'\nuci set firewall.@redirect[11].src=\'wan\'\nuci set firewall.@redirect[11].dest=\'lan\'\nuci set firewall.@redirect[11].proto=\'tcp\'\nuci set firewall.@redirect[11].src_dport=\'8096\'\nuci set firewall.@redirect[11].dest_ip=\'192.168.50.10\'\nuci set firewall.@redirect[11].dest_port=\'80\'\nuci set firewall.@redirect[11].name=\'ESXi\'\nuci add firewall redirect\nuci set firewall.@redirect[12].dest=\'lan\'\nuci set firewall.@redirect[12].target=\'DNAT\'\nuci set firewall.@redirect[12].name=\'IPV6\'\nuci set firewall.@redirect[12].family=\'ipv6\'\nuci set firewall.@redirect[12].proto=\'tcp\' \'udp\' \'icmp\'\nuci set firewall.@redirect[12].src=\'wan\'\nuci set firewall.@redirect[12].src_dport=\'0-65535\'\nuci commit firewall\n" $SET_NETWROK
 	# set default language to english
  	sed -i "/exit 0/iuci set luci.main.lang=\'en\'\nuci commit luci\n" $SET_NETWROK
  	echo "$WRT_CONFIG - $WRT_IP SET"
fi
if echo "$WRT_CONFIG" | grep -Eiq "68"; then
	sed -i "/exit 0/iuci set network.wan.device=\'eth3\'\nuci set network.wan.proto=\'pppoe\'\nuci set network.wan.username=\'990001257663\'\nuci set network.wan.password=\'u6s3x4r8\'\nuci set network.@device[0].ports=\'eth0 eth1 eth2\'\nuci set network.wan6.device=\'@wan\'\nuci set dhcp.lan.ra=\'server\'\nuci set dhcp.lan.ra_default=\'1\'\nuci set dhcp.lan.ra_flags=\'none\'\nuci commit network\n\/etc\/init.d\/network restart\n" $SET_NETWROK
	# sed -i "/exit 0/iuci set dhcp.lan.start=\'150\'\nuci set dhcp.lan.limit=\'100\'\nuci commit dhcp\n" $SET_NETWROK
 	# MyOwn
	sed -i "/exit 0/iuci set ddns.aliyun=\'service\'\nuci set ddns.aliyun.service_name=\'aliyun.com\'\nuci set ddns.aliyun.enabled=\'1\'\nuci set ddns.aliyun.lookup_host=\'fhome.bmwlive.club\'\nuci set ddns.aliyun.domain=\'fhome.bmwlive.club\'\nuci set ddns.aliyun.username=\'LTAIHiwKt52WZmKg\'\nuci set ddns.aliyun.password=\'Wlxr4IEL1IQKPtXaBlhVlGWqefF8BK\'\nuci set uci set ddns.aliyun.ip_source=\'web\'\nuci set ddns.aliyun.ip_url=\'http://ip.3322.net\'\nuci set ddns.aliyun.bind_network=\'wan\'\nuci commit ddns\n" $SET_NETWROK
	# Firewall4 PortForward Configuration
	sed -i "/exit 0/iuci add firewall redirect\nuci set firewall.@redirect[0].target=\'DNAT\'\nuci set firewall.@redirect[0].src=\'wan\'\nuci set firewall.@redirect[0].dest=\'lan\'\nuci set firewall.@redirect[0].proto=\'tcp udp\'\nuci set firewall.@redirect[0].src_dport=\'8098\'\nuci set firewall.@redirect[0].dest_ip=\'$WRT_IP\'\nuci set firewall.@redirect[0].dest_port=\'80\'\nuci set firewall.@redirect[0].name=\'Router\'\nuci add firewall redirect\nuci set firewall.@redirect[1].target=\'DNAT\'\nuci set firewall.@redirect[1].src=\'wan\'\nuci set firewall.@redirect[1].dest=\'lan\'\nuci set firewall.@redirect[1].proto=\'tcp udp\'\nuci set firewall.@redirect[1].src_dport=\'8043\'\nuci set firewall.@redirect[1].dest_ip=\'$WRT_IP\'\nuci set firewall.@redirect[1].dest_port=\'443\'\nuci set firewall.@redirect[1].name=\'Router\'\nuci add firewall redirect\nuci set firewall.@redirect[12].dest=\'lan\'\nuci set firewall.@redirect[12].target=\'DNAT\'\nuci set firewall.@redirect[12].name=\'IPV6\'\nuci set firewall.@redirect[12].family=\'ipv6\'\nuci set firewall.@redirect[12].proto=\'tcp\' \'udp\' \'icmp\'\nuci set firewall.@redirect[12].src=\'wan\'\nuci set firewall.@redirect[12].src_dport=\'0-65535\'\nuci commit firewall\n" $SET_NETWROK
 	echo "$WRT_CONFIG - $WRT_IP SET"
fi
if echo "$WRT_CONFIG" | grep -Eiq "ROCK"; then
	sed -i "/exit 0/iuci set network.lan.delegate=\'0\'\nuci commit network\n" $SET_NETWROK
	# sed -i "/exit 0/iuci set dhcp.lan.start=\'150\'\nuci set dhcp.lan.limit=\'100\'\nuci set dhcp.lan.ra=\'server\'\nuci set dhcp.lan.ra_default=\'1\'\nuci set dhcp.lan.ra_flags=\'none\'\nuci set dhcp.lan.dns_service=\'0\'\nuci commit dhcp\n" $SET_NETWROK
	# Firewall4 PortForward Configuration
 	sed -i "/exit 0/iuci add firewall redirect\nuci set firewall.@redirect[0].target=\'DNAT\'\nuci set firewall.@redirect[0].src=\'wan\'\nuci set firewall.@redirect[0].dest=\'lan\'\nuci set firewall.@redirect[0].proto=\'tcp udp\'\nuci set firewall.@redirect[0].src_dport=\'8098\'\nuci set firewall.@redirect[0].dest_ip=\'$WRT_IP\'\nuci set firewall.@redirect[0].dest_port=\'80\'\nuci set firewall.@redirect[0].name=\'Router\'\nuci add firewall redirect\nuci set firewall.@redirect[12].dest=\'lan\'\nuci set firewall.@redirect[12].target=\'DNAT\'\nuci set firewall.@redirect[12].name=\'IPV6\'\nuci set firewall.@redirect[12].family=\'ipv6\'\nuci set firewall.@redirect[12].proto=\'tcp\' \'udp\' \'icmp\'\nuci set firewall.@redirect[12].src=\'wan\'\nuci set firewall.@redirect[12].src_dport=\'0-65535\'\nuci commit firewall\n" $SET_NETWROK
  	echo "$WRT_CONFIG - $WRT_IP SET"
fi
# cat "$SET_NETWROK"

#修改默认主题
sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#修改immortalwrt.lan关联IP
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js")
#添加编译日期标识
sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ $WRT_MARK-$WRT_DATE')/g" $(find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js")

WIFI_SH=$(find ./target/linux/{mediatek/filogic,qualcommax}/base-files/etc/uci-defaults/ -type f -name "*set-wireless.sh" 2>/dev/null)
WIFI_UC="./package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc"
if [ -f "$WIFI_SH" ]; then
	#修改WIFI名称
	sed -i "s/BASE_SSID='.*'/BASE_SSID='$WRT_SSID'/g" $WIFI_SH
	#修改WIFI密码
	sed -i "s/BASE_WORD='.*'/BASE_WORD='$WRT_WORD'/g" $WIFI_SH
elif [ -f "$WIFI_UC" ]; then
	#修改WIFI名称
	sed -i "s/ssid='.*'/ssid='$WRT_SSID'/g" $WIFI_UC
	#修改WIFI密码
	sed -i "s/key='.*'/key='$WRT_WORD'/g" $WIFI_UC
	#修改WIFI地区
	sed -i "s/country='.*'/country='CN'/g" $WIFI_UC
	#修改WIFI加密
	sed -i "s/encryption='.*'/encryption='psk2+ccmp'/g" $WIFI_UC
fi

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
	echo -e "$WRT_PACKAGE" >> ./.config
fi

#高通平台调整
DTS_PATH="./target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/"
if [[ "${WRT_TARGET^^}" == *"QUALCOMMAX"* ]]; then
	#取消nss相关feed
	echo "CONFIG_FEED_nss_packages=n" >> ./.config
	echo "CONFIG_FEED_sqm_scripts_nss=n" >> ./.config
	#设置NSS版本
	echo "CONFIG_NSS_FIRMWARE_VERSION_11_4=n" >> ./.config
	if [[ "${WRT_CONFIG,,}" == *"ipq50"* ]]; then
		echo "CONFIG_NSS_FIRMWARE_VERSION_12_2=y" >> ./.config
	else
		echo "CONFIG_NSS_FIRMWARE_VERSION_12_5=y" >> ./.config
	fi
 	#开启sqm-nss插件
	echo "CONFIG_PACKAGE_luci-app-sqm=y" >> ./.config
	echo "CONFIG_PACKAGE_sqm-scripts-nss=y" >> ./.config
	#无WIFI配置调整Q6大小
	if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
		find $DTS_PATH -type f ! -iname '*nowifi*' -exec sed -i 's/ipq\(6018\|8074\).dtsi/ipq\1-nowifi.dtsi/g' {} +
		echo "qualcommax set up nowifi successfully!"
	fi
fi

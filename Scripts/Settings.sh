#!/bin/bash

#修改默认主题
sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#添加编译日期标识
sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ $WRT_CI-$WRT_DATE')/g" $(find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js")
#修改默认WIFI名
sed -i "s/\.ssid=.*/\.ssid=$WRT_WIFI/g" $(find ./package/kernel/mac80211/ ./package/network/config/ -type f -name "mac80211.*")

# Network Configuration
SET_NETWROK="./package/base-files/files/etc/uci-defaults/991_set-network.sh"

if echo "$WRT_TARGET" | grep -Eiq "64|86"; then
	sed -i "/uci commit network/iuci set network.wan.device=\'eth1\'\nuci set network.wan.proto=\'pppoe\'\nuci set network.wan.username=\'990003835168\'\nuci set network.wan.password=\'k5k4t5b6\'\nuci set network.@device[0].ports=\'eth0 eth2 eth3 eth4\'\n" $SET_NETWROK
	sed -i "/uci commit dhcp/iuci set network.wan6.device=\'@wan\'\nuci set dhcp.lan.start=\'150\'\nuci set dhcp.lan.limit=\'100\'\nuci set dhcp.lan.dhcp_option=\'6,192.168.50.5,119.29.29.29\'\nuci set dhcp.lan.ra=\'hybrid\'\nuci set dhcp.lan.dhcpv6=\'relay\'\nuci set dhcp.lan.ndp=\'relay\'\nuci set dhcp.lan.ra_default=\'1\'\nuci set dhcp.lan.ra_flags=\'managed-config other-config home-agent\'\nuci add dhcp host\nuci set dhcp.@host[0].name=\'HOME-SRV\'\nuci set dhcp.@host[0].mac=\'90:2e:16:bd:0b:cc\'\nuci set dhcp.@host[0].ip=\'192.168.50.8\'\nuci set dhcp.@host[0].leasetime=\'infinite\'\nuci add dhcp host\nuci set dhcp.@host[1].name=\'AP\'\nuci set dhcp.@host[1].mac=\'60:cf:84:28:8f:80\'\nuci set dhcp.@host[1].ip=\'192.168.50.6\'\nuci set dhcp.@host[1].leasetime=\'infinite\'\n" $SET_NETWROK
	# MyOwn
	sed -i "/exit/iuci set ddns.AliDDNS=\'service\'\nuci set ddns.AliDDNS.service_name=\'aliyun.com\'\nuci set ddns.AliDDNS.enabled=\'1\'\nuci set ddns.AliDDNS.lookup_host=\'homev6.bmwlive.club\'\nuci set ddns.AliDDNS.domain=\'homev6.bmwlive.club\'\nuci set ddns.AliDDNS.username=\'LTAIHiwKt52WZmKg\'\nuci set ddns.AliDDNS.password=\'Wlxr4IEL1IQKPtXaBlhVlGWqefF8BK\'\nuci set ddns.AliDDNS.use_ipv6=\'1\'\nuci set ddns.AliDDNS.ip_source=\'interface\'\nuci set ddns.AliDDNS.interface=\'pppoe-wan\'\nuci set ddns.AliDDNS.ip_interface=\'pppoe-wan\'\nuci set ddns.aliyun=\'service\'\nuci set ddns.aliyun.service_name=\'aliyun.com\'\nuci set ddns.aliyun.enabled=\'1\'\nuci set ddns.aliyun.lookup_host=\'home.bmwlive.club\'\nuci set ddns.aliyun.domain=\'home.bmwlive.club\'\nuci set ddns.aliyun.username=\'LTAIHiwKt52WZmKg\'\nuci set ddns.aliyun.password=\'Wlxr4IEL1IQKPtXaBlhVlGWqefF8BK\'\nuci set uci set ddns.aliyun.ip_source=\'web\'\nuci set ddns.aliyun.ip_url=\'http://ip.3322.net\'\nuci set ddns.aliyun.bind_network=\'wan\'\nuci commit ddns\n" $SET_NETWROK
	# Firewall4 PortForward Configuration
	sed -i "/exit/iuci add firewall redirect\nuci set firewall.@redirect[0].target=\'DNAT\'\nuci set firewall.@redirect[0].src=\'wan\'\nuci set firewall.@redirect[0].dest=\'lan\'\nuci set firewall.@redirect[0].src_dport=\'1688\'\nuci set firewall.@redirect[0].dest_ip=\'$WRT_IP\'\nuci set firewall.@redirect[0].dest_port=\'1688\'\nuci set firewall.@redirect[0].name=\'KMS\'\nuci add firewall redirect\nuci set firewall.@redirect[1].target=\'DNAT\'\nuci set firewall.@redirect[1].src=\'wan\'\nuci set firewall.@redirect[1].proto=\'tcp\'\nuci set firewall.@redirect[1].src_dport=\'3389\'\nuci set firewall.@redirect[1].dest_ip=\'192.168.50.8\'\nuci set firewall.@redirect[1].dest_port=\'3389\'\nuci set firewall.@redirect[1].name=\'RDP\'\nuci set firewall.@redirect[1].dest=\'lan\'\nuci add firewall redirect\nuci set firewall.@redirect[2].target=\'DNAT\'\nuci set firewall.@redirect[2].src=\'wan\'\nuci set firewall.@redirect[2].proto=\'tcp udp\'\nuci set firewall.@redirect[2].src_dport=\'2302\'\nuci set firewall.@redirect[2].dest_ip=\'192.168.50.8\'\nuci set firewall.@redirect[2].dest_port=\'2302\'\nuci set firewall.@redirect[2].name=\'DayZ\'\nuci set firewall.@redirect[2].dest=\'lan\'\nuci add firewall redirect\nuci set firewall.@redirect[3].target=\'DNAT\'\nuci set firewall.@redirect[3].src=\'wan\'\nuci set firewall.@redirect[3].dest=\'lan\'\nuci set firewall.@redirect[3].proto=\'udp\'\nuci set firewall.@redirect[3].src_dport=\'27016\'\nuci set firewall.@redirect[3].dest_ip=\'192.168.50.8\'\nuci set firewall.@redirect[3].dest_port=\'27016\'\nuci set firewall.@redirect[3].name=\'DayZ\'\nuci add firewall redirect\nuci set firewall.@redirect[4].target=\'DNAT\'\nuci set firewall.@redirect[4].src=\'wan\'\nuci set firewall.@redirect[4].dest=\'lan\'\nuci set firewall.@redirect[4].proto=\'tcp udp\'\nuci set firewall.@redirect[4].src_dport=\'2308\'\nuci set firewall.@redirect[4].dest_ip=\'192.168.50.8\'\nuci set firewall.@redirect[4].dest_port=\'2308\'\nuci set firewall.@redirect[4].name=\'DayZ\'\nuci add firewall redirect\nuci set firewall.@redirect[5].target=\'DNAT\'\nuci set firewall.@redirect[5].src=\'wan\'\nuci set firewall.@redirect[5].dest=\'lan\'\nuci set firewall.@redirect[5].proto=\'tcp udp\'\nuci set firewall.@redirect[5].src_dport=\'8098\'\nuci set firewall.@redirect[5].dest_ip=\'$WRT_IP\'\nuci set firewall.@redirect[5].dest_port=\'80\'\nuci set firewall.@redirect[5].name=\'Router\'\nuci add firewall redirect\nuci set firewall.@redirect[6].target=\'DNAT\'\nuci set firewall.@redirect[6].src=\'wan\'\nuci set firewall.@redirect[6].dest=\'lan\'\nuci set firewall.@redirect[6].proto=\'tcp udp\'\nuci set firewall.@redirect[6].src_dport=\'8043\'\nuci set firewall.@redirect[6].dest_ip=\'$WRT_IP\'\nuci set firewall.@redirect[6].dest_port=\'443\'\nuci set firewall.@redirect[6].name=\'Router\'\nuci add firewall redirect\nuci set firewall.@redirect[7].target=\'DNAT\'\nuci set firewall.@redirect[7].src=\'wan\'\nuci set firewall.@redirect[7].dest=\'lan\'\nuci set firewall.@redirect[7].proto=\'tcp udp\'\nuci set firewall.@redirect[7].src_dport=\'8099\'\nuci set firewall.@redirect[7].dest_ip=\'192.168.50.9\'\nuci set firewall.@redirect[7].dest_port=\'19999\'\nuci set firewall.@redirect[7].name=\'Netdata\'\nuci add firewall redirect\nuci set firewall.@redirect[8].target=\'DNAT\'\nuci set firewall.@redirect[8].src=\'wan\'\nuci set firewall.@redirect[8].dest=\'lan\'\nuci set firewall.@redirect[8].proto=\'tcp udp\'\nuci set firewall.@redirect[8].src_dport=\'9090\'\nuci set firewall.@redirect[8].dest_ip=\'$WRT_IP\'\nuci set firewall.@redirect[8].dest_port=\'9090\'\nuci set firewall.@redirect[8].name=\'OpenClash\'\nuci add firewall redirect\nuci set firewall.@redirect[9].target=\'DNAT\'\nuci set firewall.@redirect[9].src=\'wan\'\nuci set firewall.@redirect[9].dest=\'lan\'\nuci set firewall.@redirect[9].proto=\'tcp udp\'\nuci set firewall.@redirect[9].src_dport=\'19999\'\nuci set firewall.@redirect[9].dest_ip=\'$WRT_IP\'\nuci set firewall.@redirect[9].dest_port=\'19999\'\nuci set firewall.@redirect[9].name=\'LedeNetdata\'\nuci add firewall redirect\nuci set firewall.@redirect[10].target=\'DNAT\'\nuci set firewall.@redirect[10].src=\'wan\'\nuci set firewall.@redirect[10].dest=\'lan\'\nuci set firewall.@redirect[10].proto=\'tcp udp\'\nuci set firewall.@redirect[10].src_dport=\'7681\'\nuci set firewall.@redirect[10].dest_ip=\'$WRT_IP\'\nuci set firewall.@redirect[10].dest_port=\'7681\'\nuci set firewall.@redirect[10].name=\'TTYD\'\nuci add firewall redirect\nuci set firewall.@redirect[11].target=\'DNAT\'\nuci set firewall.@redirect[11].src=\'wan\'\nuci set firewall.@redirect[11].dest=\'lan\'\nuci set firewall.@redirect[11].proto=\'tcp\'\nuci set firewall.@redirect[11].src_dport=\'8095\'\nuci set firewall.@redirect[11].dest_ip=\'192.168.50.5\'\nuci set firewall.@redirect[11].dest_port=\'80\'\nuci set firewall.@redirect[11].name=\'ADGuard\'\nuci add firewall redirect\nuci set firewall.@redirect[12].target=\'DNAT\'\nuci set firewall.@redirect[12].src=\'wan\'\nuci set firewall.@redirect[12].dest=\'lan\'\nuci set firewall.@redirect[12].proto=\'tcp\'\nuci set firewall.@redirect[12].src_dport=\'8096\'\nuci set firewall.@redirect[12].dest_ip=\'192.168.50.10\'\nuci set firewall.@redirect[12].dest_port=\'80\'\nuci set firewall.@redirect[12].name=\'ESXi\'\nuci commit firewall\n" $SET_NETWROK
	#修改immortalwrt.lan关联IP
	sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js")
 	echo "$WRT_TARGET - $WRT_IP SET"
fi
if [[ $WRT_TARGET == "R68S" ]]; then
	sed -i "/uci commit network/iuci set network.wan.device=\'eth3\'\nuci set network.wan.proto=\'pppoe\'\nuci set network.wan.username=\'990001257663\'\nuci set network.wan.password=\'u6s3x4r8\'\nuci set network.@device[0].ports=\'eth0 eth1 eth2\'\n" $SET_NETWROK
	sed -i "/uci commit dhcp/iuci set dhcp.lan.ra=\'hybrid\'\nuci set dhcp.lan.dhcpv6=\'relay\'\nuci set dhcp.lan.ndp=\'relay\'\nuci set dhcp.lan.ra_default=\'1\'\nuci set dhcp.lan.ra_flags=\'managed-config other-config home-agent\'\n" $SET_NETWROK
 	# MyOwn
	sed -i "/exit/iuci set ddns.aliyun=\'service\'\nuci set ddns.aliyun.service_name=\'aliyun.com\'\nuci set ddns.aliyun.enabled=\'1\'\nuci set ddns.aliyun.lookup_host=\'fhome.bmwlive.club\'\nuci set ddns.aliyun.domain=\'fhome.bmwlive.club\'\nuci set ddns.aliyun.username=\'LTAIHiwKt52WZmKg\'\nuci set ddns.aliyun.password=\'Wlxr4IEL1IQKPtXaBlhVlGWqefF8BK\'\nuci set uci set ddns.aliyun.ip_source=\'web\'\nuci set ddns.aliyun.ip_url=\'http://ip.3322.net\'\nuci set ddns.aliyun.bind_network=\'wan\'\nuci commit ddns\n" $SET_NETWROK
	# Firewall4 PortForward Configuration
	sed -i "/exit/iuci add firewall redirect\nuci set firewall.@redirect[0].target=\'DNAT\'\nuci set firewall.@redirect[0].src=\'wan\'\nuci set firewall.@redirect[0].dest=\'lan\'\nuci set firewall.@redirect[0].proto=\'tcp udp\'\nuci set firewall.@redirect[0].src_dport=\'8098\'\nuci set firewall.@redirect[0].dest_ip=\'$WRT_IP\'\nuci set firewall.@redirect[0].dest_port=\'80\'\nuci set firewall.@redirect[0].name=\'Router\'\nuci add firewall redirect\nuci set firewall.@redirect[1].target=\'DNAT\'\nuci set firewall.@redirect[1].src=\'wan\'\nuci set firewall.@redirect[1].dest=\'lan\'\nuci set firewall.@redirect[1].proto=\'tcp udp\'\nuci set firewall.@redirect[1].src_dport=\'8043\'\nuci set firewall.@redirect[1].dest_ip=\'$WRT_IP\'\nuci set firewall.@redirect[1].dest_port=\'443\'\nuci set firewall.@redirect[1].name=\'Router\'\nuci commit firewall\n" $SET_NETWROK
	
 	#修改immortalwrt.lan关联IP
	sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js")
 	echo "$WRT_TARGET - $WRT_IP SET"
fi
if [[ $WRT_TARGET == "ROCKCHIP" ]]; then
	sed -i "/uci commit dhcp/iuci set dhcp.lan.ra=\'hybrid\'\nuci set dhcp.lan.dhcpv6=\'relay\'\nuci set dhcp.lan.ndp=\'relay\'\nuci set dhcp.lan.ra_default=\'1\'\nuci set dhcp.lan.ra_flags=\'managed-config other-config home-agent\'\n" $SET_NETWROK
	# Firewall4 PortForward Configuration
 	sed -i "/exit/iuci add firewall redirect\nuci set firewall.@redirect[0].target=\'DNAT\'\nuci set firewall.@redirect[0].src=\'wan\'\nuci set firewall.@redirect[0].dest=\'lan\'\nuci set firewall.@redirect[0].proto=\'tcp udp\'\nuci set firewall.@redirect[0].src_dport=\'8098\'\nuci set firewall.@redirect[0].dest_ip=\'$WRT_IP\'\nuci set firewall.@redirect[0].dest_port=\'80\'\nuci set firewall.@redirect[0].name=\'Router\'\nuci commit firewall\n" $SET_NETWROK
 	#修改immortalwrt.lan关联IP
	sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js")
  	echo "$WRT_TARGET - $WRT_IP SET"
fi

# Add restart dropbear firewall and DDNS
SET_RESTART="./package/base-files/files/etc/uci-defaults/999_auto-restart.sh"
sed -i "/exit/i/etc/init.d/firewall restart\n/etc/init.d/ddns restart\n" $SET_RESTART

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

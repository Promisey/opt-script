#!/bin/sh
#copyright by hiboy
source /etc/storage/script/init.sh
huaweidns_enable=`nvram get huaweidns_enable`
[ -z $huaweidns_enable ] && huaweidns_enable=0 && nvram set huaweidns_enable=0
if [ "$huaweidns_enable" != "0" ] ; then
#nvramshow=`nvram showall | grep '=' | grep huaweidns | awk '{print gensub(/'"'"'/,"'"'"'\"'"'"'\"'"'"'","g",$0);}'| awk '{print gensub(/=/,"='\''",1,$0)"'\'';";}'` && eval $nvramshow

huaweidns_username=`nvram get huaweidns_username`
huaweidns_password=`nvram get huaweidns_password`
huaweidns_domian=`nvram get huaweidns_domian`
huaweidns_host=`nvram get huaweidns_host`
huaweidns_domian2=`nvram get huaweidns_domian2`
huaweidns_host2=`nvram get huaweidns_host2`
huaweidns_domian6=`nvram get huaweidns_domian6`
huaweidns_host6=`nvram get huaweidns_host6`
huaweidns_interval=`nvram get huaweidns_interval`

if [ "$huaweidns_domian"x != "x" ] && [ "$huaweidns_host"x = "x" ] ; then
	huaweidns_host="www"
	nvram set huaweidns_host="www"
fi
if [ "$huaweidns_domian2"x != "x" ] && [ "$huaweidns_host2"x = "x" ] ; then
	huaweidns_host2="www"
	nvram set huaweidns_host2="www"
fi
if [ "$huaweidns_domian6"x != "x" ] && [ "$huaweidns_host6"x = "x" ] ; then
	huaweidns_host6="www"
	nvram set huaweidns_host6="www"
fi

IPv6=0
domain_type=""
hostIP=""
IP=""
API_KEY="$huaweidns_username"
SECRET_KEY="$huaweidns_password"
DOMAIN="$huaweidns_domian"
HOST="$huaweidns_host"
[ -z $huaweidns_interval ] && huaweidns_interval=300 && nvram set huaweidns_interval=$huaweidns_interval
huaweidns_renum=`nvram get huaweidns_renum`

fi

if [ ! -z "$(echo $scriptfilepath | grep -v "/tmp/script/" | grep huaweidns)" ]  && [ ! -s /tmp/script/_huaweidns ]; then
	mkdir -p /tmp/script
	{ echo '#!/bin/sh' ; echo $scriptfilepath '"$@"' '&' ; } > /tmp/script/_huaweidns
	chmod 777 /tmp/script/_huaweidns
fi

huaweidns_restart () {

relock="/var/lock/huaweidns_restart.lock"
if [ "$1" = "o" ] ; then
	nvram set huaweidns_renum="0"
	[ -f $relock ] && rm -f $relock
	return 0
fi
if [ "$1" = "x" ] ; then
	if [ -f $relock ] ; then
		logger -t "【huaweidns】" "多次尝试启动失败，等待【"`cat $relock`"分钟】后自动尝试重新启动"
		exit 0
	fi
	huaweidns_renum=${huaweidns_renum:-"0"}
	huaweidns_renum=`expr $huaweidns_renum + 1`
	nvram set huaweidns_renum="$huaweidns_renum"
	if [ "$huaweidns_renum" -gt "2" ] ; then
		I=19
		echo $I > $relock
		logger -t "【huaweidns】" "多次尝试启动失败，等待【"`cat $relock`"分钟】后自动尝试重新启动"
		while [ $I -gt 0 ]; do
			I=$(($I - 1))
			echo $I > $relock
			sleep 60
			[ "$(nvram get huaweidns_renum)" = "0" ] && exit 0
			[ $I -lt 0 ] && break
		done
		nvram set huaweidns_renum="0"
	fi
	[ -f $relock ] && rm -f $relock
fi
nvram set huaweidns_status=0
eval "$scriptfilepath &"
exit 0
}

huaweidns_get_status () {

A_restart=`nvram get huaweidns_status`
B_restart="$huaweidns_enable$huaweidns_username$huaweidns_password$huaweidns_domian$huaweidns_host$huaweidns_domian2$huaweidns_host2huaweidns_domian6$huaweidns_host6$huaweidns_interval$(cat /etc/storage/ddns_script.sh | grep -v '^#' | grep -v "^$")"
B_restart=`echo -n "$B_restart" | md5sum | sed s/[[:space:]]//g | sed s/-//g`
if [ "$A_restart" != "$B_restart" ] ; then
	nvram set huaweidns_status=$B_restart
	needed_restart=1
else
	needed_restart=0
fi
}

huaweidns_check () {

huaweidns_get_status
if [ "$huaweidns_enable" != "1" ] && [ "$needed_restart" = "1" ] ; then
	[ ! -z "$(ps -w | grep "$scriptname keep" | grep -v grep )" ] && logger -t "【huaweidns动态域名】" "停止 huaweidns" && huaweidns_close
	{ kill_ps "$scriptname" exit0; exit 0; }
fi
if [ "$huaweidns_enable" = "1" ] ; then
	if [ "$needed_restart" = "1" ] ; then
		huaweidns_close
		eval "$scriptfilepath keep &"
		exit 0
	else
		[ -z "$(ps -w | grep "$scriptname keep" | grep -v grep )" ] || [ ! -s "`which curl`" ] && huaweidns_restart
	fi
fi
}

huaweidns_keep () {
get_token
get_Zone_ID
huaweidns_start
logger -t "【huaweidns动态域名】" "守护进程启动"
expires_time=1
while true; do
sleep 43
sleep $huaweidns_interval
expires_time=$(($expires_time + $huaweidns_interval +43))
[ $expires_time -gt 80000 ] && { expires_time=1; get_token;}
[ ! -s "`which curl`" ] && huaweidns_restart
#nvramshow=`nvram showall | grep '=' | grep huaweidns | awk '{print gensub(/'"'"'/,"'"'"'\"'"'"'\"'"'"'","g",$0);}'| awk '{print gensub(/=/,"='\''",1,$0)"'\'';";}'` && eval $nvramshow
huaweidns_enable=`nvram get huaweidns_enable`
[ "$huaweidns_enable" = "0" ] && huaweidns_close && exit 0;
if [ "$huaweidns_enable" = "1" ] ; then
	huaweidns_start
fi

done
}

huaweidns_close () {

kill_ps "/tmp/script/_huaweidns"
kill_ps "_huaweidns.sh"
kill_ps "$scriptname"
}

huaweidns_start () {
check_webui_yes
curltest=`which curl`
if [ -z "$curltest" ] || [ ! -s "`which curl`" ] ; then
	logger -t "【huaweidns动态域名】" "找不到 curl ，安装 opt 程序"
	/tmp/script/_mountopt optwget
	initopt
	curltest=`which curl`
	if [ -z "$curltest" ] || [ ! -s "`which curl`" ] ; then
		logger -t "【huaweidns动态域名】" "找不到 curl ，需要手动安装 opt 后输入[opkg update; opkg install curl]安装"
		logger -t "【huaweidns动态域名】" "启动失败, 10 秒后自动尝试重新启动" && sleep 10 && huaweidns_restart x
	else
		huaweidns_restart o
	fi
fi

IPv6=0
if [ "$huaweidns_domian"x != "x" ] && [ "$huaweidns_host"x != "x" ] ; then
	DOMAIN="$huaweidns_domian"
	HOST="$huaweidns_host"
	arDdnsCheck $huaweidns_domian $huaweidns_host
fi
if [ "$huaweidns_domian2"x != "x" ] && [ "$huaweidns_host2"x != "x" ] ; then
	sleep 1
	DOMAIN="$huaweidns_domian2"
	HOST="$huaweidns_host2"
	arDdnsCheck $huaweidns_domian2 $huaweidns_host2
fi
if [ "$huaweidns_domian6"x != "x" ] && [ "$huaweidns_host6"x != "x" ] ; then
	IPv6=1
	sleep 1
	DOMAIN="$huaweidns_domian6"
	HOST="$huaweidns_host6"
	arDdnsCheck $huaweidns_domian6 $huaweidns_host6
fi
}

token=""
get_token() {

versions="$(curl -L -k -s -X  GET \
https://dns.myhuaweicloud.com/ \
  -H 'content-type: application/json' \
   | grep -Eo '"id":"[^"]*"' | awk -F 'id":"' '{print $2}' | tr -d '"' |head -n1)"
[ "$versions" != "v2"] && logger -t "【huaweidns动态域名】" "错误！API的版本不是【v2】，请更新脚本后尝试重新启动" && sleep 10 && huaweidns_restart x

eval 'token_X="$(curl -L -k -s -D - -o /dev/null  -X POST \
  https://iam.myhuaweicloud.com/v3/auth/tokens \
  -H '"'"'content-type: application/json'"'"' \
  -d '"'"'{
    "auth": {
        "identity": {
            "methods": ["password"],
            "password": {
                "user": {
                    "name": "'$huaweidns_username'",
                    "password": "'$huaweidns_password'",
                    "domain": {
                        "name": "'$huaweidns_username'"
                    }
                }
            }
        },
        "scope": {
            "project": {
                "name": "cn-north-1"
            }
        }
    }
  }'"'"'| grep X-Subject-Token)"'
token="$(echo $token_X | awk -F ' ' '{print $2}')"
[ -z "$token" ] && logger -t "【huaweidns动态域名】" "错误！【token】获取失败，请检查用户名或密码后尝试重新启动" && sleep 10 && huaweidns_restart x

}

Zone_ID=""
get_Zone_ID() {
# 获得Zone_ID
Zone_ID="$(curl -L -k -s -X GET \
  https://dns.myhuaweicloud.com/v2/zones?name=$DOMAIN. \
  -H 'content-type: application/json' \
  -H 'X-Auth-Token: '$token)"
Zone_ID="$(echo $Zone_ID|grep -Eo "\"id\":\"[0-9a-z]*\",\"name\":\"$DOMAIN.\",\"description\""|grep -o "id\":\"[0-9a-z]*\""| awk -F : '{print $2}'|grep -o "[a-z0-9]*")"
[ -z "$Zone_ID" ] && logger -t "【huaweidns动态域名】" "错误！【Zone_ID】获取失败，请到华为云DNS手动创建公网域名后尝试重新启动" && sleep 10 && huaweidns_restart x

}

arDdnsInfo() {
case  $HOST  in
	  \*)
		HOST2="\\*"
		;;
	  \@)
		HOST2="@"
		;;
	  *)
		HOST2="$HOST"
		;;
esac

	if [ "$IPv6" = "1" ]; then
		domain_type="AAAA"
	else
		domain_type="A"
	fi
	Record_re="$(curl -L -k -s -X GET \
      https://dns.myhuaweicloud.com/v2.1/recordsets?name=$HOST2.$DOMAIN.\&type=$domain_type \
      -H 'content-type: application/json' \
      -H 'X-Auth-Token: '$token)"
	Record_ID="$(echo $Record_re|grep -o "\"id\":\"[0-9a-z]*\",\"name\":\"$HOST2.$DOMAIN.\",\"description\""|grep -o "id\":\"[0-9a-z]*\""| awk -F : '{print $2}'|grep -o "[a-z0-9]*")"
	# 检查是否有名称重复的子域名
	if [ "$(echo $Record_ID | grep -o "[0-9a-z]\{32,\}"| wc -l)" -gt "1" ] ; then
		logger -t "【huaweidns动态域名】" "$HOST.$DOMAIN 更新记录信息时发现重复的子域名！"
        for Delete_RECORD_ID in $Record_ID
        do
        logger -t "【huaweidns动态域名】" "$HOST.$DOMAIN 删除名称重复的子域名！ID: $Delete_RECORD_ID"
        RRecord_re="$(curl -L -k -s -X DELETE \
          https://dns.myhuaweicloud.com/v2.1/zones/$Zone_ID/recordsets/$Delete_RECORD_ID \
          -H 'content-type: application/json' \
          -H 'X-Auth-Token: '$token)"
        done
		Record_IP="0"
		echo $Record_IP
		return 0
	fi
	Record_IP="$(echo $Record_re |grep -Eo "\"records\":\[\"[^\"]+" | tr -d '"' | awk -F [ '{print $2}' |head -n1)"
	# Output IP
	if [ "$IPv6" = "1" ]; then
	echo $Record_IP
	return 0
	else
	case "$Record_IP" in 
	[1-9]*)
		echo $Record_IP
		return 0
		;;
	*)
		echo "Get Record Info Failed!"
		#logger -t "【huaweidns动态域名】" "获取记录信息失败！"
		return 1
		;;
	esac
	fi
}

# 查询域名地址
# 参数: 待查询域名
arNslookup() {
mkdir -p /tmp/arNslookup
nslookup $1 | tail -n +3 | grep "Address" | awk '{print $3}'| grep -v ":" | sed -n '1p' > /tmp/arNslookup/$$ &
I=5
while [ ! -s /tmp/arNslookup/$$ ] ; do
		I=$(($I - 1))
		[ $I -lt 0 ] && break
		sleep 1
done
killall nslookup
if [ -s /tmp/arNslookup/$$ ] ; then
cat /tmp/arNslookup/$$ | sort -u | grep -v "^$"
rm -f /tmp/arNslookup/$$
else
	curltest=`which curl`
	if [ -z "$curltest" ] || [ ! -s "`which curl`" ] ; then
		Address="`wget -T 5 -t 3 --no-check-certificate --quiet --output-document=- http://119.29.29.29/d?dn=$1`"
		if [ $? -eq 0 ]; then
		echo "$Address" |  sed s/\;/"\n"/g | sed -n '1p' | grep -E -o '([0-9]+\.){3}[0-9]+'
		fi
	else
		Address="`curl -k -s http://119.29.29.29/d?dn=$1`"
		if [ $? -eq 0 ]; then
		echo "$Address" |  sed s/\;/"\n"/g | sed -n '1p' | grep -E -o '([0-9]+\.){3}[0-9]+'
		fi
	fi
fi
}

arNslookup6() {
mkdir -p /tmp/arNslookup
nslookup $1 | tail -n +3 | grep "Address" | awk '{print $3}'| grep ":" | sed -n '1p' > /tmp/arNslookup/$$ &
I=5
while [ ! -s /tmp/arNslookup/$$ ] ; do
		I=$(($I - 1))
		[ $I -lt 0 ] && break
		sleep 1
done
killall nslookup
if [ -s /tmp/arNslookup/$$ ] ; then
	cat /tmp/arNslookup/$$ | sort -u | grep -v "^$"
	rm -f /tmp/arNslookup/$$
fi
}

# 更新记录信息
# 参数: 主域名 子域名
arDdnsUpdate() {
case  $HOST  in
	  \*)
		HOST2="\\*"
		;;
	  \@)
		HOST2="@"
		;;
	  *)
		HOST2="$HOST"
		;;
esac
	if [ "$IPv6" = "1" ]; then
		domain_type="AAAA"
	else
		domain_type="A"
	fi
I=3
Record_ID=""
while [ "$Record_ID" = "" ] ; do
    I=$(($I - 1))
    [ $I -lt 0 ] && break    # 获得记录ID
    Record_re="$(curl -L -k -s -X GET \
      https://dns.myhuaweicloud.com/v2.1/recordsets?name=$HOST2.$DOMAIN.\&type=$domain_type \
      -H 'content-type: application/json' \
      -H 'X-Auth-Token: '$token)"
    Record_ID="$(echo $Record_re|grep -o "\"id\":\"[0-9a-z]*\",\"name\":\"$HOST2.$DOMAIN.\",\"description\""|grep -o "id\":\"[0-9a-z]*\""| awk -F : '{print $2}'|grep -o "[a-z0-9]*")"
    echo "RECORD ID: $Record_ID"
done
    if [ "$Record_ID" = "" ] ; then
        # 添加子域名记录IP
        logger -t "【huaweidns动态域名】" "添加子域名 $HOST 记录IP"
        IP=$hostIP
        eval 'RESULT="$(curl -L -k -s -X POST \
          https://dns.myhuaweicloud.com/v2.1/zones/'$Zone_ID'/recordsets \
          -H '"'"'content-type: application/json'"'"' \
          -H '"'"'X-Auth-Token: '$token''"'"' \
          -d '"'"'{
            "name": "'$HOST2'.'$DOMAIN'.",
            "type": "'$domain_type'",
            "ttl": '$huaweidns_interval',
            "records": [
                "'$IP'"
            ]
          }'"'"')"'
        RESULT="$(echo $RESULT |grep -Eo "\"status\":\"[^\"]+" | tr -d '"' | awk -F : '{print $2}' |head -n1)"
    else
        # 更新记录IP
        IP=$hostIP
        eval 'RESULT="$(curl -L -k -s -X PUT \
          https://dns.myhuaweicloud.com/v2.1/zones/'$Zone_ID'/recordsets/'$Record_ID' \
          -H '"'"'content-type: application/json'"'"' \
          -H '"'"'X-Auth-Token: '$token''"'"' \
          -d '"'"'{
            "ttl": '$huaweidns_interval',
            "records": [
                "'$IP'"
            ]
          }'"'"')"'
        RESULT="$(echo $RESULT |grep -Eo "\"status\":\"[^\"]+" | tr -d '"' | awk -F : '{print $2}' |head -n1)"
    fi
    echo "$RESULT"

    # 输出记录IP
    if [ "$RESULT" = "PENDING_UPDATE" ];then
        echo "$(date) -- update success"
        return 0
    fi
    if [ "$RESULT" = "PENDING_CREATE" ];then
        echo "$(date) -- create success"
        return 0
    else 
        echo "$(date) -- UPDATE failed"
        return 1
    fi

}


# 动态检查更新
# 参数: 主域名 子域名
arDdnsCheck() {
	#local postRS
	#local lastIP
	source /etc/storage/ddns_script.sh
	hostIP=$arIpAddress
	hostIP=`echo $hostIP | head -n1 | cut -d' ' -f1`
	if [ -z $(echo "$hostIP" | grep : | grep -v "\.") ] && [ "$IPv6" = "1" ] ; then 
		IPv6=0
		logger -t "【huaweidns动态域名】" "错误！$hostIP 获取目前 IPv6 失败，请在脚本更换其他获取地址，保证取得IPv6地址(例如:ff03:0:0:0:0:0:0:c1)"
		return 1
	fi
	if [ "$hostIP"x = "x"  ] ; then
		curltest=`which curl`
		if [ -z "$curltest" ] || [ ! -s "`which curl`" ] ; then
			[ "$hostIP"x = "x"  ] && hostIP=`wget -T 5 -t 3 --no-check-certificate --quiet --output-document=- "ip.6655.com/ip.aspx" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1`
			[ "$hostIP"x = "x"  ] && hostIP=`wget -T 5 -t 3 --no-check-certificate --quiet --output-document=- "http://members.3322.org/dyndns/getip" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1`
			[ "$hostIP"x = "x"  ] && hostIP=`wget -T 5 -t 3 --no-check-certificate --quiet --output-document=- "ip.3322.net" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1`
			[ "$hostIP"x = "x"  ] && hostIP=`wget -T 5 -t 3 --no-check-certificate --quiet --output-document=- "https://www.ipip.net/" | grep "IP地址" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1`
		else
			[ "$hostIP"x = "x"  ] && hostIP=`curl -L -k -s ip.6655.com/ip.aspx | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1`
			[ "$hostIP"x = "x"  ] && hostIP=`curl -L -k -s "http://members.3322.org/dyndns/getip" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1`
			[ "$hostIP"x = "x"  ] && hostIP=`curl -L -k -s ip.3322.net | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1`
			[ "$hostIP"x = "x"  ] && hostIP=`curl -L -k -s "https://www.ipip.net" | grep "IP地址" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1`
		fi
		if [ "$hostIP"x = "x"  ] ; then
			logger -t "【huaweidns动态域名】" "错误！获取目前 IP 失败，请在脚本更换其他获取地址"
			return 1
		fi
	fi
	echo "Updating Domain: $HOST.$DOMAIN"
	echo "hostIP: ${hostIP}"
	lastIP=$(arDdnsInfo "$DOMAIN" "$HOST")
	if [ $? -eq 1 ]; then
		[ "$IPv6" != "1" ] && lastIP=$(arNslookup "$HOST.$DOMAIN")
		[ "$IPv6" = "1" ] && lastIP=$(arNslookup6 "$HOST.$DOMAIN")
	fi
	echo "lastIP: ${lastIP}"
	if [ "$lastIP" != "$hostIP" ] ; then
		logger -t "【huaweidns动态域名】" "开始更新 $HOST.$DOMAIN 域名 IP 指向"
		logger -t "【huaweidns动态域名】" "目前 IP: ${hostIP}"
		logger -t "【huaweidns动态域名】" "上次 IP: ${lastIP}"
		sleep 1
		postRS=$(arDdnsUpdate "$DOMAIN" "$HOST")
		if [ $? -eq 0 ]; then
			echo "postRS: ${postRS}"
			logger -t "【huaweidns动态域名】" "更新动态DNS记录成功！"
			return 0
		else
			echo ${postRS}
			logger -t "【huaweidns动态域名】" "更新动态DNS记录失败！请检查您的网络。"
			if [ "$IPv6" = "1" ] ; then 
				IPv6=0
				logger -t "【huaweidns动态域名】" "错误！$hostIP 获取目前 IPv6 失败，请在脚本更换其他获取地址，保证取得IPv6地址(例如:ff03:0:0:0:0:0:0:c1)"
				return 1
			fi
			return 1
		fi
	fi
	echo ${lastIP}
	echo "Last IP is the same as current IP!"
	return 1
}

initopt () {
optPath=`grep ' /opt ' /proc/mounts | grep tmpfs`
[ ! -z "$optPath" ] && return
if [ ! -z "$(echo $scriptfilepath | grep -v "/opt/etc/init")" ] && [ -s "/opt/etc/init.d/rc.func" ] ; then
	{ echo '#!/bin/sh' ; echo $scriptfilepath '"$@"' '&' ; } > /opt/etc/init.d/$scriptname && chmod 777  /opt/etc/init.d/$scriptname
fi

}

initconfig () {

if [ ! -s "/etc/storage/ddns_script.sh" ] ; then
cat > "/etc/storage/ddns_script.sh" <<-\EEE
# 自行测试哪个代码能获取正确的IP，删除前面的#可生效
arIpAddress () {
# IPv4地址获取
# 获得外网地址
curltest=`which curl`
if [ -z "$curltest" ] || [ ! -s "`which curl`" ] ; then
    #wget -T 5 -t 3 --no-check-certificate --quiet --output-document=- "https://www.ipip.net" | grep "IP地址" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1
    wget -T 5 -t 3 --no-check-certificate --quiet --output-document=- "http://members.3322.org/dyndns/getip" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1
    #wget -T 5 -t 3 --no-check-certificate --quiet --output-document=- "ip.6655.com/ip.aspx" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1
    #wget -T 5 -t 3 --no-check-certificate --quiet --output-document=- "ip.3322.net" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1
else
    #curl -L -k -s "https://www.ipip.net" | grep "IP地址" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1
    curl -L -k -s "http://members.3322.org/dyndns/getip" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1
    #curl -L -k -s ip.6655.com/ip.aspx | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1
    #curl -L -k -s ip.3322.net | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1
fi
}
arIpAddress6 () {
# IPv6地址获取
# 因为一般ipv6没有nat ipv6的获得可以本机获得
ifconfig $(nvram get wan0_ifname_t) | awk '/Global/{print $3}' | awk -F/ '{print $1}'
}
if [ "$IPv6" = "1" ] ; then
arIpAddress=$(arIpAddress6)
else
arIpAddress=$(arIpAddress)
fi
EEE
	chmod 755 "$ddns_script"
fi

}

initconfig

case $ACTION in
start)
	huaweidns_close
	huaweidns_check
	;;
check)
	huaweidns_check
	;;
stop)
	huaweidns_close
	;;
keep)
	huaweidns_keep
	;;
*)
	huaweidns_check
	;;
esac


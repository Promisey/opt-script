#!/bin/sh
#copyright by hiboy
#一键自动更新固件脚本
#wget --no-check-certificate -O- https://opt.cn2qq.com/opt-script/up.sh | sed -e "s|^\(Firmware.*\)=[^=]*$|\1=|" > /tmp/up.sh && bash < /tmp/up.sh
logger_echo () {
    logger -t "【Firmware】" "$1"
    echo "$(date "+%Y-%m-%d_%H-%M-%S") ""$1"
}
if [ -f /tmp/up_Firmware ] ; then
    logger_echo " 上次更新未完成，跳过更新！稍等几分钟可再次尝试更新！"
    exit
fi
touch /tmp/up_Firmware
export LD_LIBRARY_PATH=/lib:/opt/lib
Firmware=""
mkdir -p /tmp/padavan
rm -f /tmp/padavan/*
wget --no-check-certificate  -O /tmp/padavan/MD5.txt https://opt.cn2qq.com/padavan/MD5.txt
dos2unix /tmp/padavan/MD5.txt
if [ "$Firmware"x = "x" ] ; then
PN=`grep Web_Title= /www/EN.dict | sed 's/Web_Title=//g'| sed 's/ 无线路由器\| Wireless Router//g'`
[ "$PN"x != "x" ] && Firmware=`cat /tmp/padavan/MD5.txt | grep -Eo "$PN"'_.*' | sed -n '1p'`
fi
MD5_txt=`cat /tmp/padavan/MD5.txt | sed 's@\r@@g' |sed -n '/'$Firmware'/,/CRC32/{/'$Firmware'/n;/CRC32/b;p}' | grep "MD5：" | tr 'A-Z' 'a-z' |awk '{print $2}'`
if [ "$MD5_txt"x = x ] ; then
    logger_echo " 未能获取【https://opt.cn2qq.com/padavan/MD5.txt】记录，跳过更新！可再次尝试更新！"
else
logger_echo " 下载【$Firmware】，https://opt.cn2qq.com/padavan/$Firmware"
size_tmpfs=`nvram get size_tmpfs`
[ -z $size_tmpfs ] && size_tmpfs="0"
[ "$size_tmpfs" = "0" ] && mount -o remount,size=50% tmpfs /tmp
# 备份reboot的lib
eval $(ldd /sbin/reboot |cut -d'>' -f2 | cut -d' ' -f2 | awk '{print "cp "$1" /tmp/padavan/ ;";}')
wget --no-check-certificate  -O /tmp/padavan/$Firmware https://opt.cn2qq.com/padavan/$Firmware
eval $(md5sum /tmp/padavan/$Firmware | awk '{print "MD5_down="$1;}')
echo $MD5_down
echo $MD5_txt
if [ -s /tmp/padavan/$Firmware ] && [ "$MD5_txt"x = "$MD5_down"x ] ; then
    logger_echo " 下载【$Firmware】，md5匹配，开始更新！请勿断电！"
    mtd_write -r write /tmp/padavan/$Firmware Firmware_Stub  > /tmp/padavan/log.txt  2>&1
    mtd_log=`cat /tmp/padavan/log.txt | grep -Eo '\[ok\]'`
    if [ -s /tmp/padavan/log.txt ] && [ "$mtd_log"x = '[ok]x' ] ; then
        logger_echo " 更新【$Firmware】，[ok]！"
        logger_echo " 稍等【$Firmware】，自动重启！"
        logger_echo " 出现[ok]！为刷入成功，自动重启路由"
        export LD_LIBRARY_PATH=/tmp/padavan
        /sbin/reboot
        logger_echo "如果自动重启失败可尝试手动重启路由"
    else
        logger_echo "`cat /tmp/padavan/log.txt`"
        logger_echo " 出错【$Firmware】，更新失败！"
    fi
else
    logger_echo " 下载【$Firmware】，md5与记录不同，下载失败，跳过更新！可重启后再次尝试更新！"
    logger_echo " 下载md5: $MD5_down"
    logger_echo " 记录md5: $MD5_txt"
fi
fi
rm -f /tmp/up_Firmware


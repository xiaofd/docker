#/bin/hello&
[[ -z $CF_Domain ]] && echo -n "Enter Domain:" && read CF_Domain
[[ -z $CF_Token ]] && echo -n "CF_Token:" && read CF_Token
PORT="$XRAY_Port"

xray_conf_dir="/etc/xray"
mkdir -p "$xray_conf_dir"
[[ ! -f "$xray_conf_dir"/xray ]] && cp /bin/xrayb "$xray_conf_dir"/xray \
&& wget -O "$xray_conf_dir"/geosite.dat https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat \
&& wget -O "$xray_conf_dir"/geoip.dat https://github.com/v2fly/geoip/releases/latest/download/geoip.dat
[[ ! -f "$xray_conf_dir"/config.json ]] && cp /bin/config.json "$xray_conf_dir"/ && config_new="true"
echo "0 12 * * * wget -O ${xray_conf_dir}/geosite.dat https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat" >> /etc/crontabs/root
echo "10 12 * * * wget -O ${xray_conf_dir}/geoip.dat https://github.com/v2fly/geoip/releases/latest/download/geoip.dat" >> /etc/crontabs/root

# qrencode -l H 参数 可以纠错，生成图片稍大
# qrencode -o- -l H "12345645gsdfgsdfsdf" -t UTF8
# echo "12345645gsdfgsdfsdf" | qrencode -o- -l H -t UTF8
apk add --no-cache jq libqrencode curl openssl

UUID=$(cat /proc/sys/kernel/random/uuid)
#WS_PATH='/'$(head -n 10 /dev/urandom | md5sum | head -c $((RANDOM % 12 + 4)))'/'
WS_PATH_NOSPLASH=$(head -n 10 /dev/urandom | md5sum | head -c $((RANDOM % 12 + 4)))
WS_PATH='/'${WS_PATH}'/'

if [[ ! -f "$xray_conf_dir"/xray.crt ]];then
curl -L https://get.acme.sh | sh
# "$HOME"/.acme.sh/acme.sh --set-default-ca --server letsencrypt
"$HOME"/.acme.sh/acme.sh --set-default-ca --server zerossl
"$HOME"/.acme.sh/acme.sh --register-account -m admin@google.com
# can not use
# [[ -z $CF_Token ]] && "$HOME"/.acme.sh/acme.sh --issue -d "${CF_Domain}" --webroot "$website_dir" -k ec-256 --force
[[ -n $CF_Token ]] && "$HOME"/.acme.sh/acme.sh --issue -d "${CF_Domain}" --dns dns_cf -k ec-256 --force
"$HOME"/.acme.sh/acme.sh --installcert --ecc -d "${CF_Domain}" --fullchainpath "${xray_conf_dir}"/xray.crt --keypath "${xray_conf_dir}"/xray.key
# cp "$HOME"/.acme.sh/"${CF_Domain}*"/fullchain.cer "${xray_conf_dir}"/xray.crt
# cp "$HOME"/.acme.sh/"${CF_Domain}*"/"${CF_Domain}".key "${xray_conf_dir}"/xray.key
fi

if [[ -n "$config_new" ]];then
#cat ${xray_conf_dir}/config.json | jq 'setpath(["inbounds",0,"settings","clients",0,"id"];"'${UUID}'")' >${xray_conf_dir}/config.json
#cat ${xray_conf_dir}/config.json | jq 'setpath(["inbounds",1,"settings","clients",0,"id"];"'${UUID}'")' >${xray_conf_dir}/config.json
#cat ${xray_conf_dir}/config.json | jq 'setpath(["inbounds",0,"settings","fallbacks",2,"path"];"'${WS_PATH}'")' >${xray_conf_dir}/config.json
#cat ${xray_conf_dir}/config.json | jq 'setpath(["inbounds",1,"streamSettings","wsSettings","path"];"'${WS_PATH}'")' >${xray_conf_dir}/config.json
#cat ${xray_conf_dir}/config.json | 
#jq 'setpath(["inbounds",0,"settings","clients",0,"id"];"'${UUID}'")' | 
#jq 'setpath(["inbounds",1,"settings","clients",0,"id"];"'${UUID}'")' | 
#jq 'setpath(["inbounds",0,"settings","fallbacks",2,"path"];"'${WS_PATH}'")' | 
#jq 'setpath(["inbounds",1,"streamSettings","wsSettings","path"];"'${WS_PATH}'")' >${xray_conf_dir}/config_temp.json
#mv ${xray_conf_dir}/config_temp.json ${xray_conf_dir}/config.json

sed -i "s/xx-port/${PORT}/g" ${xray_conf_dir}/config.json
sed -i "s/xx-uuid/${UUID}/g" ${xray_conf_dir}/config.json
sed -i "s/xx-path/${WS_PATH_NOSPLASH}/g" ${xray_conf_dir}/config.json

fi

UUID=$(cat ${xray_conf_dir}/config.json | jq .inbounds[0].settings.clients[0].id | tr -d '"')
PORT=$(cat ${xray_conf_dir}/config.json | jq .inbounds[0].port)
FLOW=$(cat ${xray_conf_dir}/config.json | jq .inbounds[0].settings.clients[0].flow | tr -d '"')
WS_PATH=$(cat ${xray_conf_dir}/config.json | jq .inbounds[0].settings.fallbacks[1].path | tr -d '"')
WS_PATH_WITHOUT_SLASH=$(echo $WS_PATH | tr -d '/')
DOMAIN=${CF_Domain}

#echo "URL 链接 (VLESS + TCP + TLS)"
#echo "vless://$UUID@$DOMAIN:$PORT?security=tls#TLS-$DOMAIN"
#echo "vless://$UUID@$DOMAIN:$PORT?security=tls#TLS-$DOMAIN" | qrencode -o- -t UTF8
#echo "URL 链接 (VLESS + TCP + XTLS)"
#echo "vless://$UUID@$DOMAIN:$PORT?security=xtls&flow=$FLOW#XTLS-$DOMAIN"
#echo "vless://$UUID@$DOMAIN:$PORT?security=xtls&flow=$FLOW#XTLS-$DOMAIN" | qrencode -o- -t UTF8
echo "URL 链接 (VLESS + WebSocket + TLS)"
echo "vless://$UUID@$DOMAIN:$PORT?type=ws&security=tls&path=%2f${WS_PATH_WITHOUT_SLASH}#WS_TLS-$DOMAIN"
echo "vless://$UUID@$DOMAIN:$PORT?type=ws&security=tls&path=%2f${WS_PATH_WITHOUT_SLASH}#WS_TLS-$DOMAIN" | qrencode -o- -t UTF8
echo "URL 链接(CDN)"
echo "vless://${UUID}@www.csgo.com:${PORT}?path=%2F${WS_PATH_WITHOUT_SLASH}&security=tls&encryption=none&host=${DOMAIN}&fp=random&type=ws&sni=${DOMAIN}#WS_TLS-${DOMAIN}"
echo "vless://${UUID}@www.csgo.com:${PORT}?path=%2F${WS_PATH_WITHOUT_SLASH}&security=tls&encryption=none&host=${DOMAIN}&fp=random&type=ws&sni=${DOMAIN}#WS_TLS-${DOMAIN}" | qrencode -o- -t UTF8

#"$xray_conf_dir"/xray --config "$xray_conf_dir"/config.json
#/bin/xray --config "$xray_conf_dir"/config.json
#/bin/sh
crontab -l

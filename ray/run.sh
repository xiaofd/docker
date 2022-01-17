echo -n "Enter Domain:"
read ray_domain

xray_conf_dir="/etc/xray"
mkdir -p "$xray_conf_dir"
cp /bin/xray "$xray_conf_dir"/
cp /bin/config.json "$xray_conf_dir"/

# qrencode -l H 参数 可以纠错，生成图片稍大
# qrencode -o- -l H "12345645gsdfgsdfsdf" -t UTF8
# echo "12345645gsdfgsdfsdf" | qrencode -o- -l H -t UTF8
apk add --no-cache jq libqrencode curl openssl

UUID=$(cat /proc/sys/kernel/random/uuid)
WS_PATH='/'$(head -n 10 /dev/urandom | md5sum | head -c $((RANDOM % 12 + 4)))'/'
PORT=443

curl -L https://get.acme.sh | sh
# "$HOME"/.acme.sh/acme.sh --set-default-ca --server letsencrypt
"$HOME"/.acme.sh/acme.sh --set-default-ca --server zerossl
"$HOME"/.acme.sh/acme.sh --register-account -m admin@google.com
# can not use
# [[ -z $CF_Token ]] && "$HOME"/.acme.sh/acme.sh --issue -d "${ray_domain}" --webroot "$website_dir" -k ec-256 --force
[[ -z $CF_Token ]] && echo "CF_Token:" && read CF_Token
[[ -n $CF_Token ]] && "$HOME"/.acme.sh/acme.sh --issue -d "${ray_domain}" --dns dns_cf -k ec-256 --force
"$HOME"/.acme.sh/acme.sh --installcert --ecc -d "${ray_domain}" --fullchainpath "${xray_conf_dir}"/xray.crt --keypath "${xray_conf_dir}"/xray.key
# cp "$HOME"/.acme.sh/"${ray_domain}*"/fullchain.cer "${xray_conf_dir}"/xray.crt
# cp "$HOME"/.acme.sh/"${ray_domain}*"/"${ray_domain}".key "${xray_conf_dir}"/xray.key


#cat ${xray_conf_dir}/config.json | jq 'setpath(["inbounds",0,"settings","clients",0,"id"];"'${UUID}'")' >${xray_conf_dir}/config.json
#cat ${xray_conf_dir}/config.json | jq 'setpath(["inbounds",1,"settings","clients",0,"id"];"'${UUID}'")' >${xray_conf_dir}/config.json
#cat ${xray_conf_dir}/config.json | jq 'setpath(["inbounds",0,"settings","fallbacks",2,"path"];"'${WS_PATH}'")' >${xray_conf_dir}/config.json
#cat ${xray_conf_dir}/config.json | jq 'setpath(["inbounds",1,"streamSettings","wsSettings","path"];"'${WS_PATH}'")' >${xray_conf_dir}/config.json
cat ${xray_conf_dir}/config.json | 
jq 'setpath(["inbounds",0,"settings","clients",0,"id"];"'${UUID}'")' | 
jq 'setpath(["inbounds",1,"settings","clients",0,"id"];"'${UUID}'")' | 
jq 'setpath(["inbounds",0,"settings","fallbacks",2,"path"];"'${WS_PATH}'")' | 
jq 'setpath(["inbounds",1,"streamSettings","wsSettings","path"];"'${WS_PATH}'")' >${xray_conf_dir}/config_temp.json
mv ${xray_conf_dir}/config_temp.json ${xray_conf_dir}/config.json

UUID=$(cat ${xray_conf_dir}/config.json | jq .inbounds[0].settings.clients[0].id | tr -d '"')
PORT=$(cat ${xray_conf_dir}/config.json | jq .inbounds[0].port)
FLOW=$(cat ${xray_conf_dir}/config.json | jq .inbounds[0].settings.clients[0].flow | tr -d '"')
WS_PATH=$(cat ${xray_conf_dir}/config.json | jq .inbounds[0].settings.fallbacks[2].path | tr -d '"')
WS_PATH_WITHOUT_SLASH=$(echo $WS_PATH | tr -d '/')
DOMAIN=${ray_domain}

echo "URL 链接 (VLESS + TCP + TLS)"
echo "vless://$UUID@$DOMAIN:$PORT?security=tls#TLS-$DOMAIN"
echo "vless://$UUID@$DOMAIN:$PORT?security=tls#TLS-$DOMAIN" | qrencode -o- -t UTF8
echo "URL 链接 (VLESS + TCP + XTLS)"
echo "vless://$UUID@$DOMAIN:$PORT?security=xtls&flow=$FLOW#XTLS-$DOMAIN"
echo "vless://$UUID@$DOMAIN:$PORT?security=xtls&flow=$FLOW#XTLS-$DOMAIN" | qrencode -o- -t UTF8
echo "URL 链接 (VLESS + WebSocket + TLS)"
echo "vless://$UUID@$DOMAIN:$PORT?type=ws&security=tls&path=%2f${WS_PATH_WITHOUT_SLASH}%2f#WS_TLS-$DOMAIN"
echo "vless://$UUID@$DOMAIN:$PORT?type=ws&security=tls&path=%2f${WS_PATH_WITHOUT_SLASH}%2f#WS_TLS-$DOMAIN" | qrencode -o- -t UTF8

"$xray_conf_dir"/xray --config "$xray_conf_dir"/config.json

/bin/sh

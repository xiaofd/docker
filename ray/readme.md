docker run -it --name=ray -e CF_Token="" -e CF_Domain="" --network=host -v /etc/xray:/etc/xray --restart=always xiaofd/ray
docker run -it --name=ray --network=host --restart=always -v /etc/xray:/etc/xray -e CF_Domain="" -e XRAY_Port=443 xiaofd/ray:vision


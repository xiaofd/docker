docker run -it --name=ray -e CF_Token="" -e CF_Domain="" --network=host -v /etc/xray:/etc/xray --restart=always xiaofd/ray


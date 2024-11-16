## 以下用于支持UPNP
```
# 配置 NAT
sudo iptables -t nat -A POSTROUTING -o ens18 -j MASQUERADE

# 配置内网流量
sudo iptables -A FORWARD -i br-d41eddbf0c23 -o ens18 -j ACCEPT
sudo iptables -A FORWARD -i ens18 -o br-d41eddbf0c23 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i br-01ba68f251d6 -o ens18 -j ACCEPT
sudo iptables -A FORWARD -i ens18 -o br-01ba68f251d6 -m state --state RELATED,ESTABLISHED -j ACCEPT


sudo apt update
sudo apt install miniupnpd

```
```
# 增加配置文件 /etc/miniupnpd/miniupnpd.conf
listening_ip=ens18
listening_ip=br-d41eddbf0c23
listening_ip=br-01ba68f251d6
ext_ifname=ens18

enable_natpmp=yes
enable_upnp=yes
secure_mode=yes

allow 50000-65535 192.168.1.0/24 50000-65535
allow 50000-65535 192.168.2.0/24 50000-65535
deny 0-65535 0.0.0.0/0 0-65535
```
```
# 后即可支持UPNP
sudo systemctl restart miniupnpd
sudo systemctl enable miniupnpd
```

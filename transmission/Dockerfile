# docker run -it -p 9091:9091 -p 51413:51413 -e USER=xiaofd -e PASS=xiaofd.win xiaofd/transmission

FROM ubuntu:16.04
MAINTAINER xiaofd <xiaofd@jun.ac.cn>

# install ubuntu sshd
RUN apt-get update && \
	apt-get clean  && \
        apt-get install -y apt-utils && \
	apt-get install -y openssh-server wget dpkg apt-utils --no-install-recommends && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*
	
RUN mkdir /var/run/sshd && \
	echo 'root:root' | chpasswd && \
	sed -ri 's/^PermitRootLogin\s+.*/PermitRootLogin yes/' /etc/ssh/sshd_config && \ 
	sed -ri 's/UsePAM yes/#UsePAM yes/g' /etc/ssh/sshd_config

ENV USER=xiaofd
ENV PASS=xiaofd.win

# install 
RUN apt-get update && \
	apt-get clean  && \
        wget --no-check-certificate -O /root/transmission.sh xiaofd.github.io/transmission.sh && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

RUN cd /root && \
  echo "#!/bin/bash" > run.sh && \
  echo 'bash /root/transmission.sh -u $USER -p $PASS' >> run.sh && \
  echo 'service transmission-daemon start' >> run.sh && \
  echo "/usr/sbin/sshd -D" >> run.sh && \
  chmod +x run.sh

EXPOSE 22 9091 51413

CMD    ["/root/run.sh"]

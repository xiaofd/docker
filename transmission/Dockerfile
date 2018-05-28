# ubuntu_python3_redis_requests
# download a py file and run
# docker run -it -p 9091:9091 -e USER=xiaofd -e PASS=xiaofd.win xiaofd/transmission
# export ENV PYFILE

FROM ubuntu:16.04
MAINTAINER xiaofd <xiaofd@jun.ac.cn>

# install ubuntu sshd
RUN apt-get update && \
	apt-get clean  && \
	apt-get install -y openssh-server wget  --no-install-recommends && \
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

EXPOSE 22 9091

CMD    ["/root/run.sh"]

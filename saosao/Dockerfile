# ubuntu_ssr
# docker run -it -e PYFILE=pan.xiaofd.win/hello2.py  xiaofd/conda_run
# export ENV PYFILE

FROM ubuntu:16.04
MAINTAINER xiaofd <xiaofd@jun.ac.cn>

# install ubuntu sshd
RUN apt-get update && \
	apt-get clean  && \
	apt-get install -y openssh-server wget unzip --no-install-recommends && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*
	
RUN mkdir /var/run/sshd && \
	echo 'root:root' | chpasswd && \
	sed -ri 's/^PermitRootLogin\s+.*/PermitRootLogin yes/' /etc/ssh/sshd_config && \ 
	sed -ri 's/UsePAM yes/#UsePAM yes/g' /etc/ssh/sshd_config

# install 
ENV P=xiaofd.win
ENV M=chacha20
ENV X=auth_sha1_v4
ENV H=http_simple

COPY ssr.zip .
RUN unzip ssr.zip && cd SSR* && \
        bash install.sh 

RUN cd /root && \
  echo "#!/bin/bash" > run.sh && \
  echo 'cd /usr/local/shadowsocksr/ && python mujson_mgr.py -a -u xiaofd -p 8080 -k $P -m $M -O "$X""_compatible" -o "$H"_"compatible"' >> run.sh && \
  echo 'bash /usr/local/shadowsocksr/logrun.sh' >> run.sh && \
  #echo '/etc/init.d/ssh stop &' >> run.sh && \
  echo "/usr/sbin/sshd -D" >> run.sh && \
  chmod +x run.sh

EXPOSE 22 8080

CMD    ["/root/run.sh"]

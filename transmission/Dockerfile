# ubuntu_python3_redis_requests
# download a py file and run
# docker run -it -e PYFILE=pan.xiaofd.win/hello2.py  daocloud.io/405102091/python_run
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

# install 
RUN apt-get update && \
	apt-get clean  && \
        wget --no-check-certificate xiaofd.github.io/transmission.sh && bash transmission.sh && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

#RUN export PATH=/opt/conda/bin:$PATH && pip install -U pip requests redis

ENV PYFILE=pan.xiaofd.win/hello.py
ENV PATH=/opt/conda/bin:$PATH
RUN cd /root && \
  echo "#!/bin/bash" > run.sh && \
  echo 'service transmission-daemon start' >> run.sh && \
  #echo 'tmux new-session -d "/usr/bin/python3 run.py 2>&1"' >> run.sh && \
  #echo '/etc/init.d/ssh stop &' >> run.sh && \
  echo "/usr/sbin/sshd -D" >> run.sh && \
  chmod +x run.sh

EXPOSE 22 9091

CMD    ["/root/run.sh"]

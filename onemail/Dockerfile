FROM ubuntu:16.04
MAINTAINER xiaofd <xiaofd@jun.ac.cn>

ENV LANG C.UTF-8

RUN sed -i "s/^exit 101$/exit 0/" /usr/sbin/policy-rc.d && \
    apt-get update && apt-get install -y python3 redis-server python3-chardet python3-redis python3-flask && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY onestmp.py oneweb.py /root

RUN cd /root && \
  echo "#!/bin/bash" > run.sh && \
  echo 'python3 oneweb.py' >> run.sh
  chmod +x run.sh

EXPOSE 25 80

CMD ["/root/run.sh"]

# run py file
# docker run -it --rm -v /pyapp:/python -e PYFILE=test.py xiaofd/python:3.8
# # not use # docker run -it --rm -v /pyapp:/python xiaofd/python:3.8 python test.py
# debian 11
FROM python:3.8-slim 
MAINTAINER xiaofd <xiaofd@jun.ac.cn>

RUN mkdir /python && \
    pip --no-cache-dir install pipreqs 

ENV PYFILE=test.py

RUN cd /root && \
  echo "#!/bin/bash" > /run.sh && \
  echo 'pipreqs /python --encoding=utf-8 --force' >> /run.sh && \
  echo 'pip3 install -r /python/requirements.txt' >> /run.sh && \
  echo 'python /python/"$PYFILE"' >> /run.sh && \
  chmod +x /run.sh

#CMD ["/bin/bash"]
CMD ["/run.sh"]

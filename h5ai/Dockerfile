# FROM ubuntu:20.04
FROM debian:bullseye-slim
MAINTAINER xiaofd <jun@jun.ac.cn>

RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y \
  nginx php php-fpm supervisor \
  php-gd php-exif ffmpeg imagemagick \
  wget unzip patch

# install h5ai and patch configuration
COPY h5ai-0.30.0.zip .
RUN unzip h5ai-0.30.0.zip -d /usr/share/h5ai

#patch base dir
RUN sed -i "s#\$this->set('ROOT_PATH', Util::normalize_path(dirname(\$this->get('H5AI_PATH')), false))#\$this->set('ROOT_PATH', '/var/www')#g" /usr/share/h5ai/_h5ai/private/php/core/class-setup.php
ADD options.json.patch options.json.patch
RUN patch -p1 -u -d /usr/share/h5ai/_h5ai/private/conf/ -i /options.json.patch && rm options.json.patch

# add h5ai as the only nginx site
COPY default /etc/nginx/sites-available/default

RUN mkdir -p /run/php
WORKDIR /var/www

# add dummy files in case the container is not run with a volume mounted to /var/www

RUN echo "Looks like you did not mount a volume to `/var/www`. See README.md for details." > /var/www/INSTALL.md
RUN mkdir -p /var/www/first/second/third/fourth/fifth
ADD README.md /var/www/README.md

# use supervisor to monitor all services
ADD supervisord.conf /etc/supervisor/conf.d/supervisord.conf
CMD supervisord -c /etc/supervisor/conf.d/supervisord.conf

# expose only nginx HTTP port
EXPOSE 80

# expose path
VOLUME /var/www

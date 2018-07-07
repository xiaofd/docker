FROM ubuntu:16.04
MAINTAINER xiaofd <xiaofd@jun.ac.cn>

RUN sed -i "s/^exit 101$/exit 0/" /usr/sbin/policy-rc.d && \
    apt-get update && apt-get install -y curl wget git nginx php php-fpm php-curl cron && \
    wget -O /etc/nginx/sites-available/default xiaofd.github.io/others/nginx-php && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN rm -rf /var/www/html/* && \
    git clone https://github.com/donwa/oneindex.git /var/www/html/ && \
    chmod -R 0755 /var/www/html/* && \
    chmod -R 0777 /var/www/html/cache && \
    chmod -R 0777 /var/www/html/config

RUN cd /root && \
  echo "# token every 1 hour" > one-cron && \
  echo "0 * * * * root /usr/bin/php /var/www/html/one.php token:refresh" >> one-cron && \
  echo "# cache every 1 minute" >> one-cron && \
  echo "*/1 * * * * root /usr/bin/php /var/www/html/one.php cache:refresh" >> one-cron && \
  cp one-cron /etc/cron.d/one-cron && \
  chmod 0644 /etc/cron.d/one-cron && \
  echo "#!/bin/bash" > run.sh && \
  echo 'cron # cron -f # foreground' >> run.sh && \
  echo '/etc/init.d/php7.0-fpm restart && nginx -g "daemon off;"' >> run.sh && \
  chmod +x run.sh

EXPOSE 80

CMD ["/root/run.sh"]

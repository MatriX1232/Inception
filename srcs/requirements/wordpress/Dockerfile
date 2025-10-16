FROM debian:bullseye-slim

RUN apt-get update && apt-get install -y \
    php-fpm \
    php-mysql \
    curl \
    unzip \
    mariadb-client \
 && rm -rf /var/lib/apt/lists/*

RUN sed -i 's/listen = \/run\/php\/php7.4-fpm.sock/listen = 0.0.0.0:9000/' /etc/php/7.4/fpm/pool.d/www.conf

COPY ./tools/wp-cli.phar /usr/local/bin/wp
COPY ./tools/setup_wordpress.sh /usr/local/bin/setup_wordpress.sh

RUN chmod +x /usr/local/bin/wp /usr/local/bin/setup_wordpress.sh

WORKDIR /var/www/html

EXPOSE 9000

ENTRYPOINT [ "/usr/local/bin/setup_wordpress.sh" ]
CMD [ "php-fpm7.4", "-F" ]
FROM debian:bullseye

RUN apt update -y && apt install -y php-fpm php-mysqli curl
RUN apt clean

RUN rm -rf /var/lib/apt/lists/*

COPY tools/www.conf /etc/php/7.4/fpm/pool.d/www.conf

COPY tools/wordpress.sh /usr/local/bin/wordpress.sh

RUN chmod +x /usr/local/bin/wordpress.sh

CMD ["/usr/local/bin/wordpress.sh"]
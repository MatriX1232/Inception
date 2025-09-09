FROM debian:bullseye

RUN apt update && apt upgrade -y && apt install -y nginx
RUN apt install -y openssl

ARG DOMAIN_NAME
ENV DOMAIN_NAME=${DOMAIN_NAME}

RUN mkdir -p /etc/nginx/ssl

RUN openssl req -x509 -nodes -days 365 -keyout /etc/nginx/ssl/inception.key -out /etc/nginx/ssl/inception.crt -subj "/CN=${DOMAIN_NAME}"

RUN mkdir -p /var/www/wordpress /var/run/nginx

RUN chmod 755 /var/www/wordpress

RUN chown -R www-data:www-data /var/www/wordpress

COPY ./tools/nginx.conf /etc/nginx/nginx.conf

CMD ["nginx", "-g", "daemon off;"]

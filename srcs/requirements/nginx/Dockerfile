FROM debian:bullseye-slim

ARG DOMAIN_NAME

RUN apt-get update && \
    apt-get install -y --no-install-recommends nginx openssl gettext-base && \
    rm -rf /var/lib/apt/lists/*

COPY ./tools/generate_cert.sh /usr/local/bin/generate_cert.sh
RUN chmod +x /usr/local/bin/generate_cert.sh

# Run certificate generation at build time using the build ARG DOMAIN_NAME
RUN DOMAIN_NAME=${DOMAIN_NAME} /usr/local/bin/generate_cert.sh

RUN mkdir -p /etc/nginx/templates
COPY ./conf/nginx.conf /etc/nginx/templates/nginx.conf.template

EXPOSE 443

CMD ["/bin/bash", "-c", "envsubst '${DOMAIN_NAME}' < /etc/nginx/templates/nginx.conf.template > /etc/nginx/nginx.conf && nginx -g 'daemon off;'"]
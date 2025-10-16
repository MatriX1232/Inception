FROM debian:bullseye-slim

# Install MariaDB and clean up apt lists to keep image small
RUN apt-get update \
	&& apt-get install -y --no-install-recommends mariadb-server mariadb-client \
	&& rm -rf /var/lib/apt/lists/*

COPY ./tools/setup_mariadb.sh /usr/local/bin/setup_mariadb.sh

RUN chmod +x /usr/local/bin/setup_mariadb.sh

# Allow external connections
RUN sed -i 's/^bind-address\s*=.*/bind-address = 0.0.0.0/' /etc/mysql/mariadb.conf.d/50-server.cnf

EXPOSE 3306

# Use absolute path for entrypoint so exec works reliably
ENTRYPOINT [ "/usr/local/bin/setup_mariadb.sh" ]

CMD [ "mysqld_safe" ]
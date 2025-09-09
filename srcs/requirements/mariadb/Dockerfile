FROM debian:bullseye

RUN apt update -y
RUN apt upgrade -y
RUN apt install -y mariadb-server
RUN apt clean

RUN rm -rf /var/lib/apt/lists/*

COPY tools/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf

RUN chmod 644 /etc/mysql/mariadb.conf.d/50-server.cnf

COPY tools/mariadb.sh ./mariadb.sh

RUN chmod +x ./mariadb.sh

CMD ["./mariadb.sh"]
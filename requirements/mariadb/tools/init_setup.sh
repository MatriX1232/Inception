DB_PASS="$(cat /run/secrets/db_pass.txt)";

echo "CREATE DATABASE IF NOT EXISTS ${db1_name} ;" > db1.sql
echo "CREATE USER IF NOT EXISTS '${db1_user}'@'%' IDENTIFIED BY '${DB_PASS}' ;" >> db1.sql
echo "GRANT ALL PRIVILEGES ON ${db1_name}.* TO '${db1_user}'@'%' ;" >> db1.sql
echo "ALTER USER 'root'@'localhost' IDENTIFIED BY '12345' ;" >> db1.sql
echo "FLUSH PRIVILEGES;" >> db1.sql

cat db1.sql > /etc/mysql/init.sql

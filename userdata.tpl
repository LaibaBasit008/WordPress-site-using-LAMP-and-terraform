#!/bin/bash
# AUTOMATIC WORDPRESS INSTALLER IN  AWS Ubuntu Server 20.04 LTS (HVM)
# CHANGE DATABASE VALUES BELOW AND PASTE IT TO USERDATA SECTION In ADVANCED SECTION WHILE LAUNCHING EC2
# USE ELASTIC IP ADDRESS AND ALLOW SSH, HTTP AND HTTPS REQUEST IN SECURITY GROUP
# by Dev Bhusal
# Downloaded from https://www.devbhusal.com/wordpress.awsubuntu.sh

#Change these values and keep in safe place
db_root_password=PassWord
db_username=wordpressuser
db_user_password=PassWord4-user
db_name=wordpress

# install LAMP Server
sudo apt update -y
sudo apt install apache2 -y
sudo systemctl start apache2
 
sudo apt install php -y
sudo apt install php php-{pear,cgi,common,curl,mbstring,gd,mysqlnd,bcmath,json,xml,intl,zip,imap,imagick} -y

sudo apt install mysql-server mysql-common -y
sudo systemctl enable --now  apache2
sudo systemctl enable --now mysql

usermod -a -G www-data ubuntu
chown -R ubuntu:www-data /var/www
find /var/www -type d -exec chmod 2775 {} \;
find /var/www -type f -exec chmod 0664 {} \;

wget https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz
cp -r wordpress/* /var/www/html/
sudo systemctl stop mysql
mkdir /var/run/mysqld
chown mysql:mysql /var/run/mysqld
mysqld_safe --skip-grant-tables >res 2>&1 & mysql -uroot -e "UPDATE mysql.user SET authentication_string=null WHERE User='root';"
mysql -uroot -e " UPDATE mysql.user SET plugin='mysql_native_password'  WHERE User='root';flush privileges"

killall -v mysqld
sudo systemctl stop mysql 
sudo systemctl start mysql

mysql -uroot -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$db_root_password';FLUSH PRIVILEGES;" 
mysql -uroot -p$db_root_password  -e "DELETE FROM mysql.user WHERE User='';"
mysql -uroot -p$db_root_password -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"


# Create database user and grant privileges
mysql -uroot -p$db_root_password -e "CREATE USER '$db_username'@'localhost' IDENTIFIED BY '$db_user_password';"yes

mysql -uroot -p$db_root_password -e "GRANT ALL ON *.* TO '$db_username'@'localhost';flush privileges;"
# Create database
mysql -uroot -p$db_root_password -e "CREATE DATABASE $db_name;"

# Create wordpress configuration file and update database value
cd /var/www/html
cp wp-config-sample.php wp-config.php

sed -i "s/database_name_here/$db_name/g" wp-config.php
sed -i "s/username_here/$db_username/g" wp-config.php
sed -i "s/password_here/$db_user_password/g" wp-config.php
cat <<EOF >>/var/www/html/wp-config.php

define( 'FS_METHOD', 'direct' );
define('WP_MEMORY_LIMIT', '256M');

EOF

# Change permission of /var/www/html/
chown -R ubuntu:www-data /var/www/html
chmod -R 774 /var/www/html
rm /var/www/html/index.html
sed -i '/<Directory "\/var\/www">/,/<\/Directory>/ s/AllowOverride None/AllowOverride all/' /etc/apache2/apache2.conf
sudo systemctl restart apache2
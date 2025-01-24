#!/bin/bash
#A script for Debian and derivatives that makes easy to install WordPress on your own server. The script allows:
#	> automatic WordPress installation using wp cli
#	> automatic generation of self-signed SSL certificate and a Diffie-Hellman file (2048bit)
#	> import database from local server and update URIs
#	> installation of plugin protecting against brute force attacks (fail2ban + mu-plugin)

# Colors, standard prefix
CSI="\033["
# disable color
CEND="${CSI}0m"
# red background
CREDBG="${CSI}41m"
# red
CRED="${CSI}91m"
# green
CGREEN="${CSI}32m"

# variables
dbname=wp$(openssl rand -hex 2)
dbprefix=px$(openssl rand -hex 2)wp_
dbuser=user$(openssl rand -hex 2)
dbpass=$(openssl rand -base64 16)
PHP_VER=$(php -v | grep ^PHP | cut -b 5,6,7)

# Run script as root
if [[ "$EUID" -ne 0 ]]; then
echo
        echo -e "Sorry, you need to run this as root"
        echo
        exit 1
fi

# Clear screen
clear

# Check the system and install software if necessary
echo
if [[ ! -f /usr/bin/mysql ]]; then
        echo -e " It looks like MariaDB/MysQL it ${CRED}is not installed.${CEND}"
else
        echo -e " It looks like MariaDB/MysQL it ${CGREEN}is installed.${CEND}"
fi
if [[ ! -f /usr/bin/php ]]; then
        echo -e " It looks like PHP it ${CRED}is not installed.${CEND}"
else
        echo -e " It looks like PHP it ${CGREEN}is installed.${CEND}"
fi
if [[ ! -f /usr/sbin/nginx ]]; then
        echo -e " It looks like Nginx it ${CRED}is not installed. ${CEND}"
else
        echo -e " It looks like Nginx it ${CGREEN}is installed. ${CEND}"
fi
if [[ ! -d /var/www ]]; then
        mkdir -p /var/www
fi

# COLLECTING DATA
#_-_-_-_-_-_-_-_-_-_-_-_-_

# LEMP
        echo
        while [[ $INSTLEMP !=  "y" && $INSTLEMP  != "n" ]]; do
                        read -p "Install/update LEMP (system repositories) [y/n]?: " -e -i n INSTLEMP
        done

# WordPress directory
        echo
		echo -e "${CGREEN}Enter an absolute path to the Wordpress installation directory ${CRED}without a SLASH (/) at the end${CEND}:"
		echo "Directory /var/www contains:"
        echo
		ls  /var/www/
		echo "----------------------------"
		echo -e "${CGREEN}e.g.:/var/www${CEND}"
        read -p  ": " -e WPdir
		echo
        echo -e "All files and folders will be extracted to ->: ${CRED}$WPdir/${CEND}wordpress"
        echo
        echo -e "${CREDBG}Press any key to continue or ctrl +c to cancel and start over...${CEND}"
        read -n1 -r -p ""

# Set administrator/main user for WordPress backend
	echo -e  "Enter a ${CRED}username ${CEND}for WordPress:"
	read WPuser
	while true; do
		echo -e "Enter a ${CRED}password${CEND} for ${CRED}$WPuser${CEND} without any spaces: "
		read -s WPuserpass1
		echo -e "${CRED}Re-enter${CEND} password:"
		read -s WPuserpass2
		[ "$WPuserpass1" = "$WPuserpass2" ] && break
		echo
		echo -e "${CRED}Passwords do no match, try again.${CEND}"
		echo
    done

# Set an e-mail addres for the WordPress user
	echo -e  "Enter ${CRED}an e-mail address${CEND} of the site administrator (must have at '@' and dot '.'):"
	read WPEmail
	while true; do
		echo -e "${CRED}Re-enter an e-mail:${CEND} "
		read WPEmail2
		[ "$WPEmail" = "$WPEmail2" ] && break
		echo
		echo -e "${CRED}E-mails do no match, try again.${CEND}"
    done

# set locales for WordPress
	echo 
		read -p  "Set the site language (e.g.: en_US, it_IT, pl_PL): " -e -i pl_PL WPLCL 
	echo
    
    while [[ $INSTWPFAIL2B !=  "y" && $INSTWPFAIL2B  != "n" ]]; do
                        read -p "Do you want to enable a brute force protection plugin? (mu-plugins + fail2ban) [y/n]?: " -e -i n INSTWPFAIL2B
        done

#END OF COLLECTING DATA
	echo
	echo -e "${CREDBG}Ready to install. Press any key to continue or ctrl +c to cancel and start over...${CEND}"
	read -n1 -r -p ""

# ACTIONS
#_-_-_-_-_-_-_-_-_-_-_-_-_

# install the all necessary software, create directories
if [[ ! -f /usr/bin/tar ]]; then
	apt update; apt install tar -y
fi

if [[ ! -f /usr/bin/curl ]]; then
	apt update;apt install curl -y
fi

if [[ ! -f /usr/bin/openssl ]]; then
	apt update; apt install openssl -y
fi

if [[ ! -d $WPdir ]]; then
	mkdir -p $WPdir
fi

if [[ ! -d /usr/local/src/wordpress ]]; then
	mkdir -p /usr/local/src/wordpress
fi

if [[ ! -d /etc/nginx/ssl ]]; then
	mkdir -p /etc/nginx/ssl
fi

# Generate self-signed SSL certificate in background
	echo -e "${CGREEN}The generation of a self-signed certificate in the background has been started.\n${CRED}The certificate files will be saved in :/etc/nginx/ssl${CEND}"
	# first generate Diffie-Hellman file (takes more time)
	openssl dhparam -out /etc/nginx/ssl/dhparam.pem 2048 > /dev/null 2>&1 &
	# generate self-signed SSL
	openssl req -new -x509 -nodes -days 720 -newkey rsa:2048 -keyout /etc/nginx/ssl/selfsigned.key -out /etc/nginx/ssl/selfsigned.crt -subj "/C=XX/ST=XX/L=XX/O=XX/CN=mywp.site" >> /dev/null 2>&1 &	
	sleep 5;
	echo	
# download ssl-params.conf file for nginx
	curl -o /etc/nginx/ssl/ssl-params.conf -LO https://raw.githubusercontent.com/intsez/WordPress/main/conf/ssl-params.conf

# Install LEMP if selected
if [[ "$INSTLEMP" = 'y' ]]; then
                echo
	apt update;apt install nginx mariadb-server php php-fpm php-mysqli php-common php-mbstring php-bz2 php-xmlrpc php-gd php-xml php-mysql php-cli php-zip php-curl php-intl php-opcache php-imagick -y

fi

# download configuration files for Nginx server block
if [[ ! -d /etc/nginx/conf.d ]]; then
            mkdir -p /etc/nginx/conf.d
fi

if [[ -f /etc/nginx/conf.d/wpnx-restr.conf ]]; then
echo
echo -e "${CRED}It looks like wpnx-restr.conf exists, file renamed. ${CEND}"
mv /etc/nginx/conf.d/wpnx-restr.conf /etc/nginx/conf.d/wpnx-restr.bck_$(date +%d-%m-%y#%H-%M-%S)
sleep 2;
fi

# download nginx configuration files for WordPress
if [[ -f /etc/nginx/sites-available/wordpress.conf ]]; then
echo -e "${CRED}It looks like wordpress.conf exists, file renamed ... ${CEND}"
mv /etc/nginx/sites-available/wordpress.conf /etc/nginx/sites-available/wordpress.bck_$(date +%d-%m-%y#%H-%M-%S)
sleep 2;
fi
echo
curl -o /etc/nginx/sites-available/wordpress.conf -LO https://raw.githubusercontent.com/intsez/WordPress/main/conf/wordpress.conf 
curl -o /etc/nginx/conf.d/wpnx-restr.conf -LO https://raw.githubusercontent.com/intsez/WordPress/main/conf/wpnx-restr.conf

#change WordPress directory in nginx
sed -i "s|/var/www/wordpress|$WPdir/wordpress|g" /etc/nginx/sites-available/wordpress.conf

#change php version
sed -i "s|php8.2|php$PHP_VER|g" /etc/nginx/sites-available/wordpress.conf

# create shortcut for WordPress on Nginx
 echo
 echo -e "${CGREEN}Additional security rules have been saved to: '/etc/nginx/conf.d/'.\nAdjust them as needed and reload Nginx again (nginx -s reload).${CEND}"
 echo

#remove shortcut for a default website
rm -rf /etc/nginx/sites-enabled/default

# disable include conf.d in main serwer configuration, will be added in VPS config
sed -i "s|include /etc/nginx/conf|#include /etc/nginx/conf|g" /etc/nginx/nginx.conf

# CREATE DATABASE USER AND ADD CHOOSEN PRIVILEGES
      mysql -e "CREATE DATABASE ${dbname} /*\!40100 DEFAULT CHARACTER SET utf8 */;"
 if [ $? -eq 0 ]; then
echo -e "${CGREEN}Database ${CRED}${dbname}${CEND} ${CGREEN}created.${CEND}"
	echo
	echo "All existing databases:"
	mysql -e "SHOW DATABASES;"
	echo
else
	echo
	echo "Unexpected failure."
	echo
	exit 1
fi
      
# create an user for database
 mysql -e "CREATE USER '${dbuser}'@localhost IDENTIFIED BY '${dbpass}';"
 if [ $? -eq 0 ]; then
		echo -e "User ${CRED}${dbuser}@localhost ${CEND}${CGREEN}created."
	else
		echo
		echo "Unexpected failure."
		echo
		exit 1
    fi

# show table prefix
	echo -e "${CEND}Table prefix ${CRED}${dbprefix} ${CEND}${CGREEN}created."

# Grant ALL privileges for the database
        mysql -e "GRANT ALL ON ${dbname}.* TO '${dbuser}'@localhost;"
        mysql -e "FLUSH PRIVILEGES;"
	if [ $? -eq 0 ]; then
		echo -e "${CEND}Privileges for ${CRED}${dbuser}@localhost${CEND} to ${CRED}${dbname}${CEND} ${CGREEN}granted.${CEND}"
		echo
		sleep 2;
		
		else
			echo
			echo "Unexpected failure."
			echo
			exit 1
	fi

# remove old shortcuts
    rm -rf /etc/nginx/sites-enabled/wordpress*
    rm -rf /etc/nginx/sites-enabled/default*
	
# create shortcut for new nginx configuration
    ln -s /etc/nginx/sites-available/wordpress.conf /etc/nginx/sites-enabled/

# set Wordpress directory permissions for installation process
	chown -R 0777 $WPdir

# Download and install WordPress
#_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_

# download wp cli for headless instalaltion
	curl -o /usr/local/src/wordpress/wp-cli.phar -LO https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
	chmod +x /usr/local/src/wordpress/wp-cli.phar
	mv /usr/local/src/wordpress/wp-cli.phar /usr/local/bin/wp
	echo

# download wordpress
	wp core download --path=$WPdir/wordpress --locale=$WPLCL --allow-root

# create wp-config file
	wp config create --path=$WPdir/wordpress --dbname=$dbname --dbuser=$dbuser --dbpass=$dbpass --dbprefix=$dbprefix --allow-root
#install WordPress
	wp core install --path=$WPdir/wordpress --url=localhost --title=Wordpress --admin_user=$WPuser --admin_password=$WPuserpass1 --admin_email=$WPEmail --allow-root

# Download an extra security rules for wp-config.php
	echo
	cp $WPdir/wordpress/wp-config.php $WPdir/wordpress/wp-config.backup
	curl -o /usr/local/src/wordpress/wp-config-security.conf -O https://raw.githubusercontent.com/intsez/WordPress/main/conf/wp-config-security.conf
	cat /usr/local/src/wordpress/wp-config-security.conf >> $WPdir/wordpress/wp-config.php
	if [ $? -eq 0 ]; then
		echo
		echo -e "${CGREEN}An additional security rules have been addedto $WPdir/wordpress/wp-config.php, adjust them as needed.${CEND}"
	else
                echo "Wrong path or wp-config.php doesn't exist"
	fi
	sleep 5;

    if [[ "$INSTWPFAIL2B" = 'y' ]]; then
    if [[ ! -d /etc/fail2ban ]]; then
	echo
            apt install fail2ban -y
    fi
	
# Enable the brute force protection (mu-plugins + fail2ban), configuration for must use plugin
	
	if [[ ! -d $WPdir/wordpress/wp-content/mu-plugins ]]; then
			mkdir -p $WPdir/wordpress/wp-content/mu-plugins
	fi
	
    cd $WPdir/wordpress/wp-content/mu-plugins
            echo -e "<?php\nfunction login_failed_403() {\nstatus_header( 403 );\n}\nadd_action( 'wp_login_failed', 'login_failed_403' );" > wordpress-auth.php
# configuration for fail2ban
    cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
    echo -e "[Definition]\nfailregex = <HOST>.*POST.*(wp-login\.php|xmlrpc\.php).* 403 " > /etc/fail2ban/filter.d/wordpress-auth.conf
    echo -e "\n[wordpress-auth]\nenabled = true\nport = http,https\nfilter = wordpress-auth\nlogpath = /var/log/nginx/access.log\nmaxretry = 3\nbantime = 3600" >> /etc/fail2ban/jail.local
    echo
    # commands to restart fail2ban
	systemctl restart fail2ban.service
	#(for OS without system.d)
	service fail2ban restart
	echo -e "${CGREEN}The Brute Force protection plugin created in ${CRED}$WPdir/wordpress/wp-content/mu-plugins/${CEND}wordpress\n${CGREEN}and enabled in fail2ban.${CEND}"
	fi
# EO FAIL2BAN

#Import database, update URIs, copy wp-content
		echo        
		while [[ $IMPDTB !=  "y" && $IMPDTB  != "n" ]]; do
                 read -p "Do you want to import local database, update URIs and copy wp-content?[y/n]?: " -e -i n IMPDTB
         done
		
         if [[ "$IMPDTB" = 'y' ]]; then

        # database location
        echo -e "${CRED}Enter an absolute path to the copy of your database location${CEND}\ne.g.:${CGREEN}/home/user/BACKUP/database.sql${CEND}"
        read -p ": " -e WPdbfile

        # wp-content dirctory location
        echo
        echo -e "${CRED}Enter an absolute path to the directory where ${CEND}the old wp-content${CRED} directory is located, and press enter${CEND}\ne.g.:${CGREEN}/home/user/BACKUP/${CEND} (without wp-content at the end)"
        read -p ": " -e WPcontent

        # URIs addreses
        echo
        echo -e "${CRED}Enter an old address, domain of your previous WordPress instance (be precise) ${CEND}\ne.g.:${CGREEN} www.olddomainname.io or 123.321.123.321 or 432.12.24.132:4487 ${CEND}"
        read -p ": " -e oldaddr
        echo
        echo -e "${CRED}Enter a NEW address, domain, of your actual WordPress instance (be precise) ${CEND}\ne.g.:${CGREEN} https://newaddress.com or localhost or 421.21.42.12:3412 ${CEND}"
        read -p ": " -e newaddr

        # Import Database actions
        cp -rf $WPcontent/wp-content/* $WPdir/wp-content/
        chown -R www-data:www-data $WPdir/wp-content
        echo -e "${CGREEN}Please wait, importing database. It may take a while...${CEND}"

        # clear all tables in current database
        mysql -Nse 'show tables' ${dbname} | while read table; do mysql -e "drop table ${table}" ${dbname}; done

        # import database
        mysql ${dbname} < ${WPdbfile}
        if [ $? -eq 0 ]; then
                echo
        else
                echo
                echo -e "${CRED}Unexpected failure.${CEND}"
                echo
                exit
        fi
        # show then read table_prefix
        mysqlshow ${dbname}
        echo
        echo -e "${CRED}Please type a table prefix shown above\n${CEND}(everything before the phrase:'${CGREEN}......wp_${CEND}options'), ${CRED}and press enter:${CEND}"
        echo -e "e.g: ${CGREEN}prefix_wp_ ${CEND}or${CGREEN} wpdata01-wp_${CEND}"
        read -p  ": " -e /tmp/updtSQL.sql
        echo -e "UPDATE ${table_pref}options SET option_value = replace(option_value, '${oldaddr}', '${newaddr}') WHERE option_name = 'home' OR option_name = 'siteurl';" > updtSQL.sql
        echo -e "UPDATE ${table_pref}posts SET guid = replace(guid, '${oldaddr}','${newaddr}');" >> /tmp/updtSQL.sql
        echo -e "UPDATE ${table_pref}posts SET post_content = replace(post_content, '${oldaddr}', '${newaddr}');" >> /tmp/updtSQL.sql
        echo -e "UPDATE ${table_pref}postmeta SET meta_value = replace(meta_value,'${oldaddr}','${newaddr}');" >> /tmp/updtSQL.sql
        echo -e "UPDATE ${table_pref}usermeta SET meta_value = replace(meta_value, '${oldaddr}','${newaddr}');" >> /tmp/updtSQL.sql
        echo -e "UPDATE ${table_pref}links SET link_url = replace(link_url, '${oldaddr}','${newaddr}');" >> /tmp/updtSQL.sql
        echo -e "UPDATE ${table_pref}comments SET comment_content = replace(comment_content , '${oldaddr}','${newaddr}');" >> /tmp/updtSQL.sql
        echo
        echo "Please wait, updating..."
        mysql ${dbname} <  /tmp/updtSQL.sql
        mysql -e "FLUSH PRIVILEGES;"
        if [ $? -eq 0 ]; then
                echo
                echo -e "${CGREEN}Import finished.${CEND}"
                echo
        else
                echo
                echo -e "${CRED}Unexpected failure.${CEND}"
                echo
                exit
        fi

        #change table prefix in wp-config.php, backup wp-config.php
        cp $WPdir/wp-config.php $WPdir/wp-config.php.backup
        # Update table prefix
        sed -i "/table_prefix/c \$table_prefix = '${table_pref}' ;" $WPdir/wp-config.php
fi

#EO IMPORTING DATABASE

 # update URIs after install
  if [[ "$IMPDTB" = 'n' ]]; then
    # variables
    oldaddr=localhost

        # URIs addreses
		echo
        echo -e "Enter the domain/address of your WordPress website\ne.g.:${CGREEN} youraddress.com ${CEND}or${CGREEN} localhost ${CEND}or${CGREEN} 192.168.1.155 ${CRED}(be precise)${CEND}"
        read -p ": " -e newaddr
        echo -e "UPDATE ${dbprefix}options SET option_value = replace(option_value, '${oldaddr}', '${newaddr}') WHERE option_name = 'home' OR option_name = 'siteurl';" > /tmp/updtSQL.sql
        echo -e "UPDATE ${dbprefix}posts SET guid = replace(guid, '${oldaddr}','${newaddr}');" >> /tmp/updtSQL.sql
        echo -e "UPDATE ${dbprefix}posts SET post_content = replace(post_content, '${oldaddr}', '${newaddr}');" >> /tmp/updtSQL.sql
        echo -e "UPDATE ${dbprefix}postmeta SET meta_value = replace(meta_value,'${oldaddr}','${newaddr}');" >> /tmp/updtSQL.sql
        echo -e "UPDATE ${dbprefix}usermeta SET meta_value = replace(meta_value, '${oldaddr}','${newaddr}');" >> /tmp/updtSQL.sql
        echo -e "UPDATE ${dbprefix}links SET link_url = replace(link_url, '${oldaddr}','${newaddr}');" >> /tmp/updtSQL.sql
        echo -e "UPDATE ${dbprefix}comments SET comment_content = replace(comment_content , '${oldaddr}','${newaddr}');" >> /tmp/updtSQL.sql
        echo
        echo "Please wait, updating..."
        mysql ${dbname} < /tmp/updtSQL.sql
        mysql -e "FLUSH PRIVILEGES;"
        if [ $? -eq 0 ]; then
                echo
                echo -e "${CGREEN}URIs updated.${CEND}"
        else
                echo
                echo -e "${CRED}Unexpected failure.${CEND}"
                echo
                exit
        fi

fi

#remove downloaded files and folders
        echo
        echo "Removing downloaded files ..."
        rm -rf /usr/local/src/wordpress
        rm -rf /root/.wp-cli
# set proper permissions for Wordpress a nd certificate file
        echo -e "Setting proper permissions ..."
		chmod 600 /etc/nginx/ssl/dhparam.pem /etc/nginx/ssl/selfsigned.key /etc/nginx/ssl/selfsigned.crt
        chown -R 0775 $WPdir
        chown -R www-data:www-data $WPdir
# test and reload nginx
        echo -e "Reloading nginx ..."
		echo -e "${CGREEN}"
        nginx -t && nginx -s reload
        echo -e "${CEND}"

# Summary and tips
		echo -e "${CRED}Configuration for https connection enabled.\nYou can change it and make other modifications in the: /etc/nginx/sites-available/wordpress.conf\n\nAlso remember to change selfsigned certificate and generate strong dhparam.pem file.\nFiles are located in /etc/nginx/ssl ${CEND}"
		echo        
		echo -e "Type the ${CGREEN}${newaddr}${CEND} into the address bar of your browser to view Wordpress website. "
        echo
		echo -e "${CGREEN}All operations have been completed. Bye ;)${CEND}"
		echo

#!/bin/bash
# A script for Debian and derivatives that makes it easy to install WordPress on a web server with a LEMP stack installed. The script allows for:
#	> automatic WordPress installation using wp cli from command line
#	> automatic generation of a self-signed SSL certificate and Diffie-Hellman file (in the background process, both 2048-bit)

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
dbname=wp_$(openssl rand -hex 2)
dbprefix=px$(openssl rand -hex 2)wp_
dbuser=user$(openssl rand -hex 2)
dbpass=$(openssl rand -base64 16)
PHP_VER=$(php -v | grep ^PHP | cut -b 5,6,7)

# function for password *******
askpass() {
    charcount='0'
    prompt="${1}: "
    reply=''
    while IFS='' read -n '1' -p "${prompt}" -r -s 'char'
    do
        case "${char}" in
            # Handles NULL
            ( $'\000' )
            break
            ;;
            # Handles BACKSPACE and DELETE
            ( $'\010' | $'\177' )
            if (( charcount > 0 )); then
                prompt=$'\b \b'
                reply="${reply%?}"
                (( charcount-- ))
            else
                prompt=''
            fi
            ;;
            ( * )
            prompt='*'
            reply+="${char}"
            (( charcount++ ))
            ;;
        esac
    done
    printf '\n' >&2
    printf '%s\n' "${reply}"
}


# Run script as root
if [[ "$EUID" -ne 0 ]]; then
echo
        echo -e "Sorry, you need to run this as root"
        echo
        exit 1
fi

# Clear screen
clear

# Check the system 
echo
echo "It looks like:"
echo
if [[ ! -f /usr/bin/mysql ]]; then
        echo -e " MariaDB/MysQL is${CRED} not installed.${CEND}"
else
        echo -e " MariaDB/MysQL ${CGREEN}is installed.${CEND}"
fi
if [[ ! -f /usr/bin/php ]]; then
        echo -e " PHP is .........${CRED} not installed.${CEND}"
else
        echo -e " PHP  ........ ${CGREEN}is installed.${CEND}"
fi

if [[ ! -f /usr/sbin/nginx ]] || [[ ! -f /etc/nginx/nginx.conf ]]; then
        echo -e " Nginx is .......${CRED} not installed. ${CEND}"
else
        echo -e " Nginx ...... ${CGREEN} is installed. ${CEND}"
fi

# Collecting data 
#_-_-_-_-_-_-_-_-_-_-_-_-_

# LEMP
        echo
        while [[ $INSTLEMP !=  "y" && $INSTLEMP  != "n" ]]; do
                        read -p "Install/update LEMP (system repositories) [y/n]?: " -e -i n INSTLEMP
        done

# Set WordPress directory
echo
		echo -e "${CGREEN}Enter an absolute path to the Wordpress installation directory\n${CEND}(${CRED}without a trailing slash ${CEND}'${CRED}/${CEND}')"
		echo "Directory /var/www contains:"
        echo
		ls  /var/www/
		echo "----------------------------"
		
		while true; do
		echo -e "${CGREEN}e.g.:/var/www${CEND}"
		read -p  ": " -e -i / WPdir

	if [[ -d $WPdir/wordpress ]]; then
		echo
		echo -e "${CREDBG}It looks like the destination folder exists.${CEND}"
		echo
	fi

		echo -e "WordPress will be installed in: '${CRED}$WPdir/${CEND}${CGREEN}wordpress${CEND}'. Is this the correct path ?"
		read -p  "[y/n]: " -e -i y WPdirOK

		if [[ "$WPdirOK" = 'y' ]] ; then
		break
		
			echo
			echo -e "${CGREEN}OK. Try again.${CEND}"
			echo
		fi
    done
		
# Set administrator/main user for WordPress backend

# username and password
while true; do

	echo -e  "Enter your ${CGREEN}username ${CEND}(main administrator account)"
	read -p ": " WPuser

echo -e "Enter ${CGREEN}$WPuser${CEND} password (without any spaces) "
WPuserpass1="$(askpass)"

# re-enter pasword
echo -e "${CGREEN}Re-enter password ${CEND}"
WPuserpass2="$(askpass)"

# compare passwords
[ "$WPuserpass1" = "$WPuserpass2" ] && break
		echo
		echo -e "${CREDBG}Passwords do no match, try again.${CEND}"
		echo
    done

# <<<<< username and password
		
# set an e-mail addres for the WordPress user
	while true; do

		while true; do
			echo -e  "Enter ${CGREEN}an e-mail address for $WPuser${CEND}"
			read -p ": " WPEmail
			# Check if the characters "@" and "." are included
			if [[ ! "$WPEmail" =~ "@" ]] || [[ ! "$WPEmail" =~ "." ]]; then
				echo
				echo -e "${CREDBG}Address must contain '@' and '.' . Try again.${CEND}"
				echo
			fi
			break 
		
		done

		echo -e "${CGREEN}Re-enter ${CEND}$WPuser's ${CGREEN}e-mail${CEND}"
		read -p ": " WPEmail2
		
	# compare e-mails	
		[ "$WPEmail" = "$WPEmail2" ] && break
		echo
		echo -e "${CREDBG}E-mails do no match. Try again.${CEND}"
		echo
	done

# <<<<< set an e-mail addres for the WordPress user

# set locales for WordPress
		read -p  "Set the site language (e.g.: en_US, it_IT, pl_PL): " -e -i pl_PL WPLCL 
	echo
   
# <<<<<<<<<< Collecting data

	echo -e "${CREDBG}Ready to install. Press any key to continue or ctrl +c to cancel.${CEND}"
	read -n1 -r -p ""

# Actions
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

if [[ ! -d /etc/nginx/conf.d ]]; then
            mkdir -p /etc/nginx/conf.d
fi

# Generate a self-signed SSL certificate in background
# _-_-_-_-_-__-_-_-_-_-_-_-_-_-_-_-_-__-_-_-_-_-_-_-_-_

# generate Diffie-Hellman
	if [[ ! -f /etc/nginx/ssl/dhparam.pem ]]; then
		openssl dhparam -out /etc/nginx/ssl/dhparam.pem 2048 > /dev/null 2>&1 &
	echo
	echo -e "${CGREEN}Generateing a Diffie-Hellman key file in background.\nThe file will be saved in: /etc/nginx/ssl${CEND}"
	fi
# generate self-signed SSL
	if [[ ! -f /etc/nginx/ssl/selfsigned.key ]] || [[ ! -f /etc/nginx/ssl/selfsigned.crt ]]; then
		openssl req -new -x509 -nodes -days 720 -newkey rsa:2048 -keyout /etc/nginx/ssl/selfsigned.key -out /etc/nginx/ssl/selfsigned.crt -subj "/C=XX/ST=XX/L=XX/O=XX/CN=mywp.site" >> /dev/null 2>&1 &	
	echo
	echo -e "${CGREEN}Generating a self-signed certificate in background.\nThe certificate files will be saved in: /etc/nginx/ssl${CEND}"
	fi
	echo
	sleep 5;
# download ssl-params.conf file for nginx
	if [[ ! -f /etc/nginx/ssl/ssl-params.conf ]]; then
		curl -o /etc/nginx/ssl/ssl-params.conf -LO https://raw.githubusercontent.com/intsez/WordPress/main/conf/ssl-params.conf		else
	fi

# >>>> Install LEMP if selected
	if [[ "$INSTLEMP" = 'y' ]]; then
        echo
		apt update;apt install nginx mariadb-server php php-fpm php-mysql php-common php-mbstring php-bz2 php-xmlrpc php-gd php-xml php-mysql php-cli php-zip php-curl php-intl php-opcache php-imagick -y
	fi
# <<<< Install LEMP if selected

# >>>>> NGINX - download configuration files 
# _-_-_-_-_-__-_-_-_-_-_-_-_-_-_-_-_-__-_-_-_

	if [[ -f /etc/nginx/conf.d/wpnx-restr.conf ]]; then
	echo -e "${CGREEN}wpnx-restr.conf exists. Old file has been renamed. ${CEND}"
	mv /etc/nginx/conf.d/wpnx-restr.conf /etc/nginx/conf.d/wpnx-restr.bck_$(date +%d-%m-%y)
	sleep 2;
	fi

# nginx files for WordPress
	if [[ -f /etc/nginx/sites-available/wordpress.conf ]]; then
	echo -e "${CGREEN}wordpress.conf exists. Old file has been renamed. ${CEND}"
	mv /etc/nginx/sites-available/wordpress.conf /etc/nginx/sites-available/wordpress.bck_$(date +%d-%m-%y)
	sleep 2;
	fi
	echo
	curl -o /etc/nginx/sites-available/wordpress.conf -LO https://raw.githubusercontent.com/intsez/WordPress/main/conf/wordpress.conf 
	curl -o /etc/nginx/conf.d/wpnx-restr.conf -LO https://raw.githubusercontent.com/intsez/WordPress/main/conf/wpnx-restr.conf
	
# change WordPress directory
	sed -i "s|/var/www/wordpress|$WPdir/wordpress|g" /etc/nginx/sites-available/wordpress.conf

# remove old shortcuts
	rm -rf /etc/nginx/sites-enabled/wordpress*
	rm -rf /etc/nginx/sites-enabled/default*
	
# create shortcut for WordPress configuration
	ln -s /etc/nginx/sites-available/wordpress.conf /etc/nginx/sites-enabled/

#remove shortcut for a default website
	rm -rf /etc/nginx/sites-enabled/default

# disable include conf.d in main serwer configuration, will be added in VPS config
	sed -i "s|include /etc/nginx/conf|#include /etc/nginx/conf|g" /etc/nginx/nginx.conf

# change the php version
	sed -i "s|php8.2-fpm|php$PHP_VER-fpm|g" /etc/nginx/sites-available/wordpress.conf

# <<<< NGINX - download configuration files

# >>>> CREATE DATABASE USER AND SET PRIVILEGES
	mysql -e "CREATE DATABASE ${dbname} /*\!40100 DEFAULT CHARACTER SET utf8 */;"
	echo
	echo "All existing databases:"
	mysql -e "SHOW DATABASES;"
	echo
	echo -e "${CGREEN}Database ${CEND}${dbname}${CGREEN} created.${CEND}"
# create user for database
	mysql -e "CREATE USER '${dbuser}'@localhost IDENTIFIED BY '${dbpass}';"
	if [ $? -eq 0 ]; then
		echo -e "${CGREEN}User ${CEND}${dbuser}@localhost${CGREEN} created."
	else
		echo
		echo "Unexpected failure."
		echo
		exit 1
	fi
# show table prefix
	echo -e "${CGREEN}Table prefix ${CEND}${dbprefix} ${CGREEN}created."
# Grant ALL privileges for the database
        mysql -e "GRANT ALL ON ${dbname}.* TO '${dbuser}'@localhost;"
        mysql -e "FLUSH PRIVILEGES;"
	if [ $? -eq 0 ]; then
		echo -e "${CGREEN}Privileges for ${CEND}${dbuser}@localhost${CGREEN} to ${CEND}${dbname} ${CGREEN}granted.${CEND}"
		echo
	else
		echo
		echo "Unexpected failure."
		echo
	exit 1
	fi
	sleep 5;
	
# <<<<< CREATE DATABASE USER AND ADD PRIVILEGES

# >>>>> Download and install WordPress
# set Wordpress directory permissions for installation process
	chown -R 0777 $WPdir
# download wp cli for headless instalaltion
	curl -o /usr/local/src/wordpress/wp-cli.phar -LO https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
	chmod +x /usr/local/src/wordpress/wp-cli.phar
	mv /usr/local/src/wordpress/wp-cli.phar /usr/local/bin/wp
	echo

# download wordpress
	wp core download --path=$WPdir/wordpress --locale=$WPLCL --allow-root
# create wp-config file
	wp config create --path=$WPdir/wordpress --dbname=$dbname --dbuser=$dbuser --dbpass=$dbpass --dbprefix=$dbprefix --allow-root
# install WordPress
	wp core install --path=$WPdir/wordpress --url=localhost --title=WordPress --admin_user=$WPuser --admin_password=$WPuserpass1 --admin_email=$WPEmail --allow-root
# download and add some extra security rules to wp-config.php
	echo
	cp $WPdir/wordpress/wp-config.php $WPdir/wordpress/wp-config.backup
	curl -o /usr/local/src/wordpress/wp-config-security.conf -O https://raw.githubusercontent.com/intsez/WordPress/main/conf/wp-config-security.conf
	cat /usr/local/src/wordpress/wp-config-security.conf >> $WPdir/wordpress/wp-config.php

# <<<<< Downalod and install WordPress

# Cleaning the system, setting permissions, realoading nginx
#_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_
	rm -rf /usr/local/src/wordpress
        rm -rf /root/.wp-cli
# set proper permissions for Wordpress and certificate file
	chmod 600 /etc/nginx/ssl/dhparam.pem /etc/nginx/ssl/selfsigned.key /etc/nginx/ssl/selfsigned.crt
        chown -R 0775 $WPdir
        chown -R www-data:www-data $WPdir
# test and reload nginx
	echo -e "${CGREEN}"
	nginx -t && nginx -s reload
        echo -e "${CEND}"

# Summary and tips
#_-_-_-_-_-_-_-_-_-
	echo -e "${CREDBG}-_-_-_-_-_-_-_-_-_Summary_-_-_-_-_-_-_-_-_-_-${CEND}"
	echo
	echo -e "Important configuration files are located in:"
	echo "----------------------------------------------------------"
	echo -e "${CGREEN}  > $WPdir/wordpress/wp-config.php (scroll down to see added security rules)"
	echo -e "  > /etc/nginx/sites-available/wordpress.conf\n  > /etc/nginx/conf.d/wpnx-restr.conf\n  > /etc/nginx/ssl/ssl-params.conf${CEND}"
	echo
	echo -e " > Remember to change your self-signed certificate and generate a strong dhparam.pem key file!\n\n > If nginx is not running, the script is probably still running in the background\n   generating the dhparam.pem key file. Check this by typing ${CGREEN}ps r${CEND} in the terminal.\n   Once the script has finished, reload nginx by typing ${CGREEN}nginx -t && nginx -s reload${CEND} in the terminal."
	echo		
	echo -e " > Type: localhost in your browser address bar to view your WordPress site. "
	echo
	echo -e "${CGREEN}Installation completed.${CEND}"
	echo

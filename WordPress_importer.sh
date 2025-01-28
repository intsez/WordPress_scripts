#!/bin/bash
# A script for Debian and derivatives that makes it easy to import a MySQL database and copy wp-content from a local source, then update the WordPress URIs.

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

# Clear screen
clear


# >>>>> set the WordPress directory
	echo -e "Enter an absolute path to the Wordpress installation directory."
	echo "Directory /var/www contains:"
    echo
	ls  /var/www/
	echo "----------------------------"
	
	while true; do
			echo -e "${CGREEN}e.g.:/var/www/wordpress/${CEND}"
			read -p  ": " -e -i / WPdirectory
			echo -e "Is this the correct path: '${CRED}$WPdirectory${CEND}${CGREEN}${CEND}'? "
			read -p  "[y/n]: " -e -i y WPdirectoryOK
	
		if [[ "$WPdirectoryOK" = 'y' ]] ; then
			break
		fi
	done
# <<<<< 
		
# >>>>> set the database location
	while true; do
			echo
			echo -e "Enter an absolute path to the database file you want to import.\n${CGREEN}e.g.:/home/user/BACKUP/database.sql${CEND}"
		read -p ": " -e -i / WPdbfile
			echo -e "Is this the correct database file: '${CRED}$WPdbfile${CEND}${CGREEN}${CEND}'? "
		read -p  "[y/n]: " -e -i y WPdbfileOK

		if [[ "$WPdbfileOK" = 'y' ]] ; then
			break
		fi
    done
# <<<<< 

# >>>>> set the wp-content backup copy
	while true; do
		echo
			echo -e "Enter an absolute path to the backup of the wp-content directory.\n${CGREEN}e.g.:/home/user/BACKUP/wp-content/${CEND}"
		read -p ": " -e -i / WPcontent
			echo -e "Is this the correct path: '${CRED}$WPcontent${CEND}${CGREEN}${CEND}'? "
		read -p  "[y/n]: " -e -i y WPcontentOK

		if [[ "$WPcontentOK" = 'y' ]] ; then
			break
		
		fi
	done
# <<<<< 
		
# >>>>> display all databases		
	echo        
	echo -e "${CGREEN}All existing databases:${CEND}"
	mysql -e "SHOW DATABASES;"
	echo
	echo -e "${CGREEN}Enter the name of the database you want to update:${CEND}"
    read -p ": " -e dbname
# <<<<<   

# >>>>> set URI addreses
    echo
    echo -e "Enter an old address, domain of your previous WordPress instance.\ne.g.:${CGREEN} https://www.olddomainname.io ${CEND}or${CGREEN} https://123.321.123.321 ${CEND}or${CGREEN} http://432.12.24.132:4487 ${CEND}"
    read -p ": " -e -i http oldaddr
    echo
    echo -e "Enter a new address/domain for your WordPress site\n(${CGREEN}must include http, not https)${CEND}\ne.g.: ${CGREEN}http://${CEND}newaddress.com ${CEND}or ${CGREEN}http://${CEND}localhost ${CGREEN}or ${CGREEN}http://${CEND}421.21.42.12:3412 ${CEND}"
    read -p ": " -e -i http:// newaddr
# <<<<< 
	echo
	echo -e "${CREDBG}Press any key to start importing or ctrl +c to cancel.${CEND}"
	read -n1 -r -p ""

# >>>>>>>>>> Actions
	echo -e "Copying wp-content, this may take a while, please wait ..."
	echo
	sleep 2;
	
	
# check if rsync is installed
		if [[ ! -f /usr/bin/rsync ]]; then
			apt install rsync -y
		fi
		
	rsync -avxr $WPcontent* $WPdirectory/wp-content/
	chown -R www-data:www-data $WPdirectory/wp-content
		
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
		
# show then read database prefix  (table_prefix)
	echo -e "Database table prefixes:"    
		mysql -e "SELECT DISTINCT LEFT(TABLE_NAME, LENGTH(TABLE_NAME) - INSTR(REVERSE(TABLE_NAME), '_')) AS prefix FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = '${dbname}' AND INSTR(TABLE_NAME, '_') > 0;"	
		echo
	echo -e "Enter the table prefix of the imported database:"
	echo -e "${CGREEN}e.g: prefix_wp_ ${CEND}or${CGREEN} wpdata_01-wp_${CEND}"
		read -p  ": " -e table_pref
	echo
	echo -e "Updating, please wait..."
	echo -e "UPDATE ${table_pref}options SET option_value = replace(option_value, '${oldaddr}', '${newaddr}') WHERE option_name = 'home' OR option_name = 'siteurl';" > /tmp/updtSQL.sql
	echo -e "UPDATE ${table_pref}posts SET guid = replace(guid, '${oldaddr}','${newaddr}');" >> /tmp/updtSQL.sql
	echo -e "UPDATE ${table_pref}posts SET post_content = replace(post_content, '${oldaddr}', '${newaddr}');" >> /tmp/updtSQL.sql
	echo -e "UPDATE ${table_pref}postmeta SET meta_value = replace(meta_value,'${oldaddr}','${newaddr}');" >> /tmp/updtSQL.sql
	echo -e "UPDATE ${table_pref}usermeta SET meta_value = replace(meta_value, '${oldaddr}','${newaddr}');" >> /tmp/updtSQL.sql
	echo -e "UPDATE ${table_pref}links SET link_url = replace(link_url, '${oldaddr}','${newaddr}');" >> /tmp/updtSQL.sql
	echo -e "UPDATE ${table_pref}comments SET comment_content = replace(comment_content , '${oldaddr}','${newaddr}');" >> /tmp/updtSQL.sql
# import database
	mysql ${dbname} <  /tmp/updtSQL.sql
	mysql -e "FLUSH PRIVILEGES;"

# update table prefix in wp-config.php, 
	# backup wp-config.php
	cp ${WPdirectory}wp-config.php ${WPdirectory}wp-config.backup_$(date +%d-%m-%y#%S)
# Update table prefix
	sed -i "/table_prefix/c \$table_prefix = '${table_pref}' ;" ${WPdirectory}/wp-config.php

echo
echo -e "${CGREEN} Import completed.${CEND}"
echo

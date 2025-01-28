# WordPress_autoinstaller.sh
A script for Debian and derivatives that makes it easy to install WordPress from the command line. The script allows you to:
* automatically install all the necessary packages to run WordPress on your server ([Nginx](https://nginx.org/), [MariaDB](https://mariadb.org/), [php-fpm](https://www.php.net/manual/en/install.fpm.php))
* automatically install WordPress using [wp cli](https://wp-cli.org),
* automatically generate a [Self-signed SSL certificate](https://en.wikipedia.org/wiki/Self-signed_certificate) and [Diffie-Hellman](https://en.wikipedia.org/wiki/Diffie%E2%80%93Hellman_key_exchange) key file (both 2048 bit).

### Usage
Just download and execute the script e.g.:
```sh
wget https://raw.githubusercontent.com/intsez/WordPress-autoinstaller/refs/heads/main/WordPress_autoinstaller.sh
chmod +x WordPress_autoinstaller.sh
./WordPress_autoinstaller.sh
```
![WordPress_Installer](https://github.com/user-attachments/assets/fb9dbd24-7b55-4028-9699-7ca054fc70e1)



# WordPress_importer.sh
A script for Debian and derivatives that makes it easy to import a MySQL database and copy wp-content from a local source, then update the WordPress URIs.

### Usage
Just download and execute the script e.g.:
```sh
wget https://raw.githubusercontent.com/intsez/WordPress_scripts/refs/heads/main/WordPress_importer.sh
chmod +x WordPress_importer.sh
./WordPress_importer.sh
```
![WordPress_importer](https://github.com/user-attachments/assets/00626881-5ad2-4ce7-95fc-7c158d9c7230)


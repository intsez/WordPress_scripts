# WordPress-autoinstaller.sh
A script for Debian and derivatives that makes it easy to install WordPress on a web server with a LEMP stack installed. The script allows you to:
* automatic WordPress installation using [wp cli](https://wp-cli.org),
* automatic generation of a [Self-signed SSL certificate](https://en.wikipedia.org/wiki/Self-signed_certificate) and [Diffie-Hellman](https://en.wikipedia.org/wiki/Diffie%E2%80%93Hellman_key_exchange) key file (both 2048 bit).

## Usage
Just download and execute the script :
```sh
wget https://raw.githubusercontent.com/intsez/WordPress-autoinstaller/refs/heads/main/WordPress_autoinstaller.sh
chmod +x WordPress_autoinstaller.sh
./WordPress_autoinstaller.sh
```

# WordPress-autoinstaller.sh
A script for Debian and derivatives that makes easy to install WordPress on your own server.
Basic features:
* automatic WordPress installation using [wp cli](https://wp-cli.org),
* automatic generation of a [Self-signed SSL certificate](https://en.wikipedia.org/wiki/Self-signed_certificate) and a 2048-bit [Diffie-Hellman](https://en.wikipedia.org/wiki/Diffie%E2%80%93Hellman_key_exchange) key,
* import database from local server and [update URIs](https://developer.wordpress.org/advanced-administration/upgrade/migrating/),
* install a [brute force attack](https://en.wikipedia.org/wiki/Brute-force_attack) protection plugin ([fail2ban](https://en.wikipedia.org/wiki/Fail2ban) + [mu-plugin](https://developer.wordpress.org/advanced-administration/plugins/mu-plugins/))

## Usage
Just download and execute the script :
```sh
wget https://raw.githubusercontent.com/intsez/WordPress-autoinstaller/refs/heads/main/WordPress_autoinstaller.sh
chmod +x WordPress_autoinstaller.sh
./WordPress_autoinstaller.sh
```

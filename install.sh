#!/bin/bash

randomPasswordMYSQL="123456qwerty123456"
minestorePath="/var/www/minestore"
minestoreDomain="";
phpVersion="7.2"
webserverUse="nginx"
sudoUse="sudo"
customMysql=0

clear >$(tty)

echo -e "\e[32mStarting installation of MineStoreCMS\e[0m"


firstStep(){
	$sudoUse apt update -y
	$sudoUse apt install -y curl openssl unzip build-essential cron
	$sudoUse curl -sL https://raw.githubusercontent.com/creationix/nvm/v0.33.4/install.sh -o install_nvm.sh
	$sudoUse bash install_nvm.sh
	source ~/.profile
	export NVM_DIR="$HOME/.nvm"
	[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
	[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
	nvm install v14.5.0
	nvm use v14.5.0
	nvm install --latest-npm
	echo -e "\nFirst step was \e[32msuccessfully\e[0m ended"
	echo -e "\e[32mPlease close terminal (like putty) and reconnect again\e[0m"
	echo -e "Then run command: bash install.sh step2"
}

packagesInstall(){
	$sudoUse apt update -y
	if [ "$(lsb_release -s -i)" == "Ubuntu" ]; then
		$sudoUse apt install -y software-properties-common
		add-apt-repository ppa:ondrej/php -y
    add-apt-repository ppa:certbot/certbot -y
	else
		$sudoUse apt install -y apt-transport-https lsb-release ca-certificates
		$sudoUse wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
		$sudoUse sh -c 'echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list'
	fi
	$sudoUse apt update -y
	$sudoUse apt install -y php7.2 php7.2-fpm php7.2-mbstring php7.2-xmlrpc php7.2-soap php7.2-gd php7.2-xml php7.2-cli php7.2-zip php7.2-curl php7.2-common php7.2-pdo php7.2-mysql
	$sudoUse curl -sS https://getcomposer.org/installer -o composer-setup.php
	$sudoUse php composer-setup.php --install-dir=/usr/local/bin --filename=composer
	randomPasswordMYSQL=$(openssl rand -base64 32 | cut -c1-32)
	if [ "$(systemctl is-active mysql)" != "inactive" ]; then
		echo
		echo -e "\e[31m - ALREADY INSTALLED DATABASE SERVER DETECTED!\e[0m"
		echo -e "We have detected that you're already have been using INSTALLED DATABASE SERVICE."
		while [ -z "${mysqlLogin}" ]
		do
			read -p "Enter login (ex. root): " mysqlLogin
		done
		while [ -z "${mysqlPass}" ]
		do
			read -p "Enter password: " mysqlPass
		done
		customMysql=1
		eval "$sudoUse mysql -h127.0.0.1 -P3306 -u$mysqlLogin -p$mysqlPass -e\"create database minestore;\""
	else
		export DEBIAN_FRONTEND=noninteractive
		if [ "$(lsb_release -s -i)" == "Debian" ]; then
			wget https://dev.mysql.com/get/mysql-apt-config_0.8.13-1_all.deb
			apt install gdebi-core
			# gdebi -qn mysql-apt-config_0.8.13-1_all.deb
			DEBIAN_FRONTEND=noninteractive dpkg -i mysql-apt-config*
			$sudoUse apt-key adv --keyserver keys.gnupg.net --recv-keys 8C718D3B5072E1F5
			apt update
		fi
		# echo "YOUR mysql pass: $randomPasswordMYSQL"
		$sudoUse debconf-set-selections <<< "mysql-server mysql-server/root_password password $randomPasswordMYSQL"
		$sudoUse debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $randomPasswordMYSQL"
		$sudoUse DEBIAN_FRONTEND=noninteractive apt install -q -y mysql-server

		if [ "$(lsb_release -s -i)" == "Debian" ]; then
			eval "$sudoUse mysql -h127.0.0.1 -P3306 -uroot -p$randomPasswordMYSQL -e\"create database minestore;\""
			eval "$sudoUse mysql -h127.0.0.1 -P3306 -uroot -p$randomPasswordMYSQL -e\"ALTER USER 'root'@'localhost' IDENTIFIED BY PASSWORD '$randomPasswordMYSQL';\""
			eval "$sudoUse mysql -h127.0.0.1 -P3306 -uroot -p$randomPasswordMYSQL -e\"CREATE USER 'minestore'@'%' IDENTIFIED BY PASSWORD '$randomPasswordMYSQL';\""
      eval "$sudoUse mysql -h127.0.0.1 -P3306 -uroot -p$randomPasswordMYSQL -e\"GRANT ALL PRIVILEGES ON *.* TO 'minestore'@'%' WITH GRANT OPTION;';\""
      eval "$sudoUse mysql -h127.0.0.1 -P3306 -uroot -p$randomPasswordMYSQL -e\"SET PASSWORD FOR 'minestore'@'%' = PASSWORD('$randomPasswordMYSQL');';\""
      eval "$sudoUse mysql -h127.0.0.1 -P3306 -uroot -p$randomPasswordMYSQL -e\"FLUSH PRIVILEGES;';\""
		else
      eval "$sudoUse mysql -h127.0.0.1 -P3306 -uroot -p$randomPasswordMYSQL -e\"create database minestore;\""
			eval "$sudoUse mysql -h127.0.0.1 -P3306 -uroot -p$randomPasswordMYSQL -e\"ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$randomPasswordMYSQL';\""
			eval "$sudoUse mysql -h127.0.0.1 -P3306 -uroot -p$randomPasswordMYSQL -e\"CREATE USER 'minestore'@'%' IDENTIFIED WITH mysql_native_password BY '$randomPasswordMYSQL';\""
      eval "$sudoUse mysql -h127.0.0.1 -P3306 -uroot -p$randomPasswordMYSQL -e\"GRANT ALL PRIVILEGES ON *.* TO 'minestore'@'%' WITH GRANT OPTION;';\""
      eval "$sudoUse mysql -h127.0.0.1 -P3306 -uroot -p$randomPasswordMYSQL -e\"FLUSH PRIVILEGES;';\""
		fi
	fi
}

configurationInstall(){
	cd $minestorePath
	wget http://minestorecms.com/cms.z -O ./cms.z
	tar -xzf ./cms.z .
	rm -f ./cms.z

	# phpVersion=$(php --version | head -n 1 | cut -d " " -f 2 | cut -c 1-3)

	if [ $webserverUse == "nginx" ]; then
		$sudoUse apt install -y nginx
    $sudoUse apt-get install -y python3-certbot-nginx
		cat > /etc/nginx/sites-enabled/minestore << EOF
server {
	listen 80;
	listen [::]:80;

	root $minestorePath/public;
	index index.php;
	server_name $minestoreDomain;
  client_max_body_size 64m;

  location / {
      try_files \$uri \$uri/ /index.php?\$query_string;
  }
  location ~ \.php$ {
      try_files \$uri =404;
      fastcgi_split_path_info ^(.+\.php)(.*)$;
      fastcgi_pass unix:/run/php/php$phpVersion-fpm.sock;
      fastcgi_index index.php;
      fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
      include fastcgi_params;
  }
}
EOF
	$sudoUse service nginx restart
	else
		$sudoUse apt install -y apache2 libapache2-mod-php$phpVersion
   $sudoUse apt-get install -y python3-certbot-apache
		cat > /etc/apache2/sites-enabled/minestore.conf << EOF
<VirtualHost *:80>
	ServerName $minestoreDomain
	ServerAdmin webmaster@localhost
	DocumentRoot $minestorePath/public
	<Directory $minestorePath/public>
		Options -Indexes +FollowSymLinks +MultiViews
		AllowOverride All
		Require all granted
	</Directory>
	<Directory $minestorePath>
       AllowOverride All
   </Directory>
	<FilesMatch \.php$>
		SetHandler "proxy:unix:/run/php/php$phpVersion-fpm.sock|fcgi://localhost/"
	</FilesMatch>
</VirtualHost>
EOF
	$sudoUse a2enconf php$phpVersion-fpm
	$sudoUse a2enmod proxy
	$sudoUse a2enmod proxy_fcgi setenvif
	$sudoUse a2enmod rewrite
	$sudoUse service apache2 restart
	fi

	if ! grep -q "timezone.sitePath" /etc/php/$phpVersion/fpm/php.ini
	then
		printf "\n[timezone]\ntimezone.sitePath = $minestorePath" >> /etc/php/$phpVersion/fpm/php.ini
	fi

	if grep -q '^post_max_size ' /etc/php/$phpVersion/fpm/php.ini
	then
		sed -i 's,^post_max_size =.*$,post_max_size = 64M,' >> /etc/php/$phpVersion/fpm/php.ini
	else
		sed -i '/^\[PHP\].*/a post_max_size = 64M' /etc/php/$phpVersion/fpm/php.ini
	fi

	if grep -q '^memory_limit ' /etc/php/$phpVersion/fpm/php.ini
	then
		sed -i 's,^memory_limit =.*$,memory_limit = 256M,' >> /etc/php/$phpVersion/fpm/php.ini
	else
		sed -i '/^\[PHP\].*/a memory_limit = 256M' /etc/php/$phpVersion/fpm/php.ini
	fi

	if grep -q '^upload_max_size ' /etc/php/$phpVersion/fpm/php.ini
	then
		sed -i 's,^upload_max_size =.*$,upload_max_size = 64M,' >> /etc/php/$phpVersion/fpm/php.ini
	else
		sed -i '/^\[PHP\].*/a upload_max_size = 64M' /etc/php/$phpVersion/fpm/php.ini
	fi

	sudo sed -i "s/.*bind-address.*/bind-address = 0.0.0.0/" /etc/mysql/mysql.conf.d/mysqld.cnf
	sudo sed -i "s/.*bind-address.*/bind-address = 0.0.0.0/" /etc/mysql/my.cnf

	if [ -e libphpcpp.so.2.2.0 ]; then \
        mv -f libphpcpp.so.2.2.0 /usr/lib/; \
        ln -f -s /usr/lib/libphpcpp.so.2.2.0 /usr/lib/libphpcpp.so.2.2; \
        ln -f -s /usr/lib/libphpcpp.so.2.2.0 /usr/lib/libphpcpp.so; \
	fi
	if [ -e libphpcpp.a.2.2.0 ]; then mv -f libphpcpp.a.2.2.0 /usr/lib/; \
	        ln -f -s /usr/lib/libphpcpp.a.2.2.0 /usr/lib/libphpcpp.a; \
	fi
	if `which ldconfig`; then \
	        ldconfig; \
	fi

	EXTENSION_DIR=$(php -i | grep ^extension_dir | head -n 1 | cut -d " " -f 3)
	if [ -e timezone.ini ]; then mv -f timezone.ini /etc/php/$phpVersion/fpm/conf.d/;
	fi
	if [ -e timezone.so ]; then mv -f timezone.so $EXTENSION_DIR/;
	fi
	$sudoUse service php$phpVersion-fpm restart
	$sudoUse chmod -R 0777 .env storage key public/img
	$sudoUse chown -R www-data:www-data public/img
	$sudoUse chown root updater
  $sudoUse chmod u=rwx,go=xr,+s updater
	$sudoUse service nginx restart
	$sudoUse service mysql restart
	export COMPOSER_ALLOW_SUPERUSER=1
	composer install
  $sudoUse sudo certbot --$webserverUse
	npm i -f --no-audit --silent
	npm install --silent --save vue-cookie
	npm install --silent vue-i18n
	npm run production
	php artisan cache:clear
	php artisan config:clear
	php artisan key:generate
	$sudoUse chmod -R 0777 $minestorePath
	$sudoUse chown -R www-data:www-data $minestorePath
  crontab -l | { cat; echo "0 5 * * * /usr/bin/certbot renew --quiet"; } | crontab -
	crontab -l | { cat; echo "0 1 * * * cd $minestorePath && php artisan currency:update >> /dev/null 2>&1"; } | crontab -
	crontab -l | { cat; echo "*/2 * * * * cd $minestorePath && php artisan cron:worker >> /dev/null 2>&1"; } | crontab -
	echo
	echo -e "\e[32mInstallation was finished successfully!\e[0m"
	
	if [ "$customMysql" == "0" ]; then
		echo -e "Please, \e[32mSAVE\e[0m automatic generated database credentials:"
		echo -e "database: minestore"
		echo -e "user: minestore"
		echo -e "password: $randomPasswordMYSQL"
	fi
	
	echo "$randomPasswordMYSQL" > /root/MineStoreCMS_DB.txt
}

systemCheckQuestion(){
	while [ -z "${systemType}" ]
	do
		echo "Are you using new and clean Virtual Server (and you don\`t have any websites on this Virtual Server) ?"
		echo -e "1) Yes - this is Virtual Server is new and clear \e[32m(extremely recommended)\e[0m"
		echo -e "2) No - I have already installed websites on this Virtual Server." 
		echo
		read -p "Select the number \ Y (yes) \ N (no): " n
		echo
		case ${n} in
			1|y|Y|yes|Yes)
				systemType="pure"
			;;
			2|n|N|no|No)
				systemType="junk"
			;;
		esac
	done
	# echo "${systemType}"
}

minestoreDomainConfiguration(){
	while [ -z "${minestoreDomain}" ]
	do
		read -p "Enter domain (ex. store.example.com): " minestoreDomain
	done
	echo "Domain set ${minestoreDomain}"
}

webServerConfiguration(){
	while [ -z "${chooseWeb}" ]
	do
		echo "What webserver service do you wanna use?"
		echo "If you are using a web server already, select your one!"
		echo "1) Nginx (highly recommended)"
		echo "2) Apache" 
		echo
		read -p "Select the number 1 or 2: " n
		echo
		case ${n} in
			1|nginx)
				chooseWeb=1
				webserverUse="nginx"
			;;
			2|apache)
				chooseWeb=1
				webserverUse="apache"
			;;
		esac
	done
	# echo "result webserver: ${webserverUse}"
}

minestorePathConfiguration(){
	while [ -z "${minestorePathQuestion}" ]
	do
		echo "Installation path for MineStoreCMS is $minestorePath"
		echo "1) Yes - install it by next directory: $minestorePath"
		echo "2) No - I want to change the path." 
		echo
		read -p "Select the number \ Y (yes) \ N (no): " n
		echo
		case ${n} in
			1|y|Y|yes|Yes)
				minestorePathQuestion="default"
				eval "mkdir -p $minestorePath"
			;;
			2|n|N|no|No)
				minestorePathQuestion="new"
				echo "Use path WITHOUT tailing slash!"
				read -p "Enter new path of MineStoreCMS: " minestorePathNew
				eval "mkdir -p $minestorePathNew"
				while [ ! -d "$minestorePathNew" ]
				do
					echo "Directory '$minestorePathNew' doesn't exist." 
					read -p "Enter new path of MineStoreCMS: " minestorePathNew
					eval "mkdir -p $minestorePathNew"
				done
				minestorePath="$minestorePathNew"
			;;
		esac
	done
	# echo "${minestorePathQuestion}"
	# echo "result path: ${minestorePath}"
}

if [ "$#" == 0 ]; then
	echo -e "\nUse argument step1 or step2, like that:"
	echo "bash install.sh step1"
	echo "bash install.sh step2"
else
	if [ "$1" == "step1" ]; then
		firstStep
	elif [ "$1" == "step2" ]; then
		if ! command -v npm &> /dev/null
		then
		    echo "You didn't execute Step 1 or have not reconnected to the terminal !"
		    exit
		fi
		systemCheckQuestion
		webServerConfiguration
		minestoreDomainConfiguration
		minestorePathConfiguration
		packagesInstall
		configurationInstall
	else
		echo -e "\nUse argument step1 or step2, like that:"
		echo "bash install.sh step1"
		echo "bash install.sh step2"
	fi
fi

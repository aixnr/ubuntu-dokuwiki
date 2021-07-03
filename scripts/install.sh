#!/usr/bin/env bash

# ------------------------------------------------------------------------------
set -u          # Error on unset variable
set -e          # Error on non-zero exit code
set -o pipefail # Error when pipe failed


# Variables --------------------------------------------------------------------
LOG_INFO="  [INFO]"
LOG_WARN="  [WARN]"
MYUSER=www

# Base installation ------------------------------------------------------------
install_base() {
  printf "$LOG_INFO Upgrading packages\n"
  apt --yes update > /dev/null 2>&1
  apt --yes upgrade > /dev/null 2>&1
  printf "$LOG_INFO Completed upgrade\n"

  printf "$LOG_INFO Installing tzdata with env vars\n"
  DEBIAN_FRONTEND="noninteractive" TZ="America/New_York" apt --yes install tzdata > /dev/null 2>&1

  printf "$LOG_INFO Installing packages\n"
  apt --yes install curl vim nano locate less imagemagick monit \
                    nginx php-fpm php-xml php-gd > /dev/null 2>&1
  printf "$LOG_INFO Completed installation\n"
}


# Configuring user -------------------------------------------------------------
configure_user() {
  printf "$LOG_INFO Adding user $MYUSER\n"
  groupadd --gid 1000 --system ${MYUSER} > /dev/null 2>&1
  adduser --no-create-home --gecos '' --disabled-password \
          --uid 1000 --ingroup $MYUSER $MYUSER > /dev/null 2>&1
  printf "$LOG_INFO Completed configuring user $MYUSER\n"
}


# Installing Dokuwiki ----------------------------------------------------------
install_dokuwiki() {
  printf "$LOG_INFO Downloading Dokuwiki (latest stable)\n"
  curl -fSL "https://download.dokuwiki.org/src/dokuwiki/dokuwiki-stable.tgz" \
       -o dokuwiki.tgz > /dev/null 2>&1
  
  printf "$LOG_INFO Extracting and placing Dokuwiki in /var/www/dokuwiki\n"
  tar -xzf dokuwiki.tgz
  mkdir -p /var/www
  mv dokuwiki-* /var/www/dokuwiki

  printf "$LOG_INFO Configuring permissions\n"
  chown -R $MYUSER:$MYUSER /var/www/dokuwiki
  chmod -R 775 /var/www/dokuwiki
}


# Configuring nginx ------------------------------------------------------------
configure_nginx() {
  printf "$LOG_INFO Removing nginx default.conf\n"
  rm /etc/nginx/sites-enabled/default
  printf "$LOG_INFO Now configuring nginx\n" 
  printf "$LOG_INFO Adding new configuration at /etc/nginx/conf.d/dokuwiki.conf\n"
  tee /etc/nginx/conf.d/dokuwiki.conf > /dev/null << EOF
server {
  listen 80;
  
  root /var/www/dokuwiki;
  access_log /var/log/nginx/dokuwiki_access.log;
  error_log /var/log/nginx/dokuwiki_error.log;
  index doku.php;
  
  # Deny access
  location ~ /(conf/|bin/|inc/) { deny all; }

  # Support for X-Accel-Redirect
  location ~ ^/data/ { internal ; }
 
  location ~ ^/lib.*\.(js|css|gif|png|ico|jpg|jpeg)$ { expires 365d; }
 
  location / { try_files \$uri \$uri/ @dokuwiki; }
 
  location @dokuwiki {
    # rewrites "doku.php/" out of the URLs if you set the userwrite setting to .htaccess in dokuwiki config page
    rewrite ^/_media/(.*) /lib/exe/fetch.php?media=\$1 last;
    rewrite ^/_detail/(.*) /lib/exe/detail.php?media=\$1 last;
    rewrite ^/_export/([^/]+)/(.*) /doku.php?do=export_\$1&id=\$2 last;
    rewrite ^/(.*) /doku.php?id=\$1&\$args last;
  }
 
  location ~ \.php$ {
    try_files \$uri \$uri/ /doku.php;
    include fastcgi_params;
    fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    fastcgi_param REDIRECT_STATUS 200;
    fastcgi_pass unix:/var/run/php/php7.4-fpm.sock; 
    }
}
EOF
  
  printf "$LOG_INFO Done with nginx configuration\n"
}


# Configure worker processes ---------------------------------------------------
configure_worker_proc() {
  #printf "$LOG_INFO Set nginx to not run as daemon\n"
  #sed -i '/user/ i daemon off;' /etc/nginx/nginx.conf
  
  #printf "$LOG_INFO Set php-fpm to not run as daemon\n"
  #sed -i 's/;daemonize = yes/daemonize = no/' /etc/php/7.4/fpm/php-fpm.conf

  printf "$LOG_INFO Changing worker process for nginx to www\n"
  sed -i "s/user www-data/user www/" /etc/nginx/nginx.conf
  
  printf "$LOG_INFO Changing worker process for php7.4-fpm to www\n"
  sed -i "s/user = www-data/user = www/" /etc/php/7.4/fpm/pool.d/www.conf
  sed -i "s/group = www-data/group = www/" /etc/php/7.4/fpm/pool.d/www.conf
  
  printf "$LOG_INFO Changing socket owner for php7.4-fpm to www\n"
  sed -i "s/listen.owner = www-data/listen.owner = www/" /etc/php/7.4/fpm/pool.d/www.conf
  sed -i "s/listen.group = www-data/listen.group = www/" /etc/php/7.4/fpm/pool.d/www.conf
  
  printf "$LOG_INFO Worker processes configured successfully!\n"
}


# Configure monit --------------------------------------------------------------
configure_monit() {
  printf "$LOG_INFO Configuring monit\n"
  printf "$LOG_INFO Creating new config at /etc/monit/conf.d/base.conf\n"
  tee /etc/monit/conf.d/base.conf > /dev/null << EOF
set httpd port 9001
  allow monit:monit_admin

check process nginx with pidfile /run/nginx.pid
  start program = "/etc/init.d/nginx start"
  stop program  = "/etc/init.d/nginx stop"

check process php-fpm7.4 with pidfile /run/php/php7.4-fpm.pid
  start program = "/etc/init.d/php7.4-fpm start"
  stop program  = "/etc/init.d/php7.4-fpm stop"
EOF

  printf "$LOG_INFO Completed monit configuration\n"
}

# Cleaning up ------------------------------------------------------------------
cleaning() {
  printf "$LOG_INFO Removing dokuwiki.tgz\n"
  rm /dokuwiki.tgz
  printf "$LOG_INFO Removing package cache\n"
  rm -rf /var/lib/apt/lists/*
}


# Main program -----------------------------------------------------------------
install_base
configure_user
install_dokuwiki
configure_nginx
configure_worker_proc
configure_monit
cleaning

# Changelog, Docker for Dokuwiki

**Project description**: Running Dokuwiki with containerized PHP-FPM and Nginx, using Ubuntu as the base container image. Nginx and PHP-FPM runs as `www` user with `uid` of `1000`, therefore maps with the default user-created non-root user (also `uid` of `1000`). PHP-FPM and Nginx are managed by `monit`.

The install script is `script/install.sh`, can be adapted to LXD or fresh VM installation.

**Table of Contents:**

1. [2021-07-02 Initialization](#2021-07-02-initialization)
2. [2021-07-03 Volume configuration](#2021-07-03-volume-configuration)

## 2021-07-02 Initialization

Running a Docker container (Ubuntu 20.04 LTS) with the following command, exposing container's port `80` (Nginx) bound to `9090`.

```bash
# Run a Ubuntu-based docker container and exec into it
docker run -it --name="dokuwiki" \
  -p 9090:80 ubuntu:20.04 -it /bin/bash
```

The initialization script can be found inside the `scripts` folder; see `scripts/install.sh` script.

Few neat tricks:

* Piping into `less` from `locate` with `locate <file_name> | xargs less`; the `xargs` command is required here.
* Installed `net-tools`, `tmux` and `htop` for debugging.
* Running `/usr/sbin/nginx` actually started the `nginx` server and exited the shell. Similarly, running `/usr/sbin/php-fpm7.4` also started the `php-fpm` server and exited the shell. To kill, issue `pgrep <service> | xargs kill -9`. This is probably related to the programs being set to run as daemon.

**!! Notes !!**:

* The default `www-data` user has a `uid` of `33` and `gid` of `33`. That's why we are changing it to `www` with `uid` of `1000` to match host's user.
* File `/etc/nginx/nginx.conf`; change `user` to `www` instead of `www-data` with `sed`.
* Create new file at `/etc/nginx/conf.d/dokuwiki.conf` for Dokuwiki's virtual host. It also has its own access and error logs.
* File `/etc/php/7.4/fpm/pool.d/www.conf`; the `user` and `group` are set `www-data`, change to `www`.
* Default socket for `php-fpm` is `/run/php/php7.4-fpm.sock` as defined at `/etc/php/7.4/fpm/pool.d/www.conf`.
* The user for `nginx` and the user for `php7.4-fpm.sock` (check with `ll`) must be the same, else there will be `502 Bad Gateway`. Edit `/etc/php/7.4/fpm/pool.d/www.conf`, under `listen.owner` and `listen.group` to user and group `www`, in addition to changing the owner for the worker processes `user` and `group`. The `user` and `group` determine the worker processes, the `listen.owner` and `listen.group` determine the socket owner.

## 2021-07-03 Volume configuration

Running a fresh container with 2 ports enabled; for `nginx` at 80 and for `monit` at `9001`.

```bash
docker run -it --name="dokuwiki" \
  -p 9090:80 -p 9345:9001 ubuntu:20.04 -it /bin/bash
```

I replaced `supervisord` with `monit`, because `supervisord` kept restarting `nginx` and `php-fpm` even though they were running already. With `monit`, I placed the config file at `/etc/monit/conf.d/base.conf` and run it with `monit start all`, and then checked with `monit status`.

Created `Dockerfile`, building the image now with `docker build -t dokuwiki .` command.

```bash
# Create the data volume
docker volume create dokuwiki_data

# Run and bind
docker run -d --name="dokuwiki" \
  --volume dokuwiki_data:/var/www/dokuwiki/data/pages \
  -p 9090:80 -p 9345:9001 dokuwiki
```

To access the named volume `dokuwiki_data`, use `bindfs`:

```bash
# Create directory
mkdir data

# Mount
sudo bindfs /var/lib/docker/volumes/dokuwiki_data/_data data

# Unmount
sudo umount data
```

**!! Notes !!**

* Set the Docker volume to `/var/www/dokuwiki/data/pages`, using the named volume `dokuwiki_data` created with the `docker volume create` command.
* `supervisord` might have failed because `nginx` and `php-fpm` were running as daemon. Maybe should turn this off to enable them running at the foreground instead of background. It turns out, it is a requirement for services to not run as `daemon` to be used with `supervisord`, while `monit` does not have this requirement.

# Dokuwiki with Docker

A custom Docker container (Ubuntu-based) for running Dokuwiki with `nginx` and `php-fpm`, managed by `monit`.

```bash
# Build the container image
docker build -t dokuwiki .

# Create named docker volume to persist data
docker volume create dokuwiki_data

# Run the container
docker run -d --name="dokuwiki" \
  --volume dokuwiki_data:/var/www/dokuwiki/data/pages \
  -p 9090:80 -p 9345:9001 dokuwiki
```

Port `80` on the container is for `nginx`, port `9001` is for `monit`. See `CHANGELOG.md` on tutorial to access data stored on the named volume via `bindfs`. It is wise to bind the port on the host to avoid Docker default to `0.0.0.0`, e.g. with `-p 127.0.0.1:9090` to only allow connection from `127.0.0.1` to the port `9090`.

To inspect the container after running, issue `docker exec -it dokuwiki /bin/bash`.

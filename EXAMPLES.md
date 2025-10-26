# WebStack Manager - Real-World Examples

Practical examples for common hosting scenarios.

## Table of Contents

1. [WordPress Multi-Site Setup](#wordpress-multi-site-setup)
2. [Laravel Application Deployment](#laravel-application-deployment)
3. [Node.js Application with Nginx](#nodejs-application-with-nginx)
4. [Multi-Client Agency Setup](#multi-client-agency-setup)
5. [E-commerce Stack](#e-commerce-stack)
6. [Development + Staging + Production](#development-staging-production)
7. [High-Traffic WordPress with Caching](#high-traffic-wordpress-with-caching)

---

## WordPress Multi-Site Setup

Host multiple WordPress sites on one server with different PHP versions.

### Scenario
- Client A: Blog on PHP 8.1 + MariaDB 10.11
- Client B: WooCommerce on PHP 8.2 + MySQL 8.0
- Client C: Legacy site on PHP 7.4 + MySQL 5.7

### Setup

**Site 1: Blog**
```bash
webstack create
# Site name: clienta-blog
# Domain: blog.clienta.com
# PHP: 8.1
# Database: MariaDB 10.11
# Redis: y
# phpMyAdmin: y
```

**Site 2: WooCommerce**
```bash
webstack create
# Site name: clientb-shop
# Domain: shop.clientb.com
# PHP: 8.2
# Database: MySQL 8.0
# Redis: y
# phpMyAdmin: y
```

**Site 3: Legacy Site**
```bash
webstack create
# Site name: clientc-legacy
# Domain: legacy.clientc.com
# PHP: 7.4
# Database: MySQL 5.7
# Redis: n
# phpMyAdmin: y
```

### Install WordPress

For each site:
```bash
cd /opt/webstack/sites/clienta-blog/public
wget https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz --strip-components=1
rm latest.tar.gz
chown -R www-data:www-data .
```

### Configure WordPress

Get database credentials:
```bash
cat /opt/webstack/sites/clienta-blog/.env
```

Visit `https://blog.clienta.com` and complete WordPress installation.

### Enable Redis Cache

Install Redis Object Cache plugin and add to `wp-config.php`:
```php
define('WP_REDIS_HOST', 'redis');
define('WP_REDIS_PORT', 6379);
define('WP_CACHE', true);
```

---

## Laravel Application Deployment

Deploy a Laravel application with full optimization.

### Setup

```bash
webstack create
# Site name: myapp
# Domain: app.example.com
# PHP: 8.3
# Database: MySQL 8.0
# Redis: y
# phpMyAdmin: n
```

### Upload Application

```bash
# From your local machine
scp -r ./my-laravel-app/* root@server:/opt/webstack/sites/myapp/public/
```

### Configure Environment

```bash
# On server
cd /opt/webstack/sites/myapp/public

# Get database credentials
cat /opt/webstack/sites/myapp/.env

# Edit Laravel .env
nano .env
```

Update database settings:
```env
DB_CONNECTION=mysql
DB_HOST=db
DB_PORT=3306
DB_DATABASE=myapp_db
DB_USERNAME=myapp_user
DB_PASSWORD=<from webstack .env>

REDIS_HOST=redis
REDIS_PORT=6379

APP_URL=https://app.example.com
```

### Install Dependencies & Setup

```bash
# Enter PHP container
docker exec -it myapp_php sh

# Inside container
cd /var/www/html
composer install --optimize-autoloader --no-dev
php artisan key:generate
php artisan migrate --force
php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan storage:link
```

### Custom Nginx Configuration

Edit `/opt/webstack/sites/myapp/nginx.conf`:
```nginx
server {
    listen 80;
    server_name _;
    root /var/www/html/public;
    index index.php;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass php:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_buffer_size 128k;
        fastcgi_buffers 256 4k;
        fastcgi_busy_buffers_size 256k;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }
}
```

Restart:
```bash
webstack restart myapp
```

---

## Node.js Application with Nginx

Run a Node.js app behind Nginx reverse proxy.

### Setup

```bash
webstack create
# Site name: nodeapp
# Domain: node.example.com
# PHP: 8.3 (won't be used, but required)
# Database: PostgreSQL 16
# Redis: y
```

### Modify Docker Compose

Edit `/opt/webstack/sites/nodeapp/docker-compose.yml`:

```yaml
version: '3.8'

services:
  web:
    image: nginx:alpine
    container_name: nodeapp_web
    restart: unless-stopped
    networks:
      - nodeapp_internal
      - webstack
    volumes:
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.nodeapp.rule=Host(`node.example.com`)"
      - "traefik.http.routers.nodeapp.entrypoints=websecure"
      - "traefik.http.routers.nodeapp.tls.certresolver=letsencrypt"
      - "traefik.docker.network=webstack"
    depends_on:
      - app

  app:
    image: node:20-alpine
    container_name: nodeapp_node
    restart: unless-stopped
    working_dir: /app
    networks:
      - nodeapp_internal
    volumes:
      - ./app:/app
    environment:
      - NODE_ENV=production
      - DB_HOST=db
      - REDIS_HOST=redis
    command: node server.js
    ports:
      - "3000"

  db:
    image: postgres:16-alpine
    container_name: nodeapp_db
    restart: unless-stopped
    networks:
      - nodeapp_internal
    volumes:
      - db_data:/var/lib/postgresql/data
    environment:
      - POSTGRES_DB=nodeapp_db
      - POSTGRES_USER=nodeapp_user
      - POSTGRES_PASSWORD=<password>

  redis:
    image: redis:7-alpine
    container_name: nodeapp_redis
    restart: unless-stopped
    networks:
      - nodeapp_internal

networks:
  nodeapp_internal:
  webstack:
    external: true

volumes:
  db_data:
```

### Nginx Configuration

Edit `/opt/webstack/sites/nodeapp/nginx.conf`:
```nginx
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://app:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Deploy Application

```bash
mkdir -p /opt/webstack/sites/nodeapp/app
# Upload your Node.js app to /opt/webstack/sites/nodeapp/app/

# Restart
cd /opt/webstack/sites/nodeapp
docker compose down
docker compose up -d
```

---

## Multi-Client Agency Setup

Manage multiple client sites efficiently.

### Create Organizational Structure

```bash
# Client 1: 3 sites
webstack create  # client1-main -> main.client1.com (PHP 8.2)
webstack create  # client1-shop -> shop.client1.com (PHP 8.1)
webstack create  # client1-blog -> blog.client1.com (PHP 8.3)

# Client 2: 2 sites
webstack create  # client2-corporate -> www.client2.com (PHP 8.3)
webstack create  # client2-portal -> portal.client2.com (PHP 8.0)

# List all
webstack list
```

### Automated Backups

Create backup script `/usr/local/bin/backup-all-sites.sh`:
```bash
#!/bin/bash

SITES=(
    "client1-main"
    "client1-shop"
    "client1-blog"
    "client2-corporate"
    "client2-portal"
)

for site in "${SITES[@]}"; do
    echo "Backing up $site..."
    webstack backup "$site"
done

# Clean old backups (keep last 7 days)
find /opt/webstack/backups -name "*.tar.gz" -mtime +7 -delete

echo "All backups complete!"
```

Make executable and add to cron:
```bash
chmod +x /usr/local/bin/backup-all-sites.sh

# Add to crontab (daily at 2 AM)
crontab -e
0 2 * * * /usr/local/bin/backup-all-sites.sh >> /var/log/webstack-backup.log 2>&1
```

### Monitoring Script

Create `/usr/local/bin/check-all-sites.sh`:
```bash
#!/bin/bash

SITES=(
    "client1-main:https://main.client1.com"
    "client1-shop:https://shop.client1.com"
    "client1-blog:https://blog.client1.com"
    "client2-corporate:https://www.client2.com"
    "client2-portal:https://portal.client2.com"
)

for entry in "${SITES[@]}"; do
    IFS=':' read -r site url <<< "$entry"

    # Check HTTP status
    status=$(curl -s -o /dev/null -w "%{http_code}" "$url")

    if [ "$status" -eq 200 ]; then
        echo "✓ $site ($url) - OK"
    else
        echo "✗ $site ($url) - HTTP $status"
        # Send alert (email, Slack, etc.)
    fi
done
```

---

## E-commerce Stack

High-performance WooCommerce setup.

### Setup

```bash
webstack create
# Site name: shop
# Domain: shop.example.com
# PHP: 8.2
# Database: MariaDB 11.2
# Redis: y
# phpMyAdmin: y
```

### Install WordPress + WooCommerce

```bash
cd /opt/webstack/sites/shop/public

# Download WordPress
wget https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz --strip-components=1
rm latest.tar.gz

# Download WooCommerce
wget https://downloads.wordpress.org/plugin/woocommerce.latest-stable.zip
unzip woocommerce.latest-stable.zip -d wp-content/plugins/
rm woocommerce.latest-stable.zip
```

### Optimize PHP

Create `php.ini`:
```bash
nano /opt/webstack/sites/shop/php.ini
```

Add:
```ini
memory_limit = 512M
max_execution_time = 300
max_input_time = 300
max_input_vars = 5000
post_max_size = 100M
upload_max_filesize = 100M

[opcache]
opcache.enable=1
opcache.memory_consumption=256
opcache.interned_strings_buffer=16
opcache.max_accelerated_files=20000
opcache.revalidate_freq=2
opcache.save_comments=1
```

Update `docker-compose.yml`:
```yaml
  php:
    volumes:
      - ./php.ini:/usr/local/etc/php/conf.d/custom.ini
```

### Optimize Nginx

Edit `/opt/webstack/sites/shop/nginx.conf`:
```nginx
server {
    listen 80;
    server_name _;
    root /var/www/html;
    index index.php;

    client_max_body_size 100M;

    # Enable gzip
    gzip on;
    gzip_vary on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml;

    # Cache static files
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    location ~ \.php$ {
        fastcgi_pass php:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_buffer_size 128k;
        fastcgi_buffers 256 16k;
        fastcgi_busy_buffers_size 256k;
        fastcgi_read_timeout 300;
    }
}
```

### Install Redis Cache

In WordPress admin:
1. Install "Redis Object Cache" plugin
2. Activate it
3. Enable object cache

### Restart

```bash
webstack restart shop
```

---

## Development + Staging + Production

Set up three environments on one server.

### Setup

```bash
# Development
webstack create
# Site name: myapp-dev
# Domain: dev.example.com
# PHP: 8.3, MariaDB 11.2, Redis: y

# Staging
webstack create
# Site name: myapp-staging
# Domain: staging.example.com
# PHP: 8.3, MariaDB 11.2, Redis: y

# Production
webstack create
# Site name: myapp-prod
# Domain: www.example.com
# PHP: 8.3, MariaDB 11.2, Redis: y
```

### Deployment Script

Create `/usr/local/bin/deploy.sh`:
```bash
#!/bin/bash

ENVIRONMENT=$1

if [ -z "$ENVIRONMENT" ]; then
    echo "Usage: deploy.sh [dev|staging|prod]"
    exit 1
fi

case $ENVIRONMENT in
    dev)
        SITE="myapp-dev"
        BRANCH="develop"
        ;;
    staging)
        SITE="myapp-staging"
        BRANCH="staging"
        ;;
    prod)
        SITE="myapp-prod"
        BRANCH="main"
        ;;
    *)
        echo "Invalid environment"
        exit 1
        ;;
esac

echo "Deploying to $ENVIRONMENT..."

# Pull latest code
cd /opt/webstack/sites/$SITE/public
git pull origin $BRANCH

# Run migrations
docker exec -it ${SITE}_php sh -c "cd /var/www/html && php artisan migrate --force"

# Clear caches
docker exec -it ${SITE}_php sh -c "cd /var/www/html && php artisan cache:clear && php artisan config:cache"

# Restart
webstack restart $SITE

echo "Deployment to $ENVIRONMENT complete!"
```

Usage:
```bash
chmod +x /usr/local/bin/deploy.sh

# Deploy to dev
./deploy.sh dev

# Deploy to staging
./deploy.sh staging

# Deploy to production
./deploy.sh prod
```

---

## High-Traffic WordPress with Caching

Optimize WordPress for high traffic.

### Setup

```bash
webstack create
# Site name: hightraffic
# Domain: blog.example.com
# PHP: 8.2
# Database: MariaDB 11.2
# Redis: y
# phpMyAdmin: y
```

### Install FastCGI Cache

Edit `/opt/webstack/sites/hightraffic/nginx.conf`:
```nginx
fastcgi_cache_path /var/cache/nginx levels=1:2 keys_zone=WORDPRESS:100m inactive=60m;
fastcgi_cache_key "$scheme$request_method$host$request_uri";

server {
    listen 80;
    server_name _;
    root /var/www/html;
    index index.php;

    set $skip_cache 0;

    # Don't cache POST requests
    if ($request_method = POST) {
        set $skip_cache 1;
    }

    # Don't cache logged in users
    if ($http_cookie ~* "comment_author|wordpress_[a-f0-9]+|wp-postpass|wordpress_logged_in") {
        set $skip_cache 1;
    }

    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    location ~ \.php$ {
        fastcgi_pass php:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;

        fastcgi_cache_bypass $skip_cache;
        fastcgi_no_cache $skip_cache;
        fastcgi_cache WORDPRESS;
        fastcgi_cache_valid 200 60m;
    }

    location ~ /purge(/.*) {
        fastcgi_cache_purge WORDPRESS "$scheme$request_method$host$1";
    }
}
```

Update `docker-compose.yml` to add cache volume:
```yaml
  web:
    volumes:
      - ./public:/var/www/html:ro
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
      - cache:/var/cache/nginx

volumes:
  db_data:
  cache:
```

### Install Caching Plugins

1. Redis Object Cache
2. Nginx Helper (for cache purging)

### Monitor Performance

```bash
# Check cache hit rate
docker exec hightraffic_web cat /var/log/nginx/access.log | grep -o 'HIT\|MISS' | sort | uniq -c
```

---

## Tips & Best Practices

### Regular Maintenance

```bash
# Weekly: Update Docker images
docker images --format "{{.Repository}}:{{.Tag}}" | xargs -L1 docker pull

# Weekly: Clean up Docker
docker system prune -f

# Daily: Backup critical sites
webstack backup important-site

# Monthly: Review logs
webstack logs mysite | grep -i error
```

### Security

```bash
# Disable directory listing in Nginx
location / {
    autoindex off;
}

# Hide PHP version
# Add to php.ini
expose_php = Off

# Limit request size
client_max_body_size 10M;
```

### Performance Monitoring

Install monitoring tools:
```bash
# Install htop
apt install htop

# Monitor resources
htop

# Check Docker stats
docker stats

# WebStack status
webstack status
```

---

**Need more examples? Open an issue on GitHub!**

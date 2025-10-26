# WebStack Manager

**Professional Multi-Environment Web Stack Management System**

WebStack Manager is a powerful, production-ready tool for managing multiple isolated web environments on a single server. Perfect for agencies, developers, and hosting providers who need to run multiple websites with different technology stacks.

## Features

- **Multi-OS Support**: Works on Debian, Ubuntu, AlmaLinux, Rocky Linux, and RHEL
- **Complete Isolation**: Each site runs in its own Docker containers
- **Version Flexibility**: Mix and match PHP versions (7.4, 8.0, 8.1, 8.2, 8.3)
- **Database Options**: MySQL (5.7, 8.0), MariaDB (10.11, 11.2), PostgreSQL (16)
- **Automatic SSL**: Let's Encrypt certificates via Traefik reverse proxy
- **Interactive Setup**: Guided prompts for all configuration
- **Easy Management**: Simple CLI for all operations
- **Built-in Backups**: One-command site backups
- **Resource Monitoring**: Track CPU, memory, and disk usage

## Architecture

```
┌─────────────────────────────────────────────┐
│           Traefik Reverse Proxy             │
│     (Automatic SSL + Load Balancing)        │
└─────────────────┬───────────────────────────┘
                  │
        ┌─────────┴─────────┐
        │                   │
┌───────▼──────┐    ┌──────▼───────┐
│   Site 1     │    │   Site 2     │
│ PHP 8.3      │    │ PHP 7.4      │
│ MariaDB 11   │    │ MySQL 5.7    │
│ + Redis      │    │              │
└──────────────┘    └──────────────┘
```

## System Requirements

- **OS**: Debian 11+, Ubuntu 20.04+, AlmaLinux 8+, Rocky Linux 8+
- **RAM**: Minimum 2GB (4GB+ recommended)
- **Disk**: 20GB+ free space
- **Ports**: 80, 443 available
- **Access**: Root or sudo privileges

## Quick Start

### 1. Download and Install

```bash
# Download the installer
wget https://raw.githubusercontent.com/yourusername/webstack/main/webstack-install.sh

# Make it executable
chmod +x webstack-install.sh

# Run the installer as root
sudo ./webstack-install.sh
```

The installer will:
1. Detect your operating system
2. Install Docker and Docker Compose
3. Set up Traefik reverse proxy
4. Prompt for your SSL email address
5. Install the `webstack` CLI tool

### 2. Create Your First Site

```bash
webstack create
```

You'll be prompted for:
- Site name (e.g., `mysite`)
- Domain name (e.g., `example.com`)
- PHP version (7.4, 8.0, 8.1, 8.2, 8.3)
- Database type (MySQL, MariaDB, PostgreSQL)
- Database credentials
- Additional services (Redis, Adminer)

### 3. Point Your Domain

Update your domain's DNS to point to your server's IP:

```
A    example.com        →  YOUR.SERVER.IP
A    www.example.com    →  YOUR.SERVER.IP
```

### 4. Access Your Site

Visit `https://example.com` - SSL certificate will be automatically generated on first visit!

## CLI Commands

### Site Management

```bash
# Create a new site (interactive)
webstack create

# List all sites
webstack list

# Start a site
webstack start mysite

# Stop a site
webstack stop mysite

# Restart a site
webstack restart mysite

# Delete a site (with confirmation)
webstack delete mysite
```

### Monitoring & Maintenance

```bash
# View site information
webstack info mysite

# View logs (real-time)
webstack logs mysite           # Web server logs
webstack logs mysite php       # PHP-FPM logs
webstack logs mysite db        # Database logs

# System status
webstack status

# Create backup
webstack backup mysite
```

## Configuration Examples

### Example 1: WordPress Site

```bash
webstack create
  Site name: myblog
  Domain: myblog.com
  PHP version: 8.1
  Database: MariaDB 10.11
  Add Redis: y
  Add phpMyAdmin: y
```

Then upload WordPress files to `/opt/webstack/sites/myblog/public/`

### Example 2: Laravel Application

```bash
webstack create
  Site name: myapp
  Domain: myapp.com
  PHP version: 8.3
  Database: MySQL 8.0
  Add Redis: y
  Add phpMyAdmin: n
```

Upload your Laravel app and update `.env` with provided database credentials.

### Example 3: Legacy PHP Application

```bash
webstack create
  Site name: legacy
  Domain: old-app.com
  PHP version: 7.4
  Database: MySQL 5.7
  Add Redis: n
  Add phpMyAdmin: y
```

## Directory Structure

```
/opt/webstack/
├── sites/
│   ├── site1/
│   │   ├── public/              # Web root (upload files here)
│   │   ├── logs/                # Site-specific logs
│   │   ├── docker-compose.yml   # Container configuration
│   │   ├── nginx.conf           # Web server config
│   │   ├── .env                 # Site credentials
│   │   └── README.md            # Site info
│   └── site2/
│       └── ...
├── traefik/
│   ├── traefik.yml              # Traefik configuration
│   ├── acme/                    # SSL certificates
│   └── docker-compose.yml
├── backups/                     # Site backups
├── templates/                   # Docker templates
└── logs/                        # System logs
```

## Advanced Usage

### Custom Nginx Configuration

Edit the site's Nginx config:

```bash
nano /opt/webstack/sites/mysite/nginx.conf
webstack restart mysite
```

### Database Access

Each site includes database credentials in `/opt/webstack/sites/mysite/.env`:

```bash
cat /opt/webstack/sites/mysite/.env
```

Connect directly to the database:

```bash
docker exec -it mysite_db mysql -u mysite_user -p
```

### Adding PHP Extensions

Create a custom Dockerfile in the site directory:

```dockerfile
FROM php:8.3-fpm-alpine
RUN docker-php-ext-install mysqli pdo pdo_mysql gd
```

Update `docker-compose.yml` to use the custom image.

### Resource Limits

Add resource limits to `docker-compose.yml`:

```yaml
services:
  php:
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 512M
```

### Scheduled Backups

Add to crontab:

```bash
# Backup all sites daily at 2 AM
0 2 * * * webstack backup mysite
```

## Monitoring

### View System Status

```bash
webstack status
```

Shows:
- Traefik status
- Sites count (total, running, stopped)
- Docker resource usage
- Disk usage

### View Real-Time Logs

```bash
# Web server access logs
webstack logs mysite web

# PHP error logs
webstack logs mysite php

# Database logs
webstack logs mysite db

# All services
cd /opt/webstack/sites/mysite && docker compose logs -f
```

### Check SSL Certificates

```bash
# View certificate expiry
docker exec traefik cat /acme/acme.json | jq
```

## Troubleshooting

### Site Not Accessible

1. Check if containers are running:
   ```bash
   webstack list
   ```

2. Check Traefik logs:
   ```bash
   docker logs traefik
   ```

3. Verify DNS is pointing to server:
   ```bash
   nslookup yourdomain.com
   ```

4. Check site logs:
   ```bash
   webstack logs mysite
   ```

### SSL Certificate Not Generating

1. Ensure ports 80 and 443 are open:
   ```bash
   netstat -tlnp | grep -E ':(80|443)'
   ```

2. Verify email in Traefik config:
   ```bash
   cat /opt/webstack/traefik/traefik.yml
   ```

3. Check Traefik logs for ACME errors:
   ```bash
   docker logs traefik | grep -i acme
   ```

### Database Connection Failed

1. Verify credentials:
   ```bash
   cat /opt/webstack/sites/mysite/.env
   ```

2. Check database container:
   ```bash
   docker ps | grep mysite_db
   docker logs mysite_db
   ```

3. Test connection:
   ```bash
   docker exec -it mysite_db mysql -u mysite_user -p
   ```

### Out of Disk Space

1. Check Docker disk usage:
   ```bash
   docker system df
   ```

2. Clean up unused images and volumes:
   ```bash
   docker system prune -a --volumes
   ```

3. Remove old backups:
   ```bash
   ls -lh /opt/webstack/backups/
   rm /opt/webstack/backups/old_backup.tar.gz
   ```

## Security Best Practices

1. **Firewall Configuration**
   ```bash
   # Allow only HTTP, HTTPS, and SSH
   ufw allow 22/tcp
   ufw allow 80/tcp
   ufw allow 443/tcp
   ufw enable
   ```

2. **Regular Updates**
   ```bash
   # Update system packages
   apt update && apt upgrade -y    # Debian/Ubuntu
   dnf update -y                   # AlmaLinux

   # Update Docker images
   docker images --format "{{.Repository}}:{{.Tag}}" | xargs -L1 docker pull
   ```

3. **Strong Passwords**
   - Use auto-generated passwords (default)
   - Store credentials securely
   - Never commit `.env` files to version control

4. **Regular Backups**
   ```bash
   # Set up automated backups
   0 2 * * * /usr/local/bin/webstack backup site1
   0 3 * * * /usr/local/bin/webstack backup site2
   ```

5. **Monitor Logs**
   ```bash
   # Check for suspicious activity
   webstack logs mysite | grep -i "error\|warning\|fail"
   ```

## Performance Optimization

### Enable OPcache

Create `php.ini` in site directory:

```ini
[opcache]
opcache.enable=1
opcache.memory_consumption=128
opcache.max_accelerated_files=10000
opcache.revalidate_freq=2
```

Mount it in `docker-compose.yml`:

```yaml
php:
  volumes:
    - ./php.ini:/usr/local/etc/php/conf.d/custom.ini
```

### Use Redis for Caching

When creating a site, answer 'y' to add Redis. Configure your application:

```php
// WordPress wp-config.php
define('WP_REDIS_HOST', 'redis');
define('WP_REDIS_PORT', 6379);

// Laravel .env
REDIS_HOST=redis
REDIS_PORT=6379
```

### Increase PHP Limits

Edit site's Nginx config:

```nginx
client_max_body_size 100M;
```

Add to PHP environment in `docker-compose.yml`:

```yaml
php:
  environment:
    - PHP_MEMORY_LIMIT=256M
    - PHP_UPLOAD_MAX_FILESIZE=100M
    - PHP_POST_MAX_SIZE=100M
```

## Migration

### Migrate from Another Server

1. Create backup on old server:
   ```bash
   tar -czf site-backup.tar.gz /var/www/html /path/to/database-dump.sql
   ```

2. Transfer to new server:
   ```bash
   scp site-backup.tar.gz user@newserver:/tmp/
   ```

3. Create site on new server:
   ```bash
   webstack create  # Use same configuration
   ```

4. Extract files:
   ```bash
   tar -xzf /tmp/site-backup.tar.gz -C /opt/webstack/sites/mysite/public/
   ```

5. Import database:
   ```bash
   docker exec -i mysite_db mysql -u user -p database < dump.sql
   ```

### Export a Site

```bash
# Create full backup
webstack backup mysite

# Backup file location
ls -lh /opt/webstack/backups/mysite_*.tar.gz
```

## Uninstallation

To completely remove WebStack Manager:

```bash
# Stop all sites
for site in /opt/webstack/sites/*; do
  cd "$site" && docker compose down -v
done

# Stop Traefik
cd /opt/webstack/traefik && docker compose down

# Remove Docker network
docker network rm webstack

# Remove files
rm -rf /opt/webstack
rm /usr/local/bin/webstack

# Optional: Remove Docker
apt remove docker-ce docker-ce-cli containerd.io  # Debian/Ubuntu
dnf remove docker-ce docker-ce-cli containerd.io  # AlmaLinux
```

## FAQ

**Q: Can I run sites on different PHP versions simultaneously?**
A: Yes! Each site is completely isolated and can use any supported PHP version.

**Q: How many sites can I host?**
A: Limited only by your server resources. We recommend 4-8 sites per 4GB RAM.

**Q: Does this work with WordPress/Laravel/Drupal?**
A: Yes! It works with any PHP application. Just upload files to the `public/` directory.

**Q: Can I use custom domains?**
A: Yes! Point any domain's DNS to your server and configure it during site creation.

**Q: Are SSL certificates free?**
A: Yes! Traefik automatically generates free Let's Encrypt SSL certificates.

**Q: How do I add more PHP extensions?**
A: Create a custom Dockerfile or use the pre-installed `docker-php-ext-install` command.

**Q: Can I use this in production?**
A: Absolutely! This is designed for production use with automatic SSL, monitoring, and backups.

## Support

- **Documentation**: [Full documentation](https://github.com/yourusername/webstack/wiki)
- **Issues**: [Report bugs](https://github.com/yourusername/webstack/issues)
- **Discussions**: [Community forum](https://github.com/yourusername/webstack/discussions)

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

MIT License - See LICENSE file for details

## Credits

Built with:
- [Docker](https://www.docker.com/)
- [Traefik](https://traefik.io/)
- [Let's Encrypt](https://letsencrypt.org/)
- [Nginx](https://nginx.org/)
- [PHP](https://www.php.net/)

---

**Made with ❤️ for developers who need flexibility without complexity**

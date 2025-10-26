# WebStack Manager - Quick Start Guide

Get your first site running in 5 minutes!

## Step 1: Install (2 minutes)

```bash
# Download the installer
wget https://raw.githubusercontent.com/yourusername/webstack/main/webstack-install.sh

# Make executable
chmod +x webstack-install.sh

# Run as root
sudo ./webstack-install.sh
```

**What you'll be asked:**
- SSL email address (for Let's Encrypt certificates)

That's it! The script handles everything else.

## Step 2: Create a Site (2 minutes)

```bash
webstack create
```

**Follow the prompts:**

1. **Site name**: `mysite` (lowercase, alphanumeric)
2. **Domain**: `example.com` (your actual domain)
3. **PHP version**: Choose 1-5 (recommend: `1` for PHP 8.3)
4. **Database**: Choose 1-5 (recommend: `1` for MariaDB 11.2)
5. **Database name**: Press Enter (auto: `mysite_db`)
6. **Database user**: Press Enter (auto: `mysite_user`)
7. **Database password**: Press Enter (auto-generated secure password)
8. **Add Redis**: `n` (not needed for basic sites)
9. **Add phpMyAdmin**: `y` (helpful for database management)

**Done!** Your site is created and running.

## Step 3: Point Your Domain (1 minute)

Update your domain's DNS settings:

```
Type: A
Name: @
Value: YOUR_SERVER_IP

Type: A
Name: www
Value: YOUR_SERVER_IP
```

## Step 4: Upload Files

Upload your website files to:

```bash
/opt/webstack/sites/mysite/public/
```

**Using SCP:**
```bash
scp -r ./my-website/* root@YOUR_SERVER_IP:/opt/webstack/sites/mysite/public/
```

**Using SFTP:**
```
Host: YOUR_SERVER_IP
Path: /opt/webstack/sites/mysite/public/
```

## Step 5: Visit Your Site

Open your browser:
```
https://example.com
```

SSL certificate will auto-generate on first visit (takes 30-60 seconds).

## Example Workflows

### WordPress Site

1. **Create site:**
   ```bash
   webstack create
   # Name: myblog
   # Domain: myblog.com
   # PHP: 8.1
   # Database: MariaDB 10.11
   # Redis: y
   # phpMyAdmin: y
   ```

2. **Download WordPress:**
   ```bash
   cd /opt/webstack/sites/myblog/public
   wget https://wordpress.org/latest.tar.gz
   tar -xzf latest.tar.gz --strip-components=1
   rm latest.tar.gz
   ```

3. **Get database credentials:**
   ```bash
   cat /opt/webstack/sites/myblog/.env
   ```

4. **Visit site and install:**
   ```
   https://myblog.com
   ```

### Laravel Application

1. **Create site:**
   ```bash
   webstack create
   # Name: myapp
   # Domain: myapp.com
   # PHP: 8.3
   # Database: MySQL 8.0
   ```

2. **Upload Laravel app:**
   ```bash
   scp -r ./my-laravel-app/* root@SERVER:/opt/webstack/sites/myapp/public/
   ```

3. **Update Laravel .env:**
   ```bash
   nano /opt/webstack/sites/myapp/public/.env
   ```

   Use credentials from:
   ```bash
   cat /opt/webstack/sites/myapp/.env
   ```

4. **Install dependencies:**
   ```bash
   docker exec -it myapp_php sh
   cd /var/www/html
   composer install
   php artisan key:generate
   php artisan migrate
   ```

### Static HTML Site

1. **Create site:**
   ```bash
   webstack create
   # Name: portfolio
   # Domain: myportfolio.com
   # PHP: 8.3 (still needed for .php files)
   # Database: MariaDB 11.2 (won't be used)
   ```

2. **Upload files:**
   ```bash
   scp -r ./dist/* root@SERVER:/opt/webstack/sites/portfolio/public/
   ```

3. **Done!** Visit: `https://myportfolio.com`

## Common Commands

```bash
# List all sites
webstack list

# View site info and credentials
webstack info mysite

# View real-time logs
webstack logs mysite

# Restart a site
webstack restart mysite

# Create backup
webstack backup mysite

# Check system status
webstack status
```

## Troubleshooting

### Site shows "404 Not Found"

```bash
# Check if containers are running
webstack list

# Start the site if stopped
webstack start mysite

# Check logs
webstack logs mysite
```

### "SSL Certificate Error"

Wait 1-2 minutes on first visit. Certificate generation takes time.

```bash
# Check Traefik logs
docker logs traefik | tail -20
```

### Database Connection Error

```bash
# Get correct credentials
cat /opt/webstack/sites/mysite/.env

# Test database connection
docker exec -it mysite_db mysql -u mysite_user -p
```

### Can't Access phpMyAdmin

If you enabled phpMyAdmin, access it at:
```
https://db.example.com
```

Login with credentials from:
```bash
cat /opt/webstack/sites/mysite/.env
```

## Next Steps

- **Security**: Set up firewall (see README)
- **Backups**: Schedule automatic backups (see README)
- **Monitoring**: Set up monitoring tools
- **Optimization**: Enable OPcache and Redis
- **Multiple Sites**: Repeat the process for more sites!

## Getting Help

- Read the full [README.md](README.md)
- Check [Troubleshooting Guide](README.md#troubleshooting)
- Open an [issue on GitHub](https://github.com/yourusername/webstack/issues)

---

**You're all set! Happy hosting!**

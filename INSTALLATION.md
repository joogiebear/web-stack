# WebStack Manager - Installation Guide

Complete installation instructions for all supported operating systems.

## Supported Operating Systems

- Debian 11 (Bullseye) and newer
- Ubuntu 20.04 LTS and newer
- AlmaLinux 8 and newer
- Rocky Linux 8 and newer
- RHEL 8 and newer

## Pre-Installation Checklist

Before installing, ensure your server meets these requirements:

- [ ] Fresh or clean server (recommended)
- [ ] Root or sudo access
- [ ] Minimum 2GB RAM (4GB+ recommended)
- [ ] 20GB+ free disk space
- [ ] Ports 80 and 443 available
- [ ] Server has internet access
- [ ] Valid email address (for SSL certificates)

## Installation Methods

### Method 1: One-Line Installation (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/joogiebear/web-stack/main/webstack-install.sh | sudo bash
```

### Method 2: Manual Installation

1. **Download the installer:**
   ```bash
   wget https://raw.githubusercontent.com/joogiebear/web-stack/main/webstack-install.sh
   ```

2. **Make it executable:**
   ```bash
   chmod +x webstack-install.sh
   ```

3. **Run the installer:**
   ```bash
   sudo ./webstack-install.sh
   ```

### Method 3: From Git Repository

```bash
git clone https://github.com/joogiebear/web-stack.git
cd web-stack
sudo ./webstack-install.sh
```

## Installation Process

The installer will perform these steps:

### 1. System Detection
- Detects your operating system
- Checks for root privileges
- Validates system compatibility

### 2. System Updates
- Updates package lists
- Upgrades existing packages

### 3. Prerequisites Installation
- Installs required system packages
- Installs curl, wget, git, jq, etc.

### 4. Docker Installation
- Adds Docker's official repository
- Installs Docker CE
- Installs Docker Compose plugin
- Starts and enables Docker service

### 5. Directory Structure
Creates the following structure:
```
/opt/webstack/
├── sites/          # Your website directories
├── traefik/        # Reverse proxy configuration
├── templates/      # Site templates
├── backups/        # Backup storage
└── logs/           # System logs
```

### 6. Traefik Setup
- **Prompts for SSL email** (required for Let's Encrypt)
- Configures Traefik reverse proxy
- Sets up automatic HTTPS redirect
- Creates Docker network
- Starts Traefik container

### 7. CLI Installation
- Installs `webstack` command to `/usr/local/bin/`
- Makes it globally accessible

## Installation Time

- **Debian/Ubuntu**: 3-5 minutes
- **AlmaLinux/Rocky**: 4-6 minutes

Time varies based on server speed and internet connection.

## Post-Installation

After installation completes, you'll see:

```
╔════════════════════════════════════════╗
║     Installation Complete!              ║
╚════════════════════════════════════════╝

WebStack Manager has been successfully installed!

Installation directory: /opt/webstack
CLI command: webstack
```

### Verify Installation

```bash
# Check webstack is available
webstack help

# Check Docker is running
docker --version
docker compose version

# Check Traefik is running
docker ps | grep traefik
```

## OS-Specific Notes

### Debian/Ubuntu

```bash
# Update system first (recommended)
sudo apt update && sudo apt upgrade -y

# Install webstack
sudo ./webstack-install.sh
```

**Note**: If you're using Debian 11, ensure you have the latest updates.

### AlmaLinux/Rocky Linux

```bash
# Update system first (recommended)
sudo dnf update -y

# Install webstack
sudo ./webstack-install.sh
```

**Note**: SELinux may need to be configured. The installer handles this automatically.

### Ubuntu on AWS/DigitalOcean

If using UFW firewall:

```bash
# Before installation, allow HTTP/HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable

# Then install
sudo ./webstack-install.sh
```

### AlmaLinux on AWS/DigitalOcean

If using firewalld:

```bash
# Before installation, allow HTTP/HTTPS
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload

# Then install
sudo ./webstack-install.sh
```

## Firewall Configuration

### Using UFW (Debian/Ubuntu)

```bash
# Allow SSH (if not already allowed)
sudo ufw allow 22/tcp

# Allow HTTP and HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Enable firewall
sudo ufw enable

# Check status
sudo ufw status
```

### Using firewalld (AlmaLinux/Rocky)

```bash
# Allow HTTP and HTTPS
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload

# Check status
sudo firewall-cmd --list-all
```

### Using iptables

```bash
# Allow HTTP
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT

# Allow HTTPS
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# Save rules
sudo iptables-save > /etc/iptables/rules.v4
```

## Cloud Provider Specific Setup

### DigitalOcean

1. Create a Droplet (Ubuntu 22.04 recommended)
2. Minimum: 2GB RAM / 1 CPU / 50GB SSD
3. SSH into your droplet
4. Run the installer

```bash
ssh root@your-droplet-ip
curl -fsSL https://raw.githubusercontent.com/joogiebear/web-stack/main/webstack-install.sh | bash
```

### AWS EC2

1. Launch an instance (Ubuntu 22.04 or Amazon Linux 2023)
2. Instance type: t3.small or larger
3. Configure Security Group to allow ports 22, 80, 443
4. SSH into your instance
5. Run the installer

```bash
ssh -i your-key.pem ubuntu@your-ec2-ip
sudo su
curl -fsSL https://raw.githubusercontent.com/joogiebear/web-stack/main/webstack-install.sh | bash
```

### Linode

1. Create a Linode (Ubuntu 22.04 recommended)
2. Minimum: Linode 2GB
3. SSH into your Linode
4. Run the installer

```bash
ssh root@your-linode-ip
curl -fsSL https://raw.githubusercontent.com/joogiebear/web-stack/main/webstack-install.sh | bash
```

### Vultr

1. Deploy a server (Ubuntu 22.04 recommended)
2. Minimum: 2GB RAM
3. SSH into your server
4. Run the installer

```bash
ssh root@your-vultr-ip
curl -fsSL https://raw.githubusercontent.com/joogiebear/web-stack/main/webstack-install.sh | bash
```

## Offline Installation

If your server doesn't have internet access, you can prepare an offline installation:

1. **On a machine with internet:**
   ```bash
   # Download Docker packages
   apt download docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

   # Download webstack
   git clone https://github.com/joogiebear/web-stack.git
   ```

2. **Transfer to offline server**

3. **Install manually:**
   ```bash
   # Install Docker packages
   dpkg -i *.deb

   # Run webstack installer
   cd web-stack
   ./webstack-install.sh
   ```

## Troubleshooting Installation

### Issue: "Docker installation failed"

**Solution:**
```bash
# Remove any existing Docker installations
sudo apt remove docker docker-engine docker.io containerd runc

# Clean up
sudo apt autoremove -y

# Try installation again
sudo ./webstack-install.sh
```

### Issue: "Port 80 or 443 already in use"

**Solution:**
```bash
# Check what's using the ports
sudo netstat -tlnp | grep -E ':(80|443)'

# If Apache is running
sudo systemctl stop apache2
sudo systemctl disable apache2

# If Nginx is running
sudo systemctl stop nginx
sudo systemctl disable nginx

# Try installation again
sudo ./webstack-install.sh
```

### Issue: "Permission denied"

**Solution:**
```bash
# Ensure you're running as root
sudo su

# Run the installer
./webstack-install.sh
```

### Issue: "Network timeout during installation"

**Solution:**
```bash
# Check internet connectivity
ping -c 4 google.com

# Check DNS resolution
nslookup docker.com

# If DNS issues, temporarily use Google DNS
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf

# Try installation again
sudo ./webstack-install.sh
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

# Remove network
docker network rm webstack

# Remove files
sudo rm -rf /opt/webstack
sudo rm /usr/local/bin/webstack

# Optional: Remove Docker
# Debian/Ubuntu
sudo apt remove docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo apt autoremove -y

# AlmaLinux/Rocky
sudo dnf remove docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

## Upgrading

To upgrade WebStack to the latest version:

```bash
# Download latest installer
wget https://raw.githubusercontent.com/joogiebear/web-stack/main/webstack-install.sh

# Run installer (it will detect existing installation)
sudo ./webstack-install.sh
```

Your sites and data will be preserved during upgrade.

## Getting Help

If you encounter issues during installation:

1. **Check the logs:**
   ```bash
   journalctl -u docker
   docker logs traefik
   ```

2. **Run diagnostics:**
   ```bash
   ./webstack-troubleshoot.sh --full
   ```

3. **Report an issue:**
   - GitHub Issues: https://github.com/joogiebear/web-stack/issues
   - Include: OS version, error messages, installation logs

## Next Steps

After successful installation:

1. **Create your first site:**
   ```bash
   webstack create
   ```

2. **Read the Quick Start:**
   - See [QUICKSTART.md](QUICKSTART.md)

3. **Configure firewall:**
   - See "Firewall Configuration" above

4. **Set up backups:**
   - See [README.md](README.md#backup)

---

**Installation complete? Create your first site with `webstack create`!**

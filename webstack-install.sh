#!/bin/bash

################################################################################
# WebStack Manager - Universal Installer
# Supports: Debian, Ubuntu, AlmaLinux, Rocky Linux, RHEL
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Installation directory
INSTALL_DIR="/opt/webstack"
BIN_DIR="/usr/local/bin"

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo -e "\n${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    else
        print_error "Cannot detect OS. /etc/os-release not found."
        exit 1
    fi

    case $OS in
        ubuntu|debian)
            OS_TYPE="debian"
            PACKAGE_MANAGER="apt"
            ;;
        almalinux|rocky|rhel|centos)
            OS_TYPE="redhat"
            PACKAGE_MANAGER="dnf"
            # Check if dnf exists, fallback to yum
            if ! command -v dnf &> /dev/null; then
                PACKAGE_MANAGER="yum"
            fi
            ;;
        *)
            print_error "Unsupported OS: $OS"
            exit 1
            ;;
    esac

    print_success "Detected OS: $OS $VER ($OS_TYPE-based)"
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root or with sudo"
        exit 1
    fi
}

# Update system packages
update_system() {
    print_header "Updating System Packages"

    case $OS_TYPE in
        debian)
            apt update -y
            apt upgrade -y
            ;;
        redhat)
            $PACKAGE_MANAGER update -y
            ;;
    esac

    print_success "System updated"
}

# Install prerequisites
install_prerequisites() {
    print_header "Installing Prerequisites"

    case $OS_TYPE in
        debian)
            apt install -y \
                ca-certificates \
                curl \
                gnupg \
                lsb-release \
                git \
                wget \
                nano \
                net-tools \
                jq
            ;;
        redhat)
            $PACKAGE_MANAGER install -y \
                ca-certificates \
                curl \
                gnupg \
                git \
                wget \
                nano \
                net-tools \
                jq \
                yum-utils
            ;;
    esac

    print_success "Prerequisites installed"
}

# Install Docker
install_docker() {
    print_header "Installing Docker"

    # Check if Docker is already installed
    if command -v docker &> /dev/null; then
        print_warning "Docker is already installed"
        docker --version
        return
    fi

    case $OS_TYPE in
        debian)
            # Add Docker's official GPG key
            install -m 0755 -d /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/$OS/gpg -o /etc/apt/keyrings/docker.asc
            chmod a+r /etc/apt/keyrings/docker.asc

            # Add Docker repository
            echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/$OS \
                $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
                tee /etc/apt/sources.list.d/docker.list > /dev/null

            apt update -y
            apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;
        redhat)
            # Add Docker repository
            $PACKAGE_MANAGER install -y yum-utils
            yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

            $PACKAGE_MANAGER install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;
    esac

    # Start and enable Docker
    systemctl start docker
    systemctl enable docker

    print_success "Docker installed successfully"
    docker --version
}

# Create directory structure
create_directories() {
    print_header "Creating Directory Structure"

    mkdir -p $INSTALL_DIR/{sites,traefik,templates,backups,logs}
    mkdir -p $INSTALL_DIR/traefik/{config,acme}

    # Set permissions
    chmod 600 $INSTALL_DIR/traefik/acme

    print_success "Directory structure created at $INSTALL_DIR"
}

# Setup Traefik reverse proxy
setup_traefik() {
    print_header "Setting Up Traefik Reverse Proxy"

    # Prompt for SSL email
    while true; do
        echo -n "Enter email address for SSL certificates (Let's Encrypt): "
        read SSL_EMAIL
        if [[ "$SSL_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            break
        else
            print_error "Invalid email address. Please try again."
        fi
    done

    # Create Traefik static configuration
    cat > $INSTALL_DIR/traefik/traefik.yml <<EOF
api:
  dashboard: true
  insecure: false

entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
  websecure:
    address: ":443"
    http:
      tls:
        certResolver: letsencrypt

certificatesResolvers:
  letsencrypt:
    acme:
      email: $SSL_EMAIL
      storage: /acme/acme.json
      httpChallenge:
        entryPoint: web

providers:
  docker:
    exposedByDefault: false
    network: webstack
  file:
    directory: /config
    watch: true

log:
  level: INFO
  filePath: /logs/traefik.log

accessLog:
  filePath: /logs/access.log
EOF

    # Create Traefik Docker Compose
    cat > $INSTALL_DIR/traefik/docker-compose.yml <<EOF
version: '3.8'

services:
  traefik:
    image: traefik:v3.0
    container_name: traefik
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    networks:
      - webstack
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./traefik.yml:/traefik.yml:ro
      - ./config:/config:ro
      - ./acme:/acme
      - ../logs:/logs
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.dashboard.rule=Host(\`traefik.localhost\`)"
      - "traefik.http.routers.dashboard.service=api@internal"
      - "traefik.http.routers.dashboard.entrypoints=websecure"
      - "traefik.http.routers.dashboard.tls.certresolver=letsencrypt"

networks:
  webstack:
    name: webstack
    driver: bridge
EOF

    # Create acme.json
    touch $INSTALL_DIR/traefik/acme/acme.json
    chmod 600 $INSTALL_DIR/traefik/acme/acme.json

    # Start Traefik
    cd $INSTALL_DIR/traefik
    docker compose up -d

    print_success "Traefik reverse proxy started"
    print_info "SSL email: $SSL_EMAIL"
}

# Create site templates
create_templates() {
    print_header "Creating Site Templates"

    # PHP 8.3 + MariaDB template
    cat > $INSTALL_DIR/templates/php8.3-mariadb.yml <<'EOF'
version: '3.8'

services:
  web:
    image: nginx:alpine
    container_name: {{SITE_NAME}}_web
    restart: unless-stopped
    networks:
      - {{SITE_NAME}}_internal
      - webstack
    volumes:
      - ./public:/var/www/html:ro
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.{{SITE_NAME}}.rule=Host(\`{{DOMAIN}}\`)"
      - "traefik.http.routers.{{SITE_NAME}}.entrypoints=websecure"
      - "traefik.http.routers.{{SITE_NAME}}.tls.certresolver=letsencrypt"
      - "traefik.http.services.{{SITE_NAME}}.loadbalancer.server.port=80"
      - "traefik.docker.network=webstack"
    depends_on:
      - php
      - db

  php:
    image: php:8.3-fpm-alpine
    container_name: {{SITE_NAME}}_php
    restart: unless-stopped
    networks:
      - {{SITE_NAME}}_internal
    volumes:
      - ./public:/var/www/html
    environment:
      - DB_HOST=db
      - DB_NAME={{DB_NAME}}
      - DB_USER={{DB_USER}}
      - DB_PASSWORD={{DB_PASSWORD}}

  db:
    image: mariadb:11.2
    container_name: {{SITE_NAME}}_db
    restart: unless-stopped
    networks:
      - {{SITE_NAME}}_internal
    volumes:
      - db_data:/var/lib/mysql
    environment:
      - MYSQL_ROOT_PASSWORD={{DB_ROOT_PASSWORD}}
      - MYSQL_DATABASE={{DB_NAME}}
      - MYSQL_USER={{DB_USER}}
      - MYSQL_PASSWORD={{DB_PASSWORD}}

networks:
  {{SITE_NAME}}_internal:
    driver: bridge
  webstack:
    external: true
    name: webstack

volumes:
  db_data:
EOF

    # PHP 8.2 + MySQL template
    cat > $INSTALL_DIR/templates/php8.2-mysql.yml <<'EOF'
version: '3.8'

services:
  web:
    image: nginx:alpine
    container_name: {{SITE_NAME}}_web
    restart: unless-stopped
    networks:
      - {{SITE_NAME}}_internal
      - webstack
    volumes:
      - ./public:/var/www/html:ro
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.{{SITE_NAME}}.rule=Host(\`{{DOMAIN}}\`)"
      - "traefik.http.routers.{{SITE_NAME}}.entrypoints=websecure"
      - "traefik.http.routers.{{SITE_NAME}}.tls.certresolver=letsencrypt"
      - "traefik.http.services.{{SITE_NAME}}.loadbalancer.server.port=80"
      - "traefik.docker.network=webstack"
    depends_on:
      - php
      - db

  php:
    image: php:8.2-fpm-alpine
    container_name: {{SITE_NAME}}_php
    restart: unless-stopped
    networks:
      - {{SITE_NAME}}_internal
    volumes:
      - ./public:/var/www/html
    environment:
      - DB_HOST=db
      - DB_NAME={{DB_NAME}}
      - DB_USER={{DB_USER}}
      - DB_PASSWORD={{DB_PASSWORD}}

  db:
    image: mysql:8.0
    container_name: {{SITE_NAME}}_db
    restart: unless-stopped
    networks:
      - {{SITE_NAME}}_internal
    volumes:
      - db_data:/var/lib/mysql
    environment:
      - MYSQL_ROOT_PASSWORD={{DB_ROOT_PASSWORD}}
      - MYSQL_DATABASE={{DB_NAME}}
      - MYSQL_USER={{DB_USER}}
      - MYSQL_PASSWORD={{DB_PASSWORD}}

networks:
  {{SITE_NAME}}_internal:
    driver: bridge
  webstack:
    external: true
    name: webstack

volumes:
  db_data:
EOF

    # Nginx config template
    cat > $INSTALL_DIR/templates/nginx.conf <<'EOF'
server {
    listen 80;
    server_name _;
    root /var/www/html;
    index index.php index.html index.htm;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass php:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

    print_success "Site templates created"
}

# Install webstack CLI
install_cli() {
    print_header "Installing WebStack CLI"

    # Copy CLI script to bin directory (will create in next step)
    # For now, create a placeholder
    cat > $BIN_DIR/webstack <<'EOFCLI'
#!/bin/bash
# WebStack Manager CLI
# This will be populated by the CLI script
echo "WebStack CLI - placeholder"
EOFCLI

    chmod +x $BIN_DIR/webstack

    print_success "WebStack CLI installed to $BIN_DIR/webstack"
}

# Final instructions
print_final_message() {
    print_header "Installation Complete!"

    echo -e "${GREEN}WebStack Manager has been successfully installed!${NC}\n"
    echo -e "Installation directory: ${BLUE}$INSTALL_DIR${NC}"
    echo -e "CLI command: ${BLUE}webstack${NC}\n"

    echo -e "${YELLOW}Available commands:${NC}"
    echo -e "  ${BLUE}webstack create${NC}      - Create a new site"
    echo -e "  ${BLUE}webstack list${NC}        - List all sites"
    echo -e "  ${BLUE}webstack start <site>${NC} - Start a site"
    echo -e "  ${BLUE}webstack stop <site>${NC}  - Stop a site"
    echo -e "  ${BLUE}webstack restart <site>${NC} - Restart a site"
    echo -e "  ${BLUE}webstack delete <site>${NC} - Delete a site"
    echo -e "  ${BLUE}webstack backup <site>${NC} - Backup a site"
    echo -e "  ${BLUE}webstack logs <site>${NC}  - View site logs"
    echo -e "  ${BLUE}webstack status${NC}      - Show system status\n"

    echo -e "${GREEN}Next steps:${NC}"
    echo -e "1. Run: ${BLUE}webstack create${NC} to create your first site"
    echo -e "2. Point your domain's DNS to this server's IP"
    echo -e "3. SSL certificates will be automatically generated\n"

    print_info "Traefik dashboard: https://traefik.localhost (update host in traefik/docker-compose.yml)"
}

################################################################################
# Main Installation Flow
################################################################################

main() {
    clear
    print_header "WebStack Manager - Universal Installer"

    check_root
    detect_os
    update_system
    install_prerequisites
    install_docker
    create_directories
    setup_traefik
    create_templates
    install_cli
    print_final_message
}

main "$@"

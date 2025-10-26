#!/bin/bash

################################################################################
# WebStack Troubleshooting Script
# Automated diagnostics and fixes for common issues
################################################################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}\n"
}

print_check() {
    echo -n "$1... "
}

print_ok() {
    echo -e "${GREEN}✓ OK${NC}"
}

print_fail() {
    echo -e "${RED}✗ FAILED${NC}"
}

print_warn() {
    echo -e "${YELLOW}⚠ WARNING${NC}"
}

################################################################################
# Diagnostic Functions
################################################################################

check_docker() {
    print_header "Checking Docker"

    print_check "Docker installed"
    if command -v docker &> /dev/null; then
        print_ok
        docker --version
    else
        print_fail
        echo "Docker is not installed. Please run webstack-install.sh"
        return 1
    fi

    print_check "Docker service running"
    if systemctl is-active --quiet docker; then
        print_ok
    else
        print_fail
        echo "Docker service is not running. Starting..."
        systemctl start docker
    fi

    print_check "Docker compose installed"
    if docker compose version &> /dev/null; then
        print_ok
        docker compose version
    else
        print_fail
        echo "Docker Compose plugin not found"
        return 1
    fi
}

check_traefik() {
    print_header "Checking Traefik Reverse Proxy"

    print_check "Traefik container running"
    if docker ps | grep -q traefik; then
        print_ok
        docker ps --filter name=traefik --format "Uptime: {{.Status}}"
    else
        print_fail
        echo "Traefik is not running. Attempting to start..."

        if [ -f "/opt/webstack/traefik/docker-compose.yml" ]; then
            cd /opt/webstack/traefik
            docker compose up -d
            print_ok
        else
            echo "Traefik configuration not found. Please reinstall."
            return 1
        fi
    fi

    print_check "Webstack network exists"
    if docker network ls | grep -q webstack; then
        print_ok
    else
        print_fail
        echo "Creating webstack network..."
        docker network create webstack
        print_ok
    fi

    print_check "Port 80 available"
    if netstat -tlnp | grep -q ':80 '; then
        print_ok
    else
        print_warn
        echo "Port 80 is not listening. Traefik may not be properly configured."
    fi

    print_check "Port 443 available"
    if netstat -tlnp | grep -q ':443 '; then
        print_ok
    else
        print_warn
        echo "Port 443 is not listening. SSL will not work."
    fi
}

check_disk_space() {
    print_header "Checking Disk Space"

    df -h / | tail -1 | awk '{
        used=$5;
        gsub(/%/, "", used);
        if (used > 90) {
            print "⚠ WARNING: Disk usage is at " used "%";
            exit 1;
        } else if (used > 80) {
            print "⚠ WARNING: Disk usage is at " used "% - consider cleanup";
            exit 2;
        } else {
            print "✓ OK: Disk usage is at " used "%";
            exit 0;
        }
    }'

    echo -e "\n${BLUE}Docker disk usage:${NC}"
    docker system df

    echo -e "\n${BLUE}Recommendation:${NC} Run 'docker system prune -a' to clean up unused images"
}

check_sites() {
    print_header "Checking Sites"

    if [ ! -d "/opt/webstack/sites" ]; then
        print_warn
        echo "No sites directory found"
        return
    fi

    local site_count=0
    local running_count=0
    local stopped_count=0

    for site_dir in /opt/webstack/sites/*; do
        if [ -d "$site_dir" ]; then
            ((site_count++))
            site_name=$(basename "$site_dir")

            print_check "Site: $site_name"

            cd "$site_dir"
            if docker compose ps | grep -q "Up"; then
                print_ok
                ((running_count++))
            else
                print_fail
                ((stopped_count++))
                echo "  Run: webstack start $site_name"
            fi

            # Check for SSL certificate
            if [ -f ".env" ]; then
                domain=$(grep "^DOMAIN=" .env | cut -d'=' -f2)
                if [ -n "$domain" ]; then
                    # Check if certificate exists in Traefik
                    if docker exec traefik cat /acme/acme.json 2>/dev/null | grep -q "$domain"; then
                        echo -e "  ${GREEN}✓${NC} SSL certificate exists for $domain"
                    else
                        echo -e "  ${YELLOW}⚠${NC} SSL certificate not found for $domain"
                        echo "    Visit https://$domain to trigger certificate generation"
                    fi
                fi
            fi
        fi
    done

    echo -e "\n${BLUE}Summary:${NC}"
    echo "  Total sites: $site_count"
    echo "  Running: $running_count"
    echo "  Stopped: $stopped_count"
}

check_dns() {
    print_header "DNS Configuration Check"

    if [ ! -d "/opt/webstack/sites" ]; then
        return
    fi

    for site_dir in /opt/webstack/sites/*; do
        if [ -d "$site_dir" ] && [ -f "$site_dir/.env" ]; then
            domain=$(grep "^DOMAIN=" "$site_dir/.env" | cut -d'=' -f2)

            if [ -n "$domain" ]; then
                print_check "DNS for $domain"

                if command -v nslookup &> /dev/null; then
                    ip=$(nslookup "$domain" 2>/dev/null | awk '/^Address: / { print $2 }' | tail -1)

                    if [ -n "$ip" ]; then
                        server_ip=$(curl -s ifconfig.me)
                        if [ "$ip" = "$server_ip" ]; then
                            print_ok
                            echo "  Points to: $ip (this server)"
                        else
                            print_warn
                            echo "  Points to: $ip (NOT this server: $server_ip)"
                        fi
                    else
                        print_fail
                        echo "  DNS resolution failed"
                    fi
                else
                    print_warn
                    echo "  nslookup not available - install with: apt install dnsutils"
                fi
            fi
        fi
    done
}

check_logs_for_errors() {
    print_header "Checking Logs for Errors"

    print_check "Traefik errors"
    error_count=$(docker logs traefik 2>&1 | grep -i error | wc -l)
    if [ "$error_count" -eq 0 ]; then
        print_ok
    else
        print_warn
        echo "  Found $error_count errors in Traefik logs"
        echo "  View with: docker logs traefik | grep -i error"
    fi

    if [ -d "/opt/webstack/sites" ]; then
        for site_dir in /opt/webstack/sites/*; do
            if [ -d "$site_dir" ]; then
                site_name=$(basename "$site_dir")
                cd "$site_dir"

                # Check web server errors
                if docker compose ps 2>/dev/null | grep -q "${site_name}_web.*Up"; then
                    print_check "Site $site_name web errors"
                    error_count=$(docker compose logs web 2>&1 | grep -i error | wc -l)
                    if [ "$error_count" -eq 0 ]; then
                        print_ok
                    else
                        print_warn
                        echo "  Found $error_count errors"
                        echo "  View with: webstack logs $site_name web"
                    fi
                fi
            fi
        done
    fi
}

auto_fix() {
    print_header "Attempting Automatic Fixes"

    # Fix 1: Restart Docker if not running
    if ! systemctl is-active --quiet docker; then
        echo "Starting Docker service..."
        systemctl start docker
        sleep 2
        print_ok
    fi

    # Fix 2: Create webstack network if missing
    if ! docker network ls | grep -q webstack; then
        echo "Creating webstack network..."
        docker network create webstack
        print_ok
    fi

    # Fix 3: Restart Traefik if not running
    if ! docker ps | grep -q traefik; then
        echo "Starting Traefik..."
        if [ -f "/opt/webstack/traefik/docker-compose.yml" ]; then
            cd /opt/webstack/traefik
            docker compose up -d
            print_ok
        fi
    fi

    # Fix 4: Restart stopped sites
    if [ -d "/opt/webstack/sites" ]; then
        for site_dir in /opt/webstack/sites/*; do
            if [ -d "$site_dir" ]; then
                site_name=$(basename "$site_dir")
                cd "$site_dir"

                if ! docker compose ps | grep -q "Up"; then
                    echo "Starting site: $site_name..."
                    docker compose up -d
                    print_ok
                fi
            fi
        done
    fi

    # Fix 5: Clean up disk space if needed
    used=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ "$used" -gt 85 ]; then
        echo "Cleaning up Docker resources..."
        docker system prune -f
        print_ok
    fi

    echo -e "\n${GREEN}Auto-fix complete!${NC}\n"
}

show_menu() {
    clear
    cat <<EOF
${BLUE}╔════════════════════════════════════════════╗${NC}
${BLUE}║    WebStack Troubleshooting Tool          ║${NC}
${BLUE}╚════════════════════════════════════════════╝${NC}

${YELLOW}Select an option:${NC}

  1) Full diagnostic check
  2) Check Docker
  3) Check Traefik
  4) Check sites
  5) Check DNS configuration
  6) Check logs for errors
  7) Attempt automatic fixes
  8) Exit

EOF
    echo -n "Choice [1-8]: "
}

main() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Please run as root or with sudo${NC}"
        exit 1
    fi

    while true; do
        show_menu
        read choice

        case $choice in
            1)
                check_docker
                check_traefik
                check_disk_space
                check_sites
                check_dns
                check_logs_for_errors
                echo -e "\n${BLUE}Press Enter to continue...${NC}"
                read
                ;;
            2)
                check_docker
                echo -e "\n${BLUE}Press Enter to continue...${NC}"
                read
                ;;
            3)
                check_traefik
                echo -e "\n${BLUE}Press Enter to continue...${NC}"
                read
                ;;
            4)
                check_sites
                echo -e "\n${BLUE}Press Enter to continue...${NC}"
                read
                ;;
            5)
                check_dns
                echo -e "\n${BLUE}Press Enter to continue...${NC}"
                read
                ;;
            6)
                check_logs_for_errors
                echo -e "\n${BLUE}Press Enter to continue...${NC}"
                read
                ;;
            7)
                auto_fix
                echo -e "\n${BLUE}Press Enter to continue...${NC}"
                read
                ;;
            8)
                echo -e "\n${GREEN}Goodbye!${NC}\n"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid choice${NC}"
                sleep 1
                ;;
        esac
    done
}

# If run with arguments, execute specific checks
if [ $# -gt 0 ]; then
    case $1 in
        --full)
            check_docker
            check_traefik
            check_disk_space
            check_sites
            check_dns
            check_logs_for_errors
            ;;
        --fix)
            auto_fix
            ;;
        *)
            echo "Usage: $0 [--full|--fix]"
            echo "  --full  Run all diagnostics"
            echo "  --fix   Attempt automatic fixes"
            exit 1
            ;;
    esac
else
    main
fi

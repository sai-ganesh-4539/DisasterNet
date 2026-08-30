# Deployment Guide

Guide for deploying the Disaster Management Platform on on-premise infrastructure.

## System Requirements

### Hardware Requirements

**Minimum Configuration:**
- CPU: 4 cores
- RAM: 16 GB
- Storage: 500 GB SSD
- Network: 1 Gbps

**Recommended Configuration:**
- CPU: 8+ cores
- RAM: 32+ GB
- Storage: 1 TB SSD
- Network: 10 Gbps

### Software Requirements

- **Operating System**: Linux (Ubuntu 20.04+, RHEL 8+, CentOS 8+)
- **Python**: 3.10+
- **PostgreSQL**: 14+ with PostGIS 3.3+
- **GDAL**: 3.4+
- **PROJ**: 9.0+
- **GEOS**: 3.11+

## Pre-Deployment Setup

### 1. System Preparation

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install system dependencies
sudo apt install -y \
    python3.10 \
    python3.10-venv \
    python3-pip \
    postgresql-14 \
    postgresql-14-postgis-3 \
    gdal-bin \
    libgdal-dev \
    libproj-dev \
    libgeos-dev \
    libspatialindex-dev \
    build-essential \
    git
```

### 2. User Setup

```bash
# Create dedicated user
sudo useradd -m -s /bin/bash disastermgmt
sudo usermod -aG sudo disastermgmt

# Switch to application user
sudo su - disastermgmt
```

### 3. Directory Structure

```bash
# Create application directories
mkdir -p /opt/disaster-management
mkdir -p /var/log/disaster-management
mkdir -p /etc/disaster-management
mkdir -p /data/disaster-management/backups
```

## Database Setup

### 1. PostgreSQL Installation

```bash
# Install PostgreSQL
sudo apt install -y postgresql-14 postgresql-contrib-14

# Start PostgreSQL service
sudo systemctl start postgresql
sudo systemctl enable postgresql
```

### 2. PostGIS Installation

```bash
# Install PostGIS
sudo apt install -y postgis postgresql-14-postgis-3

# Verify installation
sudo -u postgres psql -c "SELECT PostGIS_Version();"
```

### 3. Database Creation

```bash
# Switch to postgres user
sudo -u postgres psql

# Create database and user
CREATE DATABASE disaster_management;
CREATE USER disastermgmt WITH PASSWORD 'secure_password';
GRANT ALL PRIVILEGES ON DATABASE disaster_management TO disastermgmt;
\q
```

### 4. Schema Deployment

```bash
# Copy schema files
cp database/schemas/*.sql /tmp/

# Deploy schemas
sudo -u postgres psql -d disaster_management -f /tmp/01_spatial_extensions.sql
sudo -u postgres psql -d disaster_management -f /tmp/02_hazard_grids.sql
sudo -u postgres psql -d disaster_management -f /tmp/03_red_zones.sql
sudo -u postgres psql -d disaster_management -f /tmp/04_habitations.sql
sudo -u postgres psql -d disaster_management -f /tmp/05_shelters.sql
sudo -u postgres psql -d disaster_management -f /tmp/06_census_data.sql
sudo -u postgres psql -d disaster_management -f /tmp/07_environmental_data.sql
sudo -u postgres psql -d disaster_management -f /tmp/08_users_roles.sql
sudo -u postgres psql -d disaster_management -f /tmp/09_audit_log.sql
```

### 5. Database Optimization

```sql
-- Configure PostgreSQL for performance
ALTER SYSTEM SET shared_buffers = '8GB';
ALTER SYSTEM SET effective_cache_size = '24GB';
ALTER SYSTEM SET maintenance_work_mem = '2GB';
ALTER SYSTEM SET checkpoint_completion_target = 0.9;
ALTER SYSTEM SET wal_buffers = '16MB';
ALTER SYSTEM SET default_statistics_target = 100;
ALTER SYSTEM SET random_page_cost = 1.1;
ALTER SYSTEM SET effective_io_concurrency = 200;
ALTER SYSTEM SET work_mem = '32MB';

-- Reload configuration
SELECT pg_reload_conf();
```

## Application Deployment

### 1. Application Setup

```bash
# Clone repository
cd /opt/disaster-management
git clone <repository-url> .

# Create virtual environment
python3.10 -m venv venv
source venv/bin/activate

# Install dependencies
pip install --upgrade pip
pip install -r backend/requirements.txt
```

### 2. Configuration

```bash
# Copy environment template
cp backend/.env.example /etc/disaster-management/.env

# Edit configuration
nano /etc/disaster-management/.env
```

**Required Configuration:**
```bash
DATABASE_URL=postgresql://disastermgmt:secure_password@localhost:5432/disaster_management
SECRET_KEY=<generate-secure-key>
API_HOST=0.0.0.0
API_PORT=8000
DEBUG=false
LOG_LEVEL=INFO
LOG_FILE=/var/log/disaster-management/app.log
```

### 3. Systemd Service

Create systemd service file:

```bash
sudo nano /etc/systemd/system/disaster-management.service
```

**Service Configuration:**
```ini
[Unit]
Description=Disaster Management Platform API
After=network.target postgresql.service

[Service]
Type=simple
User=disastermgmt
Group=disastermgmt
WorkingDirectory=/opt/disaster-management
Environment="PATH=/opt/disaster-management/venv/bin"
EnvironmentFile=/etc/disaster-management/.env
ExecStart=/opt/disaster-management/venv/bin/python -m backend.app.main
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

```bash
# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable disaster-management
sudo systemctl start disaster-management
sudo systemctl status disaster-management
```

## Data Ingestion Scheduler

### 1. Scheduler Service

Create separate service for data ingestion:

```bash
sudo nano /etc/systemd/system/disaster-management-scheduler.service
```

**Scheduler Configuration:**
```ini
[Unit]
Description=Disaster Management Data Ingestion Scheduler
After=network.target postgresql.service disaster-management.service

[Service]
Type=simple
User=disastermgmt
Group=disastermgmt
WorkingDirectory=/opt/disaster-management
Environment="PATH=/opt/disaster-management/venv/bin"
EnvironmentFile=/etc/disaster-management/.env
ExecStart=/opt/disaster-management/venv/bin/python -c "from backend.app.ingestion.scheduler import DataIngestionScheduler; scheduler = DataIngestionScheduler(); scheduler.setup_all_schedules(); scheduler.run_scheduled_jobs()"
Restart=always
RestartSec=30
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

```bash
# Enable and start scheduler
sudo systemctl daemon-reload
sudo systemctl enable disaster-management-scheduler
sudo systemctl start disaster-management-scheduler
```

## SSL/TLS Configuration

### 1. SSL Certificate

```bash
# Generate self-signed certificate (for development)
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/disaster-management.key \
  -out /etc/ssl/certs/disaster-management.crt

# OR use Let's Encrypt for production
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d api.disaster-management.gov.in
```

### 2. Nginx Reverse Proxy

```bash
# Install Nginx
sudo apt install -y nginx

# Create Nginx configuration
sudo nano /etc/nginx/sites-available/disaster-management
```

**Nginx Configuration:**
```nginx
server {
    listen 80;
    server_name api.disaster-management.gov.in;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name api.disaster-management.gov.in;

    ssl_certificate /etc/ssl/certs/disaster-management.crt;
    ssl_certificate_key /etc/ssl/private/disaster-management.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    client_max_body_size 10M;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /docs {
        proxy_pass http://127.0.0.1:8000/docs;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

```bash
# Enable site
sudo ln -s /etc/nginx/sites-available/disaster-management /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

## Firewall Configuration

```bash
# Configure UFW
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 5432/tcp  # PostgreSQL (if remote access needed)
sudo ufw enable
```

## Monitoring Setup

### 1. Application Monitoring

```bash
# Install monitoring tools
sudo apt install -y htop iotop nethogs

# Create log rotation
sudo nano /etc/logrotate.d/disaster-management
```

**Log Rotation Configuration:**
```
/var/log/disaster-management/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0640 disastermgmt disastermgmt
    sharedscripts
    postrotate
        systemctl reload disaster-management > /dev/null 2>&1 || true
    endscript
}
```

### 2. Database Monitoring

```bash
# Enable PostgreSQL statistics
sudo -u postgres psql -d disaster_management -c "ALTER SYSTEM SET track_activities = on;"
sudo -u postgres psql -d disaster-management -c "SELECT pg_reload_conf();"
```

### 3. Performance Monitoring

Install monitoring agents (optional):
- Prometheus + Grafana
- DataDog
- New Relic
- Custom monitoring scripts

## Backup Strategy

### 1. Database Backups

```bash
# Create backup script
sudo nano /usr/local/bin/backup-database.sh
```

**Backup Script:**
```bash
#!/bin/bash
BACKUP_DIR="/data/disaster-management/backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/disaster_management_$DATE.sql.gz"

mkdir -p $BACKUP_DIR

pg_dump -U disastermgmt disaster_management | gzip > $BACKUP_FILE

# Keep last 7 days of backups
find $BACKUP_DIR -name "disaster_management_*.sql.gz" -mtime +7 -delete

echo "Backup completed: $BACKUP_FILE"
```

```bash
# Make executable
sudo chmod +x /usr/local/bin/backup-database.sh

# Add to cron
(crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/backup-database.sh") | crontab -
```

### 2. Application Backups

```bash
# Backup application configuration
sudo tar -czf /data/disaster-management/backups/config_$(date +%Y%m%d).tar.gz \
  /etc/disaster-management \
  /opt/disaster-management/config.yaml
```

## Testing Deployment

### 1. Health Check

```bash
# Check API health
curl http://localhost:8000/health

# Check database connection
sudo -u postgres psql -d disaster_management -c "SELECT version();"
```

### 2. API Testing

```bash
# Test authentication
curl -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username": "admin", "password": "password"}'

# Test hazard prediction
curl -X POST http://localhost:8000/api/v1/hazards/predict \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "latitude": 28.5,
    "longitude": 77.2,
    "precipitation_24h_mm": 45.0,
    "slope_percentage": 25.0,
    "elevation": 1500.0,
    "lithology": "GRANITE",
    "soil_moisture_index": 0.7,
    "vegetation_index": 0.6,
    "hazard_type": "landslide"
  }'
```

### 3. Load Testing

```bash
# Install locust
pip install locust

# Create load test script
# Run load test
locust -f load_test.py --host=http://localhost:8000
```

## Performance Tuning

### 1. Application Tuning

**Environment Variables:**
```bash
# In /etc/disaster-management/.env
WORKERS=4
WORKER_CLASS=uvicorn.workers.UvicornWorker
WORKER_CONNECTIONS=1000
MAX_REQUESTS=1000
MAX_REQUESTS_JITTER=100
GRACEFUL_TIMEOUT=30
TIMEOUT=120
```

### 2. Database Tuning

**PostgreSQL Configuration:**
```sql
-- Increase shared buffers for larger datasets
ALTER SYSTEM SET shared_buffers = '16GB';

-- Increase work memory for complex queries
ALTER SYSTEM SET work_mem = '64MB';

-- Configure parallel query processing
ALTER SYSTEM SET max_parallel_workers_per_gather = 4;
ALTER SYSTEM SET max_parallel_workers = 8;
ALTER SYSTEM SET max_parallel_maintenance_workers = 4;

-- Optimize WAL for write-heavy workloads
ALTER SYSTEM SET wal_buffers = '64MB';
ALTER SYSTEM SET checkpoint_completion_target = 0.9;
ALTER SYSTEM SET max_wal_size = '4GB';
ALTER SYSTEM SET min_wal_size = '1GB';
```

### 3. System Tuning

```bash
# Increase file descriptors
echo "* soft nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.conf

# Optimize network stack
sudo nano /etc/sysctl.conf
```

**System Configuration:**
```
net.core.somaxconn = 1024
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_local_port_range = 1024 65535
```

```bash
sudo sysctl -p
```

## Security Hardening

### 1. Application Security

```bash
# Change file permissions
sudo chmod 600 /etc/disaster-management/.env
sudo chmod 750 /opt/disaster-management
sudo chmod 640 /var/log/disaster-management/*

# Set up fail2ban
sudo apt install -y fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

### 2. Database Security

```sql
-- Restrict PostgreSQL access
-- Edit pg_hba.conf to allow only local and specific remote connections

-- Enable SSL for PostgreSQL
ALTER SYSTEM SET ssl = on;
ALTER SYSTEM SET ssl_cert_file = '/etc/ssl/certs/postgresql.crt';
ALTER SYSTEM SET ssl_key_file = '/etc/ssl/private/postgresql.key';
```

### 3. Network Security

```bash
# Install and configure fail2ban
sudo apt install -y fail2ban

# Create jail configuration
sudo nano /etc/fail2ban/jail.local
```

**Fail2ban Configuration:**
```ini
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
port = http,https
logpath = /var/log/nginx/error.log
```

## Troubleshooting

### Common Issues

**Service won't start:**
```bash
# Check logs
sudo journalctl -u disaster-management -n 50

# Check configuration
sudo systemctl cat disaster-management

# Test configuration
python -m backend.app.main --config-test
```

**Database connection issues:**
```bash
# Check PostgreSQL status
sudo systemctl status postgresql

# Check PostgreSQL logs
sudo tail -f /var/log/postgresql/postgresql-14-main.log

# Test connection
psql -U disastermgmt -d disaster_management -h localhost
```

**Performance issues:**
```bash
# Check system resources
htop
iotop
nethogs

# Check database performance
sudo -u postgres psql -d disaster_management -c "SELECT * FROM pg_stat_activity;"
```

## Maintenance

### Regular Maintenance Tasks

**Daily:**
- Check service status
- Review error logs
- Monitor disk space

**Weekly:**
- Review performance metrics
- Check database growth
- Update statistics

**Monthly:**
- Review and optimize slow queries
- Update security patches
- Test backup restoration

**Quarterly:**
- Review capacity planning
- Update ML models
- Performance tuning

### Maintenance Windows

Schedule maintenance during low-usage periods:
- Database maintenance: Sunday 2:00 AM - 4:00 AM
- Application updates: Sunday 4:00 AM - 6:00 AM
- System updates: Monthly first Sunday

## Scaling Considerations

### Horizontal Scaling

For increased capacity:
1. Deploy additional application servers
2. Use load balancer (Nginx, HAProxy)
3. Implement database read replicas
4. Use connection pooling

### Database Scaling

For large datasets:
1. Implement table partitioning
2. Use database sharding
3. Optimize spatial indexes
4. Consider read replicas for reporting

### Geographic Distribution

For multi-region deployment:
1. Deploy regional API servers
2. Use geographic load balancing
3. Implement data replication
4. Consider edge computing for field operations
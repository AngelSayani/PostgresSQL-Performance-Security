#!/bin/bash

# Configure PostgreSQL with suboptimal settings to demonstrate performance issues

# Get PostgreSQL version
PG_VER=$(ls /etc/postgresql/ | head -1)

# Set intentionally poor configuration
sudo bash -c "cat > /etc/postgresql/$PG_VER/main/conf.d/performance_demo.conf" << 'EOF'
# Intentionally poor settings for demonstration
shared_buffers = 128MB
work_mem = 4MB
maintenance_work_mem = 64MB
effective_cache_size = 4GB

# Disable logging initially (to be configured in lab)
log_min_duration_statement = -1
log_connections = off
log_disconnections = off
log_line_prefix = ''

# Allow connections from anywhere (insecure - to be fixed in lab)
listen_addresses = '*'

# Enable pg_stat_statements for query analysis
shared_preload_libraries = 'pg_stat_statements'
pg_stat_statements.track = all
pg_stat_statements.max = 10000
EOF

# Configure insecure pg_hba.conf
sudo bash -c "cat >> /etc/postgresql/$PG_VER/main/pg_hba.conf" << 'EOF'
# Insecure configuration for demonstration (to be secured in lab)
host    all             all             0.0.0.0/0               md5
EOF

# Restart PostgreSQL
sudo systemctl restart postgresql

# Enable pg_stat_statements extension
sudo -u postgres psql -d carvedrock -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"

echo "PostgreSQL configured with performance issues for lab demonstration"

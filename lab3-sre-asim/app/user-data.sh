#!/bin/bash
yum update -y
yum install -y httpd

cat << 'EOF' > /var/www/html/index.html
<h1>Lab 3 Web Server</h1>
<p>Welcome to the main page.</p>
EOF

cat << 'EOF' > /var/www/html/health.html
{"status": "ok", "dependencies": "none", "version": "v1"}
EOF

cat << 'EOF' > /etc/httpd/conf.d/health.conf
Alias /health /var/www/html/health.html
<Location /health>
    Require all granted
</Location>
EOF

systemctl enable httpd
systemctl restart httpd

# Graceful shutdown script
cat << 'EOF' > /usr/local/bin/graceful_shutdown.sh
#!/bin/bash
echo "Starting graceful shutdown..."
# Simulate waiting for in-flight requests
sleep 20
echo "Graceful shutdown complete."
EOF

chmod +x /usr/local/bin/graceful_shutdown.sh

# Systemd unit to run on shutdown
cat << 'EOF' > /etc/systemd/system/graceful-shutdown.service
[Unit]
Description=Graceful shutdown for ASG instances
DefaultDependencies=no
Before=shutdown.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/graceful_shutdown.sh
TimeoutStartSec=300

[Install]
WantedBy=shutdown.target
EOF

systemctl enable graceful-shutdown.service
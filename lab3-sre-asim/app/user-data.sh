#!/bin/bash
yum update -y
yum install -y httpd
systemctl enable httpd
systemctl start httpd

echo "<h1>Asim's Lab 3 Web Server - ${ENVIRONMENT}</h1>" > /var/www/html/index.html
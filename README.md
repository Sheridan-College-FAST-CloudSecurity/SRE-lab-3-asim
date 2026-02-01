# SRE-lab-3-asim
Repository for Lab 3 of SRE

# Lab 3 – Resilient AWS Infrastructure - Terraform

This repository contains Terraform code and a simple web application used to build a resilient AWS infrastructure as part of Lab 3 for Site Reliability Engineering (SRE) Course

## Structure of my resilient application:

- `terraform/`: Infrastructure as Code (VPC, subnets, EC2, security groups, etc.)
- `configs/`: Layered configuration files (`default.json`, `development.json`) used to parameterize the infrastructure.
- `app/`: Simple web server and bootstrap scripts for the EC2 instance.

## Health Check Endpoint EC2 Instance

The web server exposes a `/health` endpoint implemented as a static file served by Apache. The `/health` path returns a small JSON payload indicating basic status information. This endpoint is used by the Application Load Balancer health checks in Part 2 to determine instance health.


Configuration is externalized and layered so that environment-specific values (e.g., development vs production) can be changed without modifying the core Terraform code.

Commands to run terraform script once terraform is installed:

# Default Environment:

# cd terraform
# terraform init
# terraform apply -var="config_file=../configs/default.json"

# Development Environment

# terraform apply -var="config_file=../configs/development.json"


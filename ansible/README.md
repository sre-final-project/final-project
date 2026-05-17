# Ansible Automation

This directory contains the Ansible automation used for the End Term SRE project.

## Files

- `inventory.ini` - target EC2 host created by Terraform
- `playbook.yml` - main automation playbook
- `roles/docker` - installs Docker and Docker Compose plugin
- `roles/deploy` - clones the project and starts Docker Compose
- `roles/monitoring` - verifies Prometheus, Grafana, and UI health

## Usage

After `terraform apply`, replace `YOUR_EC2_PUBLIC_IP` in `inventory.ini` with:

```bash
terraform output -raw instance_public_ip
```

Run from WSL or Linux:

```bash
cd ansible
ansible-galaxy collection install community.docker
ansible-playbook -i inventory.ini playbook.yml
```

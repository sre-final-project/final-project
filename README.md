# End Term Project

Comprehensive SRE Implementation for a Distributed Microservices System

Alexander Andreyev SE-2429


# 1. Abstract

This project demonstrates the implementation of Site Reliability Engineering (SRE) practices in a distributed microservices-based system. The system includes containerized services, monitoring, infrastructure automation, incident response, and capacity planning. Docker Compose, Docker Swarm, Kubernetes, Terraform, and Ansible were used to demonstrate orchestration, automation, and infrastructure management.

The project also includes Prometheus and Grafana monitoring, alerting mechanisms, automated deployment, incident simulation, and scaling analysis.

# 2. Objectives

The objectives of this project are:

1. Deploy a distributed microservices architecture
2. Implement container orchestration
3. Configure monitoring and alerting
4. Implement infrastructure as code
5. Automate deployment and configuration
6. Simulate incidents and recovery
7. Perform capacity planning and scaling analysis

# 3. System Overview

The system consists of the following services:

1. profile-management
2. product-catalog
3. product-inventory
4. order-management
5. shipping-and-handling
6. contact-support-team
7. ecommerce-ui

Databases:

1. PostgreSQL
2. MongoDB
3. MySQL

Monitoring:

1. Prometheus
2. Grafana
3. Alertmanager

<img width="223" height="349" alt="image" src="https://github.com/user-attachments/assets/f93a7d9b-f358-4c6e-b6ff-549cd940e9e4" />


# 4. Docker Compose Deployment

The application was deployed using Docker Compose.

Commands used:

```bash
docker compose up -d --build
Docker ps
```

Insert screenshots:

[DOCKER COMPOSE SCREENSHOT]

[DOCKER PS SCREENSHOT]

# 5. Docker Swarm Deployment

Docker Swarm was used for service orchestration and scaling.

Commands used:

```bash
docker swarm init
docker stack deploy -c docker-stack.yml ecommerce
docker service ls
docker service scale ecommerce_order-management=3
```

Insert screenshots:

[SWARM INIT SCREENSHOT]

[SWARM SERVICES SCREENSHOT]

[SWARM SCALE SCREENSHOT]

# 6. Kubernetes Deployment

Kubernetes was used for advanced orchestration and declarative deployments.

The following resources were created:

1. Deployments
2. Services
3. ConfigMaps
4. Pods

Commands used:

```bash
kubectl apply -f k8s/
kubectl get pods
kubectl get services
kubectl get deployments
```

Insert screenshots:

[KUBERNETES PODS SCREENSHOT]

[KUBERNETES SERVICES SCREENSHOT]

[KUBERNETES DEPLOYMENTS SCREENSHOT]

# 7. Terraform Infrastructure Provisioning

Terraform was used to provision cloud infrastructure resources.

The Terraform configuration includes:

1. Virtual machine provisioning
2. Network configuration
3. Security groups
4. Output variables

Commands used:

```bash
terraform init
terraform plan
terraform apply
terraform output
```

Insert screenshots:

[TERRAFORM INIT SCREENSHOT]

[TERRAFORM PLAN SCREENSHOT]

[TERRAFORM APPLY SCREENSHOT]

[TERRAFORM OUTPUT SCREENSHOT]

# 8. Ansible Automation

Ansible was used to automate deployment and configuration management.

The playbook performs:

1. Docker installation
2. Dependency installation
3. Project deployment
4. Monitoring configuration

Command used:

```bash
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml
```

Insert screenshot:

[ANSIBLE SCREENSHOT]

# 9. SLI and SLO Design

The following SLIs were defined:

1. Availability
2. Latency
3. Error rate
4. Request success rate

Defined SLOs:

1. Availability >= 99%
2. Latency <= 200 ms
3. Error rate <= 1%
4. Request success rate >= 99%

# 10. Monitoring and Alerting

Prometheus was used for metrics collection and Grafana was used for visualization.

The following metrics were monitored:

1. CPU usage
2. Memory usage
3. Request rate
4. Error rate
5. Service uptime

Alerts were configured for:

1. High CPU usage
2. Service downtime
3. Increased error rates

Insert screenshots:

[PROMETHEUS TARGETS SCREENSHOT]

[GRAFANA DASHBOARD SCREENSHOT]

[ALERTS SCREENSHOT]

# 11. Health Checks and Self-Healing

Health check endpoints were implemented for services.

Docker restart policies were configured to automatically restart failed containers.

Examples:

1. /health endpoint
2. restart: unless-stopped
3. automatic recovery

Insert screenshots:

[HEALTH CHECK SCREENSHOT]

[RESTART POLICY SCREENSHOT]

# 12. Incident Simulation

An incident was simulated by introducing an incorrect database configuration in the order-management service.

Impact:

1. Order service became unavailable
2. Requests failed
3. Alerts were triggered

Response steps:

1. Detection through Grafana and Prometheus
2. Log analysis
3. Configuration fix
4. Service restart
5. Recovery verification

Commands used:

```bash
docker logs order-management
docker restart order-management
```

Insert screenshots:

[INCIDENT ALERT SCREENSHOT]

[LOG ANALYSIS SCREENSHOT]

[RECOVERY SCREENSHOT]

# 13. Postmortem Analysis

Summary:

Timeline:

Root Cause:

Detection:

Resolution:

What went well:

What went wrong:

Preventive actions:

# 14. Capacity Planning

Load testing and capacity analysis were performed to evaluate system performance under increased traffic.

The following tools and methods were used:

1. Docker stats
2. Prometheus metrics
3. Load testing scripts

Results:

1. Order-management service showed the highest CPU usage
2. Database became the primary bottleneck
3. Response time increased during high load

Scaling strategies:

1. Horizontal scaling
2. Vertical scaling
3. Database optimization

Insert screenshots:

[LOAD TEST SCREENSHOT]

[DOCKER STATS SCREENSHOT]

[CAPACITY GRAPH SCREENSHOT]

# 15. Automation

The project includes several automation mechanisms:

1. Automated deployment
2. Log inspection scripts
3. Configuration validation
4. Monitoring alerts
5. Health checks

Scripts used:

1. load-test.sh
2. log-inspector.sh
3. validate-config.sh

Insert screenshots:

[AUTOMATION SCRIPT SCREENSHOT]

[LOG INSPECTOR SCREENSHOT]

# 16. Results

The project successfully demonstrates:

1. Distributed microservices deployment
2. Multi-orchestration using Docker Swarm and Kubernetes
3. Infrastructure provisioning with Terraform
4. Automated deployment using Ansible
5. Monitoring and alerting
6. Incident response and recovery
7. Capacity planning and scaling analysis

# 17. Conclusion

This project demonstrates the implementation of Site Reliability Engineering practices in a distributed microservices environment. The system integrates orchestration, infrastructure automation, monitoring, incident response, and scalability strategies.

The final solution improves reliability, maintainability, and operational efficiency while demonstrating practical SRE concepts.

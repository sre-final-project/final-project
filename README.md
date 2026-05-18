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

<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/a5d523c1-a91b-44a9-b189-175743f28fcd" />


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

docker compose up -d --build
docker ps

<img width="1623" height="312" alt="image" src="https://github.com/user-attachments/assets/4101f5f0-0340-4665-92d0-b974a530ac19" />


# 5. Docker Swarm Deployment

Docker Swarm was used for service orchestration and scaling.

Commands used:
docker swarm init

docker stack deploy -c docker-stack.yml ecommerce

docker service ls

docker service scale ecommerce_order-management=3

<img width="1215" height="309" alt="image" src="https://github.com/user-attachments/assets/79243903-e162-4ed2-ac0a-c3ef372183a8" />

<img width="859" height="123" alt="image" src="https://github.com/user-attachments/assets/a33616cb-5e34-46ff-ac2d-ad9753488602" />

# 6. Kubernetes Deployment

Kubernetes was used for advanced orchestration and declarative deployments.

The following resources were created:

1. Deployments
2. Services
3. ConfigMaps
4. Pods

Commands used:
kubectl apply -f k8s/

kubectl get pods

<img width="715" height="257" alt="image" src="https://github.com/user-attachments/assets/a03053ae-2413-4a46-bfad-598dec856a10" />

kubectl get services

<img width="750" height="257" alt="image" src="https://github.com/user-attachments/assets/4a2e4d14-ed19-405f-b6e6-0d81fb666490" />

kubectl get deployments

<img width="800" height="256" alt="image" src="https://github.com/user-attachments/assets/56346d7f-a367-4321-8b9f-dfb32886e738" />

# 7. Terraform Infrastructure Provisioning

Terraform was used to provision cloud infrastructure resources.

The Terraform configuration includes:

1. Virtual machine provisioning
2. Network configuration
3. Security groups
4. Output variables

Commands used:

terraform init

terraform plan

terraform apply

terraform output


<img width="799" height="328" alt="image" src="https://github.com/user-attachments/assets/21991a98-9953-4c9c-a671-43308a04e70c" />
<img width="742" height="378" alt="image" src="https://github.com/user-attachments/assets/1584dc79-f388-4d92-bb6d-caff434b06fe" />



# 8. Ansible Automation

Ansible was used to automate deployment and configuration management.

The playbook performs:

1. Docker installation
2. Dependency installation
3. Project deployment
4. Monitoring configuration

Command used:

ansible-playbook -i ansible/inventory.ini ansible/playbook.yml

<img width="1182" height="375" alt="image" src="https://github.com/user-attachments/assets/e637fe02-5d3c-4763-a13a-7e73708bb8e1" />
<img width="220" height="245" alt="image" src="https://github.com/user-attachments/assets/96438f8c-1972-4b6f-a77e-bead36d985a6" />



# 9. SLI and SLO Design

The goal is to measure system reliability from the user perspective: users should be able to open the store, browse products, check inventory, sign in, and create orders without errors or long delays.

## SLI 1: Availability

Availability was selected because an e-commerce system must remain accessible for users at all times.

Definition:

Availability SLI = successful_requests / total_requests

Successful requests are HTTP requests that do not return server errors such as 5xx.

Example Prometheus expression:

1 - (
  rate(http_requests_total{status=~"5.."}[1m])
  /
  rate(http_requests_total[1m])
)

SLO:

99% of requests per month must be successful.

Error Budget:

Error Budget = 100% - 99% = 1%

For a 30-day month:

30 days = 43,200 minutes
Acceptable downtime = 43,200 * 0.01 = 432 minutes
432 minutes = 7.2 hours per month


This means the system can be unavailable for up to approximately 7.2 hours per month before the availability SLO is breached.

If backend services return errors, users cannot browse products, authenticate, check inventory, or place orders. For an e-commerce system, availability directly affects user experience and service reliability.

## SLI 2: Latency

Latency was selected because slow responses make the application difficult to use. Product browsing, inventory checks, and order creation should respond quickly.


Latency SLI = requests completed under 500 ms / total requests

Example Prometheus expression:

sum(rate(http_request_duration_seconds_bucket{le="0.5"}[1m]))
/
sum(rate(http_request_duration_seconds_count[1m]))

SLO:

95% of requests must complete in less than 500 ms.

Error Budget:

Error Budget = 100% - 95% = 5%

At an average load of 100 requests per minute:

Monthly requests = 43,200 * 100 = 4,320,000
Acceptable slow requests = 4,320,000 * 0.05 = 216,000

This means up to 5% of requests may exceed 500 ms without breaching the latency SLO.


## SLI 3: Error Rate

Error rate measures the percentage of failed backend requests.

Definition:

Error Rate SLI = failed_requests / total_requests

SLO:

Error rate must stay below 1%.

A high error rate indicates service instability, broken dependencies, database issues, failed deployments, or unavailable downstream services.

## SLI 4: Request Success Rate

Request success rate measures how many user requests are completed successfully across the full microservices system.

Definition:

Request Success Rate = successful_requests / total_requests

SLO:

Request success rate must be at least 99%.

This SLI provides a high-level reliability indicator for the complete e-commerce application.

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

<img width="974" height="526" alt="image" src="https://github.com/user-attachments/assets/77114529-f82a-411e-aa55-769d4366b147" />

<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/fc1814b4-4c72-4ecc-acd9-d5eec20a3d29" />

<img width="1496" height="798" alt="image" src="https://github.com/user-attachments/assets/526641f6-0ea9-4dcb-900a-6c72b906712d" />

<img width="974" height="521" alt="image" src="https://github.com/user-attachments/assets/f02d2052-e063-4068-a3ba-17c804f556d1" />


# 11. Health Checks and Self-Healing

Health check endpoints were implemented for services.

Docker restart policies were configured to automatically restart failed containers.

Examples:

1. /health endpoint
2. restart: unless-stopped
3. automatic recovery


<img width="505" height="214" alt="image" src="https://github.com/user-attachments/assets/b0d382f0-06a6-419f-a127-44651339db7a" />
<img width="717" height="141" alt="image" src="https://github.com/user-attachments/assets/36204b1a-ebc1-410f-bed8-03f331b36ee4" />
<img width="691" height="503" alt="image" src="https://github.com/user-attachments/assets/df2959e2-fd75-4543-a737-6329389e0654" />


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

docker logs order-management

docker restart order-management


<img width="973" height="578" alt="image" src="https://github.com/user-attachments/assets/ea1e2da8-0ccb-4d90-bad9-f2b05a4eae78" />

<img width="1429" height="492" alt="image" src="https://github.com/user-attachments/assets/ea3fde3e-deaa-4105-85f2-42a2a1c916aa" />

<img width="809" height="409" alt="image" src="https://github.com/user-attachments/assets/f36b39c7-a40f-49f5-8b7e-630fdc56d759" />

# 13. Postmortem Analysis

Summary:

The simulated incident affected the order-management service. The service became unavailable because of an incorrect MongoDB database configuration. As a result, order-related requests failed, while the other microservices continued running.

Timeline:

1. Incorrect database configuration was introduced for order-management
2. Order-management service became unhealthy
3. Prometheus and Grafana showed service degradation
4. Docker logs were checked to investigate the issue
5. The database configuration was fixed
6. The order-management service was restarted
7. Health checks confirmed that the service recovered

Root Cause:

The root cause was an incorrect MongoDB connection configuration in the order-management service. Because of this, the service could not connect to its database dependency.

Detection:

The incident was detected using Prometheus metrics, Grafana dashboards, Docker container status, and service health checks.

Resolution:

The incorrect database configuration was corrected. After that, the order-management service was restarted and its health endpoint became available again.

What went well:

1. Monitoring helped detect the issue
2. Logs showed that the problem was related to the database connection
3. Health checks made it easy to verify recovery
4. The system was restored without rebuilding all services

What went wrong:

1. The order-management service became unavailable
2. The configuration problem was detected only after the service failed
3. Recovery required manual log inspection and restart

Preventive actions:

1. Add configuration validation before deployment
2. Add stronger alerts for database connection failures
3. Use readiness probes to prevent traffic from going to unhealthy services
4. Store database settings in environment variables or secrets
5. Add automated smoke tests after deployment

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
4. Services with database dependencies were more sensitive to increased traffic
5. Monitoring showed that scaling backend services can reduce request delays

Scaling strategies:

1. Horizontal scaling
2. Vertical scaling
3. Database optimization
4. Add replicas for order-management and product-catalog
5. Increase CPU and memory limits for services with high resource usage
6. Use database indexing and connection pooling
7. Move stateful databases to managed or dedicated infrastructure in production

Capacity planning conclusion:

The system can be scaled horizontally by increasing replicas in Docker Swarm or Kubernetes. The order-management service should be scaled first because it handles order creation and depends on multiple services. The database layer should also be monitored carefully because it can become the main bottleneck during high traffic.


<img width="1151" height="917" alt="image" src="https://github.com/user-attachments/assets/7cf2ab8d-4bf8-4e7b-9ff1-c41ff3941067" />

<img width="957" height="379" alt="image" src="https://github.com/user-attachments/assets/29bc06d9-8bdf-4011-8ad2-0d555230d092" />

<img width="1919" height="997" alt="image" src="https://github.com/user-attachments/assets/bfacc54a-cc13-40a1-a790-17aad9acd44f" />


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

Automation details:

Docker Compose automates local deployment of all microservices, databases, and monitoring tools. Docker Swarm automates service replication and restart policies. Kubernetes automates declarative deployment, service discovery, health checks, and horizontal scaling. Terraform automates infrastructure provisioning, including network configuration, security groups, SSH key pair, and virtual machine creation. Ansible automates server configuration, Docker installation, application deployment, and monitoring verification.

The scripts folder provides additional operational automation. The load-test script is used to generate traffic for capacity planning. The log-inspector script is used to inspect service logs during incidents. The validate-config script is used to check configuration files before deployment.

<img width="1134" height="894" alt="image" src="https://github.com/user-attachments/assets/255a2139-0780-4670-8db3-ef4c6288895f" />
<img width="1197" height="403" alt="image" src="https://github.com/user-attachments/assets/1b2cb80c-69d0-480b-a098-42cbf9d400b2" />


<img width="1143" height="899" alt="image" src="https://github.com/user-attachments/assets/5009ed8d-679f-4e35-9bd8-dc16213cf1cf" />


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

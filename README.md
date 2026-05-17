# E-commerce Microservices
This e-commerce application is composed of 7 microservices, each built with different languages and frameworks.
We containerize these services, manage their dependencies, and orchestrate the entire application using Docker Compose, and deploy it to the cloud.
## Prerequisites
You need to installed Docker on your system
## Usage
After cloning this repo or downloading the source code zip file, open the PowerShell terminal and navigate to the directory which contains the _'docker-compose.yml'_ file. Run command below to download all the images which are public on my Docker Hub site to your local machine and run the application
```bash
docker compose up
```
When your application is ready, open the application on your browser at _http://localhost:4000_ . Another way to run you application without pulling all images from my Docker Hub site, you can build all images yourself if you can follow the instruction from README.md files which are found in each microservice app.
 After building your own images, you need to update _docker-compose.yml_ file with your new images before running command ``` docker compose up```

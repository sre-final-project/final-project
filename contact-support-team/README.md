# Contact Support Team Microservice

This Docker image provides a microservice for handling contact messages and form submissions. It allows retrieving a contact message and submitting a contact form.

## Version 2.0.0 Update

In version 2.0.0, the Contact Support Microservice is updated to include database integration, which relies on environment variables to establish a connection with a MongoDB database for storing and retrieving contact messages.

```
docker run -p 8000:8000 -e MONGODB_HOST=<mongo_host> -e MONGODB_PORT=<mongo_port> -e MONGODB_DATABASE=<mongo_database> dntranstudy/contact-support-team
```

## Usage

To run a container from this image, use the following command:

```bash
docker run -p 8000:8000 dntranstudy/contact-support-team
```

The microservice will be accessible at `http://localhost:8000`.



### API Endpoints

- `GET /api/contact-message`: Retrieves a contact message.
- `POST /api/contact-submit`: Submits a contact form.

## Environment Variables

This microservice does not require any environment variables to be set.

## Volumes

This microservice does not use any volumes.

## Docker Network

To enable communication between the Contact Support microservice and other microservices or applications, ensure that the containers are connected to the same Docker network. You can achieve this by following these steps:

1. Create a Docker network:
   ```bash
   docker network create my-network
   ```

2. Run the Contact Support microservice container with the `--network` flag:
   ```bash
   docker run --network my-network -p 8000:8000 dntranstudy/contact-support-team
   ```

3. Run other microservice or application containers on the same network:
   ```bash
   docker run --network my-network -p 4000:4000 dntranstudy/ecommerce-ui
   ```

By connecting the containers to the same Docker network, they can communicate with each other using their container names as hostnames.

## Building the Image

If you want to build the Docker image yourself, follow these steps:

1. Clone the repository containing the application code.
2. Navigate to the directory where the Dockerfile is located.
3. Run the following command to build the image:
   ```bash
   docker build -t dntranstudy/contact-support-team .
   ```
   This command will build the Docker image using the provided Dockerfile and tag it as `dntranstudy/contact-support-team`.

## Contributing

If you would like to contribute to this project, please follow the guidelines in the [CONTRIBUTING.md](./CONTRIBUTING.md) file.

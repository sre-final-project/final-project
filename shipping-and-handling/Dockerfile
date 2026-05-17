FROM golang:1.20 AS build
WORKDIR /app
COPY go.mod ./
RUN go mod download || true
COPY . .
RUN go mod tidy && go build -o server .

FROM debian:bookworm-slim
WORKDIR /app
RUN apt-get update && apt-get install -y wget ca-certificates && rm -rf /var/lib/apt/lists/*
COPY --from=build /app/server .
EXPOSE 8080
CMD ["./server"]

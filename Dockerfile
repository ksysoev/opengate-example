# OpenGate Example Dockerfile
# This builds on top of the official OpenGate image and adds configuration

FROM ghcr.io/ksysoev/opengate:main

# Copy configuration files into the container
COPY config/config.yml /config/config.yml
COPY config/gateway.json /config/gateway.json

# Expose the API gateway port
EXPOSE 8080

# Run OpenGate with the configuration file
CMD ["--config=/config/config.yml"]

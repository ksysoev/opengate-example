# OpenGate Example

[![Docker Image](https://img.shields.io/badge/docker-ghcr.io%2Fksysoev%2Fopengate--example-blue)](https://github.com/ksysoev/opengate-example/pkgs/container/opengate-example)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![OpenGate](https://img.shields.io/badge/powered%20by-OpenGate-green)](https://github.com/ksysoev/opengate)

A practical example demonstrating how to deploy [OpenGate](https://github.com/ksysoev/opengate) API Gateway with real-world configuration. This example proxies requests to [JSONPlaceholder](https://jsonplaceholder.typicode.com), a free fake API for testing and prototyping.

## What is OpenGate?

OpenGate is a production-ready API gateway that uses OpenAPI specifications for automatic routing and request forwarding. Configure your API routes declaratively using standard OpenAPI 3.x files, and OpenGate handles the proxying to your backend services.

## What This Example Demonstrates

- **Zero-code gateway deployment** - Pure configuration, no programming required
- **Docker-based deployment** - Build on top of OpenGate's official Docker image
- **Request forwarding** - Proxy requests from gateway to backend services
- **Path parameters** - Dynamic route matching (e.g., `/posts/{id}`)
- **Query parameters** - Pass-through query string parameters
- **Multiple HTTP methods** - GET, POST, etc.
- **OpenAPI specification** - Standard API definition format

## Architecture

```
┌─────────┐         ┌──────────────┐         ┌─────────────────┐
│         │  HTTP   │              │  HTTPS  │                 │
│  Client ├────────►│   OpenGate   ├────────►│ JSONPlaceholder │
│         │         │   Gateway    │         │   (Backend)     │
└─────────┘         └──────────────┘         └─────────────────┘
                           │
                           │ Reads config
                           ▼
                    ┌─────────────┐
                    │ OpenAPI     │
                    │ Spec        │
                    │ (JSON)      │
                    └─────────────┘
```

**Flow:**
1. Client sends request to OpenGate (e.g., `GET http://localhost:8080/posts/1`)
2. OpenGate matches the route against OpenAPI specification
3. OpenGate forwards request to backend (`https://jsonplaceholder.typicode.com/posts/1`)
4. Backend responds
5. OpenGate returns response to client

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) 20.10+
- [Docker Compose](https://docs.docker.com/compose/install/) 2.0+

That's it! No Go installation or compilation needed.

## Quick Start

Get up and running in 3 commands:

```bash
# 1. Clone the repository
git clone https://github.com/ksysoev/opengate-example.git
cd opengate-example

# 2. Start the gateway
docker-compose up -d

# 3. Test it!
curl http://localhost:8080/posts/1
```

You should see a JSON response with post data from JSONPlaceholder.

## Available Endpoints

All endpoints are proxied to `https://jsonplaceholder.typicode.com`:

| Gateway Endpoint | Method | Description | Example |
|-----------------|--------|-------------|---------|
| `/posts` | GET | List all posts | `curl http://localhost:8080/posts` |
| `/posts/{id}` | GET | Get specific post | `curl http://localhost:8080/posts/1` |
| `/posts` | POST | Create new post | See example below |
| `/users` | GET | List all users | `curl http://localhost:8080/users` |
| `/users/{id}` | GET | Get specific user | `curl http://localhost:8080/users/1` |
| `/comments` | GET | Get comments | `curl http://localhost:8080/comments?postId=1` |

## Usage Examples

### Get All Posts

```bash
curl http://localhost:8080/posts
```

Response:
```json
[
  {
    "userId": 1,
    "id": 1,
    "title": "sunt aut facere...",
    "body": "quia et suscipit..."
  },
  ...
]
```

### Get Specific Post

```bash
curl http://localhost:8080/posts/1
```

Response:
```json
{
  "userId": 1,
  "id": 1,
  "title": "sunt aut facere repellat provident...",
  "body": "quia et suscipit..."
}
```

### Create a Post

```bash
curl -X POST http://localhost:8080/posts \
  -H "Content-Type: application/json" \
  -d '{
    "title": "My New Post",
    "body": "This is the content of my post",
    "userId": 1
  }'
```

Response:
```json
{
  "id": 101,
  "title": "My New Post",
  "body": "This is the content of my post",
  "userId": 1
}
```

**Note:** JSONPlaceholder is a fake API, so POST/PUT/DELETE won't actually persist data, but it returns realistic responses for testing.

### Get All Users

```bash
curl http://localhost:8080/users
```

### Get Specific User

```bash
curl http://localhost:8080/users/1
```

### Get Comments for a Post

```bash
# Get all comments for post ID 1
curl "http://localhost:8080/comments?postId=1"
```

## Configuration

### Project Structure

```
opengate-example/
├── config/
│   ├── config.yml          # OpenGate configuration
│   └── gateway.json        # OpenAPI specification with routes
├── Dockerfile              # Build on top of OpenGate image
└── docker-compose.yml      # Easy local deployment
```

### OpenGate Configuration (config/config.yml)

```yaml
api:
  listen: :8080              # Port to listen on

gateway:
  spec_path: /config/gateway.json  # Path to OpenAPI spec

http:
  timeout: 30s               # Request timeout
  max_idle_conns: 100        # Connection pooling
  max_conns_per_host: 10
  idle_conn_timeout: 90s
  disable_keep_alives: false # Keep connections alive
```

### OpenAPI Specification (config/gateway.json)

Routes are defined using standard OpenAPI 3.x format with the `x-opengate` extension:

```json
{
  "openapi": "3.1.0",
  "paths": {
    "/posts": {
      "get": {
        "operationId": "get-posts",
        "x-opengate": {
          "type": "forward",
          "options": {
            "url": "https://jsonplaceholder.typicode.com"
          }
        }
      }
    }
  }
}
```

**Key fields:**
- `type: forward` - Tells OpenGate to proxy the request
- `url` - Backend service base URL
- Path parameters (like `{id}`) are automatically extracted and forwarded

## Customization

### Add Your Own Backend

To proxy to your own API instead of JSONPlaceholder:

1. Edit `config/gateway.json`
2. Change the `url` in `x-opengate.options`:

```json
"x-opengate": {
  "type": "forward",
  "options": {
    "url": "https://your-api.example.com"
  }
}
```

3. Restart the gateway:

```bash
docker-compose restart
```

### Add New Endpoints

1. Edit `config/gateway.json`
2. Add a new path entry following the OpenAPI 3.x format
3. Include the `x-opengate` extension with forwarding configuration
4. Restart: `docker-compose restart`

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed instructions.

### Change Port

To run on a different port (e.g., 9090):

```bash
# Edit docker-compose.yml, change ports section to:
ports:
  - "9090:8080"

# Or use environment variable
PORT=9090 docker-compose up -d
```

### Adjust Log Level

```bash
# Set LOG_LEVEL environment variable
LOG_LEVEL=debug docker-compose up -d
```

Available levels: `debug`, `info`, `warn`, `error`

## Deployment

### Local Development

```bash
# Start in foreground (see logs)
docker-compose up

# Start in background
docker-compose up -d

# View logs
docker-compose logs -f

# Stop
docker-compose down
```

### Production Deployment

For production, consider:

1. **Use the published Docker image:**

```dockerfile
FROM ghcr.io/ksysoev/opengate-example:latest
```

2. **Configure health checks:**

Already included in `docker-compose.yml`:
```yaml
healthcheck:
  test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:8080/posts"]
  interval: 30s
  timeout: 10s
  retries: 3
```

3. **Set resource limits:**

```yaml
services:
  opengate:
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
        reservations:
          cpus: '0.25'
          memory: 256M
```

4. **Use secrets for sensitive configuration:**

```yaml
services:
  opengate:
    secrets:
      - gateway_config
secrets:
  gateway_config:
    file: ./config/gateway.json
```

### Kubernetes Deployment

Example Kubernetes manifests:

**Deployment:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: opengate-example
spec:
  replicas: 3
  selector:
    matchLabels:
      app: opengate-example
  template:
    metadata:
      labels:
        app: opengate-example
    spec:
      containers:
      - name: opengate
        image: ghcr.io/ksysoev/opengate-example:latest
        ports:
        - containerPort: 8080
        env:
        - name: LOG_LEVEL
          value: "info"
        volumeMounts:
        - name: config
          mountPath: /config
          readOnly: true
      volumes:
      - name: config
        configMap:
          name: opengate-config
```

**Service:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: opengate-example
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 8080
  selector:
    app: opengate-example
```

## Testing

A test script is included to verify all endpoints:

```bash
# Make script executable
chmod +x test_endpoints.sh

# Run tests
./test_endpoints.sh
```

Expected output:
```
Testing OpenGate Example Endpoints
===================================

✓ GET /posts - Status: 200
✓ GET /posts/1 - Status: 200
✓ POST /posts - Status: 201
✓ GET /users - Status: 200
✓ GET /users/1 - Status: 200
✓ GET /comments?postId=1 - Status: 200

All tests passed!
```

## Troubleshooting

### Gateway won't start

**Check logs:**
```bash
docker-compose logs opengate
```

**Common issues:**
- Port 8080 already in use → Change port in `docker-compose.yml`
- Configuration file syntax error → Validate YAML/JSON
- Can't pull image → Check Docker Hub access

### Routes return 404

**Check the OpenAPI spec:**
```bash
# Verify routes are loaded
docker-compose logs opengate | grep "Loaded routes"
```

Should show: `Loaded routes from OpenAPI spec count=6`

**Validate your spec:**
- Ensure `x-opengate` extension is present
- Check path syntax (must start with `/`)
- Verify `operationId` is unique

### Backend unreachable

**Test backend directly:**
```bash
curl https://jsonplaceholder.typicode.com/posts/1
```

**Check gateway logs for errors:**
```bash
docker-compose logs opengate | grep error
```

### Live config updates not working

The config directory is mounted as read-only. To update:

1. Edit `config/gateway.json`
2. Restart the container:
```bash
docker-compose restart
```

## Performance Tuning

### Connection Pooling

Adjust in `config/config.yml`:

```yaml
http:
  max_idle_conns: 200        # Increase for high traffic
  max_conns_per_host: 20     # Connections per backend
  idle_conn_timeout: 120s    # How long to keep idle connections
```

### Timeouts

```yaml
http:
  timeout: 60s  # Increase for slow backends
```

### Resource Limits

For high-traffic scenarios, increase container resources:

```yaml
services:
  opengate:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
```

## Security Considerations

This example uses a public API with no authentication for simplicity. For production:

1. **Add authentication** - Use OpenGate's OIDC middleware (see main repo examples)
2. **Use HTTPS** - Deploy behind a reverse proxy (nginx, Traefik, etc.)
3. **Rate limiting** - Implement at infrastructure level
4. **Network policies** - Restrict backend access
5. **Secrets management** - Use Docker secrets or vault for sensitive config

## Learn More

- [OpenGate Documentation](https://github.com/ksysoev/opengate)
- [OpenAPI Specification](https://swagger.io/specification/)
- [JSONPlaceholder API](https://jsonplaceholder.typicode.com)
- [Docker Documentation](https://docs.docker.com)

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Related Projects

- [OpenGate](https://github.com/ksysoev/opengate) - The main OpenGate API Gateway
- [OpenGate with Auth](https://github.com/ksysoev/opengate#authentication) - Examples with OIDC authentication

## Support

- Open an [issue](https://github.com/ksysoev/opengate-example/issues) for bugs or feature requests
- Check [OpenGate issues](https://github.com/ksysoev/opengate/issues) for gateway-specific questions
- Star the project if you find it useful!

---

**Made with ❤️ using [OpenGate](https://github.com/ksysoev/opengate)**

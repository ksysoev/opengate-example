# Contributing to OpenGate Example

Thank you for your interest in contributing to this example project! This guide will help you customize the gateway for your needs or contribute improvements.

## How to Contribute

### Reporting Issues

If you find a bug or have a suggestion:

1. Check [existing issues](https://github.com/ksysoev/opengate-example/issues) first
2. Open a new issue with:
   - Clear description of the problem or suggestion
   - Steps to reproduce (for bugs)
   - Expected vs actual behavior
   - Your environment (Docker version, OS, etc.)

### Submitting Changes

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Test locally
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to your fork (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## Customization Guide

### Adding New Endpoints

To add a new endpoint to the gateway:

1. **Edit the OpenAPI specification** (`config/gateway.json`)

2. **Add a new path entry:**

```json
{
  "paths": {
    "/your-new-endpoint": {
      "get": {
        "summary": "Description of your endpoint",
        "operationId": "unique-operation-id",
        "tags": ["YourCategory"],
        "x-opengate": {
          "type": "forward",
          "options": {
            "url": "https://your-backend.example.com"
          }
        },
        "responses": {
          "200": {
            "description": "Success response"
          }
        }
      }
    }
  }
}
```

3. **Required fields:**
   - `operationId` - Must be unique across all endpoints
   - `x-opengate` - OpenGate-specific configuration
   - `type: forward` - Tells OpenGate to proxy the request
   - `url` - Backend service URL

4. **Restart the gateway:**

```bash
docker-compose restart
```

5. **Test your endpoint:**

```bash
curl http://localhost:8080/your-new-endpoint
```

### Using Path Parameters

Path parameters allow dynamic route matching (e.g., `/posts/{id}`):

```json
{
  "/products/{productId}": {
    "get": {
      "operationId": "get-product",
      "parameters": [
        {
          "name": "productId",
          "in": "path",
          "required": true,
          "schema": {
            "type": "string"
          }
        }
      ],
      "x-opengate": {
        "type": "forward",
        "options": {
          "url": "https://api.example.com"
        }
      }
    }
  }
}
```

**How it works:**
- Request: `GET http://localhost:8080/products/123`
- Proxied to: `https://api.example.com/products/123`

### Using Query Parameters

Query parameters are automatically passed through:

```json
{
  "/search": {
    "get": {
      "operationId": "search",
      "parameters": [
        {
          "name": "q",
          "in": "query",
          "schema": {
            "type": "string"
          }
        }
      ],
      "x-opengate": {
        "type": "forward",
        "options": {
          "url": "https://api.example.com"
        }
      }
    }
  }
}
```

**How it works:**
- Request: `GET http://localhost:8080/search?q=test`
- Proxied to: `https://api.example.com/search?q=test`

### Changing the Backend API

To use a different backend instead of JSONPlaceholder:

1. **Find and replace the URL** in `config/gateway.json`:

```bash
# Before
"url": "https://jsonplaceholder.typicode.com"

# After
"url": "https://your-api.example.com"
```

2. **Update the paths** to match your API's endpoints

3. **Update the schemas** in `responses` to match your API's response format

4. **Restart:**

```bash
docker-compose restart
```

### Modifying Gateway Configuration

Edit `config/config.yml` to adjust OpenGate settings:

#### Change Port

```yaml
api:
  listen: :9090  # Change from :8080 to :9090
```

Don't forget to update `docker-compose.yml` ports section too.

#### Adjust Timeouts

```yaml
http:
  timeout: 60s  # Increase for slow backends
```

#### Connection Pooling

```yaml
http:
  max_idle_conns: 200        # More connections for high traffic
  max_conns_per_host: 20     # Per backend host
  idle_conn_timeout: 120s    # Keep connections alive longer
```

### Building Custom Docker Image

If you want to publish your own customized version:

1. **Build the image:**

```bash
docker build -t your-username/opengate-custom:latest .
```

2. **Test locally:**

```bash
docker run -p 8080:8080 your-username/opengate-custom:latest
```

3. **Push to registry:**

```bash
docker push your-username/opengate-custom:latest
```

4. **Update docker-compose.yml:**

```yaml
services:
  opengate:
    image: your-username/opengate-custom:latest
    # Remove 'build' section
```

## Testing Changes

### Manual Testing

```bash
# Start the gateway
docker-compose up -d

# Test each endpoint
curl http://localhost:8080/posts
curl http://localhost:8080/posts/1
curl http://localhost:8080/users

# Check logs
docker-compose logs -f
```

### Automated Testing

Run the test script:

```bash
chmod +x test_endpoints.sh
./test_endpoints.sh
```

### Validate Configuration

**Check YAML syntax:**
```bash
# Install yamllint
pip install yamllint

# Validate
yamllint config/config.yml
```

**Check JSON syntax:**
```bash
# Use jq
cat config/gateway.json | jq .
```

## Common Patterns

### Multiple Backends

You can proxy different paths to different backends:

```json
{
  "/api/users": {
    "get": {
      "x-opengate": {
        "type": "forward",
        "options": {
          "url": "https://user-service.example.com"
        }
      }
    }
  },
  "/api/products": {
    "get": {
      "x-opengate": {
        "type": "forward",
        "options": {
          "url": "https://product-service.example.com"
        }
      }
    }
  }
}
```

### Path Rewriting

To map gateway paths to different backend paths:

```json
{
  "/v1/posts": {
    "get": {
      "x-opengate": {
        "type": "forward",
        "options": {
          "url": "https://api.example.com/posts"
        }
      }
    }
  }
}
```

- Request: `GET /v1/posts`
- Proxied to: `https://api.example.com/posts`

### Request/Response Transformations

OpenGate passes requests and responses as-is. For transformations, consider:

1. **Backend modifications** - Adjust your backend API
2. **Middleware services** - Add transformation services between gateway and backend
3. **Custom OpenGate extensions** - Contribute to the main OpenGate project

## Documentation

When contributing changes:

1. **Update README.md** if adding features or changing usage
2. **Update this file** if adding new patterns or examples
3. **Add comments** to configuration files for clarity
4. **Update OpenAPI descriptions** for new endpoints

## Code of Conduct

- Be respectful and constructive
- Focus on what is best for the community
- Show empathy towards others
- Gracefully accept constructive criticism

## Questions?

- Open an [issue](https://github.com/ksysoev/opengate-example/issues) for questions
- Check [OpenGate docs](https://github.com/ksysoev/opengate) for gateway features
- See [OpenAPI spec](https://swagger.io/specification/) for specification format

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing to OpenGate Example!

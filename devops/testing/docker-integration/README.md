## Docker Compose Integration Testing
> Docker Compose for spinning up integration test dependencies alongside MUnit

### When to Use
- Your MUnit integration tests need real databases, message brokers, or mock services
- You want repeatable test environments that run identically in CI and locally
- You need to test against services that cannot be effectively mocked (e.g., complex SQL, JMS)

### Configuration

**docker-compose.test.yml**
```yaml
version: "3.9"

services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: testdb
      POSTGRES_USER: mule_test
      POSTGRES_PASSWORD: test_password
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U mule_test -d testdb"]
      interval: 5s
      timeout: 3s
      retries: 10
    volumes:
      - ./test-data/init.sql:/docker-entrypoint-initdb.d/init.sql

  activemq:
    image: apache/activemq-artemis:2.31.2
    environment:
      ARTEMIS_USER: admin
      ARTEMIS_PASSWORD: admin
    ports:
      - "61616:61616"
      - "8161:8161"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8161/console"]
      interval: 5s
      timeout: 3s
      retries: 10

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5

  wiremock:
    image: wiremock/wiremock:3.3.1
    ports:
      - "8089:8080"
    volumes:
      - ./test-data/wiremock:/home/wiremock
    command: ["--verbose"]

  sftp:
    image: atmoz/sftp
    ports:
      - "2222:22"
    command: "mule_test:test_password:1001"
    volumes:
      - ./test-data/sftp-upload:/home/mule_test/upload
```

**test-data/init.sql**
```sql
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    order_number VARCHAR(50) NOT NULL,
    customer_id INTEGER NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL,
    status VARCHAR(20) DEFAULT 'PENDING',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO orders (order_number, customer_id, total_amount, status)
VALUES
    ('ORD-001', 1001, 150.00, 'COMPLETED'),
    ('ORD-002', 1002, 275.50, 'PENDING'),
    ('ORD-003', 1001, 89.99, 'SHIPPED');
```

**CI pipeline integration (GitHub Actions)**
```yaml
jobs:
  integration-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Start test dependencies
        run: docker compose -f docker-compose.test.yml up -d --wait

      - name: Run MUnit integration tests
        run: |
          mvn test -B \
            -Ddb.host=localhost \
            -Ddb.port=5432 \
            -Ddb.user=mule_test \
            -Ddb.password=test_password \
            -Djms.broker.url=tcp://localhost:61616 \
            -Dmock.api.url=http://localhost:8089 \
            -Dsftp.host=localhost \
            -Dsftp.port=2222

      - name: Stop test dependencies
        if: always()
        run: docker compose -f docker-compose.test.yml down -v
```

**run-integration-tests.sh (local development)**
```bash
#!/usr/bin/env bash
set -euo pipefail

echo "Starting test dependencies..."
docker compose -f docker-compose.test.yml up -d --wait
echo "All services healthy."

echo "Running MUnit integration tests..."
mvn test -B \
    -Ddb.host=localhost \
    -Ddb.port=5432 \
    -Ddb.user=mule_test \
    -Ddb.password=test_password \
    -Djms.broker.url=tcp://localhost:61616 \
    -Dmock.api.url=http://localhost:8089 \
    -Dsftp.host=localhost \
    -Dsftp.port=2222
TEST_EXIT=$?

echo "Stopping test dependencies..."
docker compose -f docker-compose.test.yml down -v

exit $TEST_EXIT
```

### How It Works
1. Docker Compose starts all external dependencies with health checks before tests run
2. The `--wait` flag ensures all services pass their health checks before proceeding
3. MUnit tests connect to real services via localhost with test-specific credentials
4. WireMock provides configurable HTTP mock responses for external API dependencies
5. Test data is initialized via SQL scripts and WireMock mapping files
6. Everything is torn down with `down -v` to ensure clean state for next run

### Gotchas
- Port conflicts: ensure test ports do not clash with locally running services
- Docker Compose health checks may need tuning — databases can take 10-30 seconds to start
- Do not use `latest` tags in test images; pin versions for reproducibility
- CI runners need Docker installed; GitHub Actions and GitLab CI provide this by default
- Volume mounts for test data must use relative paths from the docker-compose file location

### Related
- [contract-testing](../contract-testing/) — API spec validation
- [newman-e2e](../newman-e2e/) — End-to-end testing with Postman
- [gitlab-ci](../../cicd-pipelines/gitlab-ci/) — CI pipeline integration

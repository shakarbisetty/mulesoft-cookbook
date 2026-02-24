## Kubernetes Flex Gateway
> K8s manifests for deploying MuleSoft Flex Gateway as an ingress controller

### When to Use
- You want API management at the Kubernetes ingress layer
- You need Anypoint API Manager policies (rate limiting, OAuth) on K8s services
- You prefer Flex Gateway over traditional Nginx/Traefik ingress controllers

### Configuration

**namespace.yaml**
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: flex-gateway
  labels:
    app.kubernetes.io/name: flex-gateway
    app.kubernetes.io/part-of: mulesoft
```

**registration-secret.yaml**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: flex-registration
  namespace: flex-gateway
type: Opaque
stringData:
  registration.yaml: |
    apiVersion: gateway.mulesoft.com/v1alpha1
    kind: Registration
    metadata:
      name: flex-k8s-cluster
    spec:
      token: "${FLEX_REGISTRATION_TOKEN}"
      organization: "${ANYPOINT_ORG_ID}"
      environment: "${ANYPOINT_ENV_ID}"
```

**deployment.yaml**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: flex-gateway
  namespace: flex-gateway
  labels:
    app: flex-gateway
spec:
  replicas: 3
  selector:
    matchLabels:
      app: flex-gateway
  template:
    metadata:
      labels:
        app: flex-gateway
    spec:
      serviceAccountName: flex-gateway
      containers:
        - name: flex-gateway
          image: mulesoft/flex-gateway:1.7.0
          ports:
            - containerPort: 8080
              name: http
              protocol: TCP
            - containerPort: 8443
              name: https
              protocol: TCP
          env:
            - name: FLEX_NAME
              value: "flex-k8s-cluster"
          volumeMounts:
            - name: registration
              mountPath: /etc/flex-gateway/registration
              readOnly: true
            - name: config
              mountPath: /etc/flex-gateway/conf.d
              readOnly: true
          resources:
            requests:
              cpu: "250m"
              memory: "256Mi"
            limits:
              cpu: "1000m"
              memory: "512Mi"
          readinessProbe:
            httpGet:
              path: /healthz
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /healthz
              port: 8080
            initialDelaySeconds: 30
            periodSeconds: 10
      volumes:
        - name: registration
          secret:
            secretName: flex-registration
        - name: config
          configMap:
            name: flex-config
```

**service.yaml**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: flex-gateway
  namespace: flex-gateway
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
    service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
spec:
  type: LoadBalancer
  selector:
    app: flex-gateway
  ports:
    - name: http
      port: 80
      targetPort: 8080
    - name: https
      port: 443
      targetPort: 8443
```

**api-instance.yaml — route traffic to a backend service**
```yaml
apiVersion: gateway.mulesoft.com/v1alpha1
kind: ApiInstance
metadata:
  name: order-api
  namespace: flex-gateway
spec:
  address: https://mule.example.com:443
  services:
    order-service:
      address: http://order-service.default.svc.cluster.local:8081
      routes:
        - rules:
            - path: /api/v1/orders(/.*)?
              methods: [GET, POST, PUT, DELETE]
  policies:
    - policyRef:
        name: rate-limiting
      config:
        rateLimits:
          - maximumRequests: 100
            timePeriodInMilliseconds: 60000
    - policyRef:
        name: jwt-validation
      config:
        jwksUrl: https://auth.example.com/.well-known/jwks.json
        audiences: ["order-api"]
```

### How It Works
1. Flex Gateway registers with Anypoint using a one-time token
2. The Deployment runs 3 replicas behind a LoadBalancer Service
3. ApiInstance CRDs define routing rules that map external paths to internal K8s services
4. Anypoint API Manager policies (rate limiting, JWT, OAuth) are applied via CRDs or the UI
5. Flex Gateway acts as both ingress controller and API gateway in a single component

### Gotchas
- The registration token is single-use; re-registration requires a new token from Anypoint
- Flex Gateway Connected Mode requires outbound HTTPS to Anypoint; Local Mode works offline
- CRDs must be installed before applying ApiInstance manifests (`kubectl apply -f crds/`)
- NLB health checks must target the `/healthz` endpoint on port 8080
- Flex Gateway does not support WebSocket pass-through in all versions

### Related
- [helm-rtf](../helm-rtf/) — RTF for running Mule apps (not just API gateway)
- [terraform-anypoint](../terraform-anypoint/) — Manage API instances via Terraform
- [slo-sli-alerting](../../observability/slo-sli-alerting/) — Monitor gateway SLOs

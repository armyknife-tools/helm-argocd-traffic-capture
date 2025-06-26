# helm-argocd-traffic-capture

A Helm chart for deploying a traffic capture proxy solution with ArgoCD. This solution captures HTTP/HTTPS traffic, masks sensitive data, and sends it to a collector service. Compatible with both Istio and non-Istio environments.

## Features

- Captures HTTP/HTTPS request and response data
- Masks sensitive information (SSN, credit cards, passwords)
- Measures response duration
- Supports all HTTP methods
- Compatible with Istio service mesh environments
- Works in existing namespaces without breaking configurations
- Configurable sampling rate
- ArgoCD-ready deployment

## Important: Namespace and Istio Compatibility

This chart is designed to work in multiple scenarios:

1. **Existing namespace without Istio** - Works out of the box
2. **Existing namespace with Istio** - Automatically configures PeerAuthentication for compatibility
3. **New namespace** - Can optionally create namespace with or without Istio injection

### For Istio-enabled namespaces:
- The chart creates a PeerAuthentication resource with `PERMISSIVE` mode
- This allows the proxy (without sidecar) to communicate with Istio-injected services
- No changes required to existing workloads

## Deployment

### Using ArgoCD

1. Create an ArgoCD Application manifest (`traffic-capture-app.yaml`):

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: traffic-capture
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/armyknife-tools/helm-argocd-traffic-capture
    targetRevision: HEAD
    path: chart/traffic-capture
    helm:
      valueFiles:
        - ../../release/values.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: traffic-capture  # Your target namespace
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true  # Only creates if doesn't exist
```

2. Apply the manifest:
```bash
kubectl apply -f traffic-capture-app.yaml
```

### Using Helm

```bash
# Deploy to existing namespace
helm install traffic-capture ./chart/traffic-capture -n my-namespace

# Or create new namespace
helm install traffic-capture ./chart/traffic-capture -n traffic-capture --create-namespace
```

## Verification & Testing Commands

Use these commands to verify the traffic capture solution is working correctly.

### 1. Check Deployment Status

```bash
# Check if all pods are running
kubectl get pods -n <namespace>

# Expected output: 
# - traffic-capture-collector (1/1 or 2/2 with Istio)
# - traffic-capture-proxy (1/1 or 2/2 with Istio per replica)
# - traffic-capture-example-app (1/1 or 2/2 with Istio)
# - traffic-capture-test-client (1/1 or 2/2 with Istio)
```

### 2. Test Basic HTTP Request

```bash
# Test GET request through the proxy
kubectl exec deployment/traffic-capture-test-client -n <namespace> -c client -- \
  curl -s http://traffic-capture-proxy:8080/test \
  -H "x-original-host: example-app"
```

### 3. Test Sensitive Data Masking

```bash
# Test POST with sensitive data (SSN, credit card, password)
kubectl exec deployment/traffic-capture-test-client -n <namespace> -c client -- \
  curl -s -X POST http://traffic-capture-proxy:8080/api/payment \
  -H "x-original-host: example-app" \
  -H "Content-Type: application/json" \
  -d '{"customer_id": 12345, "ssn": "123-45-6789", "credit_card": "4111-1111-1111-1111", "amount": 99.99, "password": "secret123"}'
```

### 4. Verify Data Capture

```bash
# Check collector statistics
kubectl exec deployment/traffic-capture-test-client -n <namespace> -c client -- \
  curl -s http://traffic-capture-collector:9000/stats | jq

# Query captured traffic (latest entry)
kubectl exec deployment/traffic-capture-test-client -n <namespace> -c client -- \
  curl -s "http://traffic-capture-collector:9000/query?limit=1" | jq '.[0]'

# Verify sensitive data is masked
kubectl exec deployment/traffic-capture-test-client -n <namespace> -c client -- \
  curl -s "http://traffic-capture-collector:9000/query?limit=1" | \
  jq '.[0] | {
    method: .request.method,
    url: .request.url,
    req_body: .request.body,
    resp_body: .response.body,
    duration_ms: .response.duration_ms
  }'
```

### 5. Test Multiple HTTP Methods

```bash
# Test PUT request
kubectl exec deployment/traffic-capture-test-client -n <namespace> -c client -- \
  curl -s -X PUT http://traffic-capture-proxy:8080/api/user/123 \
  -H "x-original-host: example-app" \
  -H "Content-Type: application/json" \
  -d '{"name":"John","email":"john@example.com"}'

# Test DELETE request
kubectl exec deployment/traffic-capture-test-client -n <namespace> -c client -- \
  curl -s -X DELETE http://traffic-capture-proxy:8080/api/user/123 \
  -H "x-original-host: example-app"

# Test PATCH request
kubectl exec deployment/traffic-capture-test-client -n <namespace> -c client -- \
  curl -s -X PATCH http://traffic-capture-proxy:8080/api/user/123 \
  -H "x-original-host: example-app" \
  -H "Content-Type: application/json" \
  -d '{"status":"active"}'

# Verify all methods were captured
kubectl exec deployment/traffic-capture-test-client -n <namespace> -c client -- \
  curl -s http://traffic-capture-collector:9000/stats | jq .methods
```

### 6. Test Headers and Response Time

```bash
# Make a request with custom headers
kubectl exec deployment/traffic-capture-test-client -n <namespace> -c client -- \
  curl -s -X GET http://traffic-capture-proxy:8080/api/data \
  -H "x-original-host: example-app" \
  -H "Authorization: Bearer test-token" \
  -H "X-Custom-Header: test-value"

# Check captured headers and response time
kubectl exec deployment/traffic-capture-test-client -n <namespace> -c client -- \
  curl -s "http://traffic-capture-collector:9000/query?limit=1" | \
  jq '.[0] | {
    request_headers: .request.headers,
    response_headers: .response.headers,
    duration_ms: .response.duration_ms
  }'
```

### 7. Load Test (Optional)

```bash
# Generate 10 requests to test load handling
for i in {1..10}; do
  kubectl exec deployment/traffic-capture-test-client -n <namespace> -c client -- \
    curl -s http://traffic-capture-proxy:8080/test/$i \
    -H "x-original-host: example-app" &
done
wait

# Check total captures
kubectl exec deployment/traffic-capture-test-client -n <namespace> -c client -- \
  curl -s http://traffic-capture-collector:9000/stats | \
  jq '.total_captures'
```

### 8. Test in Istio-enabled Namespace

```bash
# For Istio namespaces, use -c client to specify container
# Check if namespace has Istio injection
kubectl get namespace <namespace> -o jsonpath='{.metadata.labels.istio-injection}'

# If Istio is enabled, the chart automatically handles compatibility
# Test should work the same way
kubectl exec deployment/traffic-capture-test-client -n <namespace> -c client -- \
  curl -s http://traffic-capture-proxy:8080/test \
  -H "x-original-host: example-app"
```

## Expected Results

When all tests pass, you should see:

1. ✅ All pods running successfully
2. ✅ HTTP requests proxied correctly with 200 status
3. ✅ Sensitive data masked in captured traffic:
   - SSN: `123-45-6789` → `[SSN-MASKED]`
   - Credit Card: `4111-1111-1111-1111` → `[CC-MASKED]`
   - Password: `secret123` → `[MASKED]`
4. ✅ All HTTP methods captured (GET, POST, PUT, DELETE, PATCH)
5. ✅ Request/response headers captured
6. ✅ Response duration measured in milliseconds
7. ✅ Collector receiving and storing all traffic

## Troubleshooting

If tests fail:

```bash
# Check proxy logs
kubectl logs deployment/traffic-capture-proxy -n <namespace> --tail=50

# Check collector logs
kubectl logs deployment/traffic-capture-collector -n <namespace> --tail=50

# Check pod status
kubectl describe pods -n <namespace>

# Check services
kubectl get svc -n <namespace>

# For Istio issues, check PeerAuthentication
kubectl get peerauthentication -n <namespace>
```

## Configuration

Key configuration options in `values.yaml`:

- `capture.samplingRate`: Percentage of traffic to capture (0.0-1.0)
- `capture.maskSensitiveData`: Enable/disable sensitive data masking
- `capture.maxBodySize`: Maximum request/response body size to capture
- `proxy.replicaCount`: Number of proxy replicas
- `proxy.istioSidecar.inject`: Enable Istio sidecar for proxy (default: false)
- `collector.persistence.enabled`: Enable persistent storage for captures
- `namespace.create`: Create namespace if it doesn't exist (default: false)
- `istio.peerAuthentication.enabled`: Enable PERMISSIVE mode for Istio compatibility (default: true)

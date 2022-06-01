# wavefront-opentelemetry

## Kubernetes and Auto-instrumentation

Install Wavefront-Proxy (OTLP Collector)

```shell
helm repo add wavefront https://wavefronthq.github.io/helm/ && helm repo update
kubectl create namespace wavefront

helm install wavefront wavefront/wavefront \
    --set wavefront.url=https://TENANT_NAME.wavefront.com \
    --set wavefront.token=API_KEY \
    --set proxy.args="--otlpGrpcListenerPorts 4317 --otlpHttpListenerPorts 4318" \
    --set clusterName="dbrice-gke" --namespace wavefront
```

Patch Proxy to open port 4317 and 4318

```shell
kubectl -n wavefront patch svc wavefront-proxy --patch '{"spec": {"ports": [{"name":"oltphttp", "port": 4318, "protocol": "TCP"}, {"name":"oltpgrpc", "port": 4317, "protocol": "TCP"}]}}}'
```

INstall cert-manager and opentelementry operator

```shell
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.8.0/cert-manager.yaml
kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/latest/download/opentelemetry-operator.yaml
```

Create auto-instrumentation it wavefront-proxy as collector

```yaml
kubectl apply -f - <<EOF
apiVersion: opentelemetry.io/v1alpha1
kind: Instrumentation
metadata:
  name: my-instrumentation
spec:
  exporter:
    endpoint: http://wavefront-proxy.wavefront:4317
  propagators:
    - tracecontext
    - baggage
    - b3
  sampler:
    type: parentbased_traceidratio
    argument: "0.25"
EOF
```

Demo with Spring and Rabbit MQ

```shell
helm repo add bitnami https://charts.bitnami.com/bitnami  && helm repo update

helm install rabbitserver bitnami/rabbitmq \
    --set persistence.enabled=false\
    --set metrics.enabled=true \
    --set auth.username=tutorial\
    --set auth.password=tutorial\ 
    --set nameOverride=rabbitserver
```

Deploy Java app (no code modification needed)

```yaml
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: rabbitmq-tutorials
    run: sender
  name: sender
  annotations:
    instrumentation.opentelemetry.io/inject-java: "true"
spec:
  containers:
  - image: docker.io/bdekany/rabbitmq-tutorials:spring-amqp
    imagePullPolicy: Always
    name: sender
    command: ["java"]
    args: ["-jar", "rabbitmq-tutorials.jar", "--spring.profiles.active=hello-world,sender,remote"]
  dnsPolicy: ClusterFirst
  restartPolicy: Always
---
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: rabbitmq-tutorials
    run: receiver
  name: receiver
  annotations:
    instrumentation.opentelemetry.io/inject-java: "true"
spec:
  containers:
  - image: docker.io/bdekany/rabbitmq-tutorials:spring-amq`
    name: sender
    imagePullPolicy: Always
    command: ["java"]
    args: ["-jar", "rabbitmq-tutorials.jar", "--spring.profiles.active=hello-world,receiver,remote"]
  dnsPolicy: ClusterFirst
  restartPolicy: Always
EOF
```


## Build your own docker image

```shell
git clone https://github.com/rabbitmq/rabbitmq-tutorials
cd rabbitmq-tutorials/spring-amqp
cp ../../Dockerfile .
docker build .
```

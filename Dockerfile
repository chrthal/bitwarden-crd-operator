FROM alpine:latest as builder

ARG BW_VERSION=2023.1.0

RUN apk add wget unzip

RUN cd /tmp && wget https://github.com/bitwarden/clients/releases/download/cli-v${BW_VERSION}/bw-linux-${BW_VERSION}.zip && \
    unzip /tmp/bw-linux-${BW_VERSION}.zip

FROM alpine:3.17.3

LABEL org.opencontainers.image.source=https://github.com/Lerentis/bitwarden-crd-operator
LABEL org.opencontainers.image.description="Kubernetes Operator to create k8s secrets from bitwarden"
LABEL org.opencontainers.image.licenses=MIT

ARG PYTHON_VERSION=3.10.11-r0
ARG PIP_VERSION=22.3.1-r1
ARG GCOMPAT_VERSION=1.1.0-r0
ARG LIBCRYPTO_VERSION=3.0.8-r4

COPY --from=builder /tmp/bw /usr/local/bin/bw
COPY requirements.txt requirements.txt

RUN set -eux; \
    addgroup -S -g 1000 bw-operator; \
    adduser -S -D -u 1000 -G bw-operator bw-operator; \
    mkdir -p /home/bw-operator; \
    chown -R bw-operator /home/bw-operator; \
    chmod +x /usr/local/bin/bw; \
    apk add gcc musl-dev libstdc++ gcompat=${GCOMPAT_VERSION} python3=${PYTHON_VERSION} py3-pip=${PIP_VERSION} libcrypto3=${LIBCRYPTO_VERSION} libssl3=${LIBCRYPTO_VERSION}; \
    pip install -r requirements.txt --no-warn-script-location; \
    apk del --purge gcc musl-dev libstdc++;

COPY --chown=bw-operator:bw-operator src /home/bw-operator

USER bw-operator

ENTRYPOINT [ "kopf", "run", "--log-format=json", "--all-namespaces", "--liveness=http://0.0.0.0:8080/healthz" ]
CMD [ "/home/bw-operator/bitwardenCrdOperator.py", "/home/bw-operator/kv.py", "/home/bw-operator/dockerlogin.py", "/home/bw-operator/template.py"]

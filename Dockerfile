FROM nginx:alpine

LABEL org.opencontainers.image.title="jenkins-k8s-demo"
LABEL org.opencontainers.image.description="A demo image built by Jenkins"

RUN printf '%s\n' \
    '<!DOCTYPE html>' \
    '<html>' \
    '<head><title>Jenkins CI Demo</title></head>' \
    '<body>' \
    '<h1>Hello from Jenkins CI!</h1>' \
    '<p>Built and published to GHCR.</p>' \
    '</body>' \
    '</html>' \
    > /usr/share/nginx/html/index.html

EXPOSE 80

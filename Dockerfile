FROM ubuntu:20.04 as builder
SHELL ["/bin/bash", "-cex"]
ADD https://github.com/krallin/tini/releases/download/v0.19.0/tini /tini
WORKDIR /app
ARG NGINX_VERSION="1.21.3"
ARG PATCH="proxy_connect_rewrite_102101.patch"
RUN apt-get update; \
  apt-get install -y \
    libfontconfig1 \
    libpcre3 \
    libpcre3-dev \
    git \
    dpkg-dev \
    openssl \
    ca-certificates \
    libpng-dev \
    libssl-dev \
    curl; \
  update-ca-certificates; \
  curl -sL http://nginx.org/download/nginx-1.21.3.tar.gz -o - | tar xvzf - -C .; \
  git clone --depth 1 https://github.com/chobits/ngx_http_proxy_connect_module; \
  cd /app/nginx-*; \
  patch -p1 < ../ngx_http_proxy_connect_module/patch/${PATCH}; \
  cd /app/nginx-*; \
  ./configure --add-module=/app/ngx_http_proxy_connect_module --with-http_ssl_module \
    --with-http_stub_status_module --with-http_realip_module --with-threads; \
  make -j$(nproc); \
  make install -j$(nproc); \
  chmod +x /tini

FROM ubuntu:21.10
LABEL maintainer='Robert Reiz <reiz@versioneye.com>'

COPY nginx.conf /usr/local/nginx/conf/nginx.conf
COPY --from=builder /tini /tini
COPY --from=builder /etc/ssl/certs/ /etc/ssl/certs/
COPY --from=builder /usr/local/nginx/sbin/nginx /usr/local/nginx/sbin/nginx

RUN mkdir -p /usr/local/nginx/logs/ && \
    touch /usr/local/nginx/logs/error.log

EXPOSE 8888

ENTRYPOINT ["/tini", "--"]
CMD ["/usr/local/nginx/sbin/nginx"]

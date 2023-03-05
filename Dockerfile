FROM debian:latest AS builder

ARG NGINX_VERSION=nginx-1.23.3
ARG MODULE_VERSION=0.5.2
ARG THEME_VERSION=1.0.1
ARG NGINX_URL=http://nginx.org/download/${NGINX_VERSION}.tar.gz
ARG MODULE_URL=https://github.com/aperezdc/ngx-fancyindex/archive/refs/tags/v${MODULE_VERSION}.tar.gz
ARG THEME_URL=https://github.com/vonsy/Nginx-Fancyindex-Theme/archive/refs/tags/v${THEME_VERSION}.tar.gz

RUN set -x \
    && groupadd --gid 1000 www \
    && useradd --system --no-create-home --shell /bin/false --uid 1000 www --gid 1000 --groups 1000 \
    && mkdir -p /var/log/nginx /var/cache/nginx \
    && chown -R www:www /var/log/nginx /var/cache/nginx \
    && apt update \
    && apt install --no-install-recommends --no-install-suggests -y ca-certificates wget libpcre3 libpcre3-dev libssl-dev zlib1g zlib1g-dev build-essential g++ \
    && rm -rf /var/lib/apt/lists/* \
    && wget --no-check-certificate $NGINX_URL && tar zxf ${NGINX_VERSION}.tar.gz \
    && wget --no-check-certificate $MODULE_URL && tar zxf v${MODULE_VERSION}.tar.gz \
    && wget --no-check-certificate $THEME_URL && tar zxf v${THEME_VERSION}.tar.gz \
    && rm -f ${NGINX_VERSION}.tar.gz v${MODULE_VERSION}.tar.gz v${THEME_VERSION}.tar.gz \
    && cd $NGINX_VERSION \
    && ./configure --prefix=/etc/nginx --sbin-path=/usr/sbin/nginx --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --pid-path=/var/run/nginx.pid --lock-path=/var/run/nginx.lock --http-client-body-temp-path=/var/cache/nginx/client_temp --http-proxy-temp-path=/var/cache/nginx/proxy_temp --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp --http-scgi-temp-path=/var/cache/nginx/scgi_temp --user=www --group=www --with-file-aio --with-threads --with-http_addition_module --with-http_auth_request_module --with-http_dav_module --with-http_flv_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_mp4_module --with-http_random_index_module --with-http_realip_module --with-http_secure_link_module --with-http_slice_module --with-http_ssl_module --with-http_stub_status_module --with-http_sub_module --with-http_v2_module --with-mail --with-mail_ssl_module --with-stream --with-stream_realip_module --with-stream_ssl_module --with-stream_ssl_preread_module --add-module=../ngx-fancyindex-${MODULE_VERSION} \
    && make && make install
    # Multi-layer build, base image is only used for compilation, no need to delete temporary files
    # && apt remove -y ca-certificates wget libpcre3 libpcre3-dev libssl-dev zlib1g zlib1g-dev build-essential g++ \
    # && apt autoremove --purge -y \
    # && cd .. \
    # && rm -rf $NGINX $MODULE $THEME

FROM debian:11-slim

LABEL org.opencontainers.image.created="2023/3/3 21:38" \
      org.opencontainers.image.authors="fsy@outlook.com" \
      org.opencontainers.image.version="1.23.3" \
      org.opencontainers.image.title="nginx-fancyindex" \
      org.opencontainers.image.description="nginx with fancyindex" \
      org.opencontainers.image.base.name="debian:11-slim"

ENV PUID=1000
ENV PGID=1000
ENV TZ=Asia/Shanghai
ENV USER=Neo
ENV PASSWORD=RedPill$

COPY --from=builder /usr/sbin/nginx /usr/sbin/nginx
COPY --from=builder /etc/nginx /etc/nginx
COPY --from=builder /Nginx-Fancyindex-Theme-1.0.0 /Nginx-Fancyindex-Theme-1.0.0
COPY nginx.conf /etc/nginx/nginx.conf
COPY docker-entrypoint.sh /

RUN set -x \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone \
    && groupadd --gid $PGID www \
    && useradd --system --no-create-home --shell /bin/false --uid $PUID www --gid $PGID --groups $PGID \
    && mkdir -p /var/log/nginx /var/cache/nginx /etc/nginx/logs /public /private \
    && chown -R ${PUID}:${PGID} /docker-entrypoint.sh /usr/sbin/nginx /etc/nginx /var/log/nginx /var/cache/nginx /Nginx-Fancyindex-Theme-1.0.0 /public /private \
    && chmod +x /docker-entrypoint.sh \
    && apt update \
    && apt install --no-install-recommends --no-install-suggests -y apache2-utils \
    && rm -rf /var/lib/apt/lists/* \
    && htpasswd -bc /etc/nginx/.htpasswd $USER $PASSWORD

ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 80 443

STOPSIGNAL SIGQUIT

CMD ["nginx", "-g", "daemon off;"]
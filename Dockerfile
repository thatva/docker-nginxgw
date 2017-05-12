FROM ubuntu:xenial
SHELL ["/bin/bash", "-c"]

## NGINX Version
ENV NGINX_VER=1.13.0

## GPG Key
ENV GPG_KEYS=B0F4253373F8F6F510D42178520A9993A1C052F8

## Set Versions
ENV PACKAGES_BUILD="\
	git-core \
	build-essential \
	zlib1g-dev \
	libpcre3-dev \
	unzip \
	wget \
	libssl-dev \
	automake \
	autoconf \
	libtool \
	libgeoip-dev \
	libxml2-dev \
	libcurl4-openssl-dev \
	libyajl-dev \
	liblmdb-dev"
ENV PACKAGES_REQUIRED="\
        libssl1.0.0 \
        libcurl3 \
        libgeoip1 \
        libyajl2 \
        liblmdb0 \
	pkg-config \
        ca-certificates \
        curl \
        libxml2"
ENV NGINX_CONFIG="\
	--prefix=/etc/nginx \
	--sbin-path=/usr/sbin/nginx \
	--modules-path=/usr/lib/nginx/modules \
	--conf-path=/etc/nginx/nginx.conf \
	--error-log-path=/var/log/nginx/error.log \
	--http-log-path=/var/log/nginx/access.log \
	--pid-path=/var/run/nginx.pid \
	--lock-path=/var/run/nginx.lock \
	--http-client-body-temp-path=/var/cache/nginx/client_temp \
	--http-proxy-temp-path=/var/cache/nginx/proxy_temp \
	--http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
	--http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
	--http-scgi-temp-path=/var/cache/nginx/scgi_temp \
	--with-pcre-jit \
	--with-http_ssl_module \
	--with-http_stub_status_module \
	--with-http_auth_request_module \
	--with-http_v2_module \
	--with-http_dav_module \
	--with-http_slice_module \
	--with-threads \
	--with-http_gzip_static_module \
	--without-http_split_clients_module \
	--without-http_userid_module \
	--add-module=modules/ngx_testcookie \
	--add-module=modules/ngx_pagespeed \
	--add-module=modules/ngx_modsecurity \
	--user=www-data \
	--group=www-data"

RUN GPG_KEYS=B0F4253373F8F6F510D42178520A9993A1C052F8
RUN mkdir -p /docker/build
WORKDIR /docker/build
RUN apt-get update && apt-get -y install --no-install-recommends \
        $PACKAGES_BUILD \
	$PACKAGES_REQUIRED \
&& rm -rf /var/lib/apt/lists/* \
&& echo "$!/bin/bash" > /docker/env \
&& git clone https://github.com/SpiderLabs/ModSecurity \
&& cd ModSecurity \
&& git checkout v3/master \
&& git submodule init \
&& git submodule update \
&& ./build.sh \
&& ./configure --prefix=/usr \
&& make -j$(nproc) \
&& make install \
&& cd /docker/build \
&& curl -fSL http://nginx.org/download/nginx-$NGINX_VER.tar.gz -o nginx.tar.gz \
&& curl -fSL http://nginx.org/download/nginx-$NGINX_VER.tar.gz.asc  -o nginx.tar.gz.asc \
&& export GNUPGHOME="$(mktemp -d)" \
&& found=''; \
for server in \
	ha.pool.sks-keyservers.net \
	hkp://keyserver.ubuntu.com:80 \
	hkp://p80.pool.sks-keyservers.net:80 \
	pgp.mit.edu \
; do \
	echo "Fetching GPG key $GPG_KEYS from $server"; \
	gpg --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$GPG_KEYS" && found=yes && break; \
done; \
test -z "$found" && echo >&2 "error: failed to fetch GPG key $GPG_KEYS" && exit 1; \
gpg --batch --verify nginx.tar.gz.asc nginx.tar.gz \
&& rm -r "$GNUPGHOME" nginx.tar.gz.asc \
&& tar xf nginx.tar.gz && rm nginx.tar.gz && mv nginx-$NGINX_VER nginx \
&& mkdir -p /docker/build/nginx/modules \
&& cd /docker/build/nginx/modules \
&& git clone https://github.com/kyprizel/testcookie-nginx-module.git ngx_testcookie \
&& git clone https://github.com/pagespeed/ngx_pagespeed.git \
&& cd /docker/build/nginx/modules/ngx_pagespeed \
&& echo "export PAGESPEED_VER=$(git tag -l --sort=-version:refname 'v*' | head -n1 | cut -c 2- )" >> /docker/env \
&& source /docker/env && git checkout v${PAGESPEED_VER} \
&& source /docker/env && wget $(scripts/format_binary_url.sh PSOL_BINARY_URL) \
&& source /docker/env && tar -zxvf $(echo ${PAGESPEED_VER} | awk -f '-' '{print $1}')*.tar.gz \
&& cd /docker/build/nginx/modules \
&& git clone https://github.com/SpiderLabs/ModSecurity-nginx.git ngx_modsecurity \
&& cd /docker/build/nginx \
&& ./configure $NGINX_CONFIG \
&& make -j$(nproc) \
&& make install \
&& rm -rf /etc/nginx/html/ \
&& mkdir /etc/nginx/conf.d/ \
&& strip /usr/sbin/nginx* \
&& ln -sf /dev/stdout /var/log/nginx/access.log \
&& ln -sf /dev/stderr /var/log/nginx/error.log \
&& rm -r /docker/build \
&& apt-get -y purge $PACKAGES_BUILD \
&& apt-get clean autoclean \
&& apt-get autoremove -y \
&& rm -rf /var/lib/{apt,dpkg,cache,log}/

## Reset workdir
WORKDIR /srv

## Expose ports
EXPOSE 80 443

## Set options
CMD ["/usr/sbin/nginx", "-g", "daemon off;"]

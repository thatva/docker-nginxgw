FROM alpine:latest

## NGINX Version
ENV NGINX_VER=1.13.0

## Mod_PageSpeed
ENV PAGESPEED_VER=34

## GPG Key
ENV GPG_KEYS=B0F4253373F8F6F510D42178520A9993A1C052F8

## Set Versions
ENV PACKAGES_BUILD="\
	binutils \
	linux-headers \
	file \
	git \
	gcc \
	g++ \
	make \
	zlib-dev \
	pcre-dev \
	wget \
	openssl-dev \
	automake \
	autoconf \
	libtool \
	geoip-dev \
	libxml2-dev \
	curl-dev \
	yajl-dev \
	gnupg \
	gawk \
	lmdb-dev"
ENV PACKAGES_REQUIRED="\
        libssl1.0 \
        libcurl \
        geoip \
        yajl \
        lmdb \
	pkgconfig \
        ca-certificates \
        curl \
        libxml2 \
	bash"
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

## Create dirs
RUN mkdir /docker

## Install packages
RUN apk --no-cache add \
        $PACKAGES_BUILD \
	$PACKAGES_REQUIRED \
&& rm -rf /var/lib/apt/lists/* \
&& echo "$!/bin/bash" > /docker/env 

## Set build dir
RUN mkdir -p /docker/build
WORKDIR /docker/build

## Set Shell
SHELL ["/bin/bash", "-c"]

## Install Modsecurity
RUN git clone https://github.com/SpiderLabs/ModSecurity \
&& cd ModSecurity \
&& git checkout v3/master \
&& git submodule init \
&& git submodule update \
&& ./build.sh \
&& ./configure --prefix=/usr \
&& make -j$(getconf _NPROCESSORS_ONLN) \
&& make install

## Installl PSOL
RUN git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git \
&& export PATH=$PATH:~/bin/depot_tools \
&& git clone https://github.com/pagespeed/mod_pagespeed.git \
&& gclient config https://github.com/pagespeed/mod_pagespeed.git --unmanaged --name=mod_pagespeed \
&& cd mod_pagespeed \
&& git checkout ${PAGESPEED_VER} \
&& cd ../ \
&& gclient sync --force --jobs=1 \
&& make AR.host="$PWD/build/wrappers/ar.sh" AR.target="$PWD/build/wrappers/ar.sh" BUILDTYPE=Release mod_pagespeed_test pagespeed_automatic_test

## Install NGINX
RUN curl -fSL http://nginx.org/download/nginx-$NGINX_VER.tar.gz -o nginx.tar.gz \
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
&& source /docker/env && tar -zxvf $(echo ${PAGESPEED_VER} | awk -F '-' '{print $1}')*.tar.gz \
&& ls \
&& cd /docker/build/nginx/modules \
&& git clone https://github.com/SpiderLabs/ModSecurity-nginx.git ngx_modsecurity \
&& cd /docker/build/nginx \
&& ./configure $NGINX_CONFIG \
&& make -j$(getconf _NPROCESSORS_ONLN) \
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

FROM ubuntu:xenial
SHELL ["/bin/bash", "-c"]

## Set Versions
ENV NGINX_VER="1.11.12"
ENV NGINX_CONFIG="\
		--prefix=/usr \
		--conf-path=/etc/nginx/nginx.conf \
		--http-log-path=/var/log/nginx/access.log \
		--error-log-path=/var/log/nginx/error.log \
		--lock-path=/var/lock/nginx.lock \
		--pid-path=/run/nginx.pid \
		--modules-path=/usr/lib/nginx/modules \
		--http-client-body-temp-path=/var/lib/nginx/body \
		--http-fastcgi-temp-path=/var/lib/nginx/fastcgi \
		--http-proxy-temp-path=/var/lib/nginx/proxy \
		--http-scgi-temp-path=/var/lib/nginx/scgi \
		--http-uwsgi-temp-path=/var/lib/nginx/uwsgi \
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
                --group=www-data

RUN mkdir -p /docker/build
WORKDIR /docker/build
RUN apt-get update && apt-get -y install --no-install-recommends \
        ca-certificates \
	git-core \
	build-essential \
	zlib1g-dev \
	libpcre3 \
	libpcre3-dev \
	unzip \
	wget \
	libssl-dev \
	automake \
	autoconf \
	libtool \
	pkg-config \
	libgeoip-dev \
	libxml2-dev \
	libcurl4-openssl-dev \
	libyajl-dev \
	liblmdb-dev \
&& rm -rf /var/lib/apt/lists/* \
&& echo "$!/bin/bash" > /docker/env \
&& git clone https://github.com/SpiderLabs/ModSecurity \
&& cd ModSecurity \
&& git checkout v3/master \
&& git submodule init \
&& git submodule update \
&& ./build.sh \
&& ./configure --prefix=/usr \
&& make \
&& make install \
&& cd /docker/build \
&& echo "export NGINX_VER=$(wget -q -O -  http://nginx.org/download/ | sed -n 's/.*href="nginx-\([^"]*\)\.tar\.gz.*/\1/p' | sort -V | tail -n1)" >> /docker/env \
&& source /docker/env && wget http://nginx.org/download/nginx-${NGINX_VER}.tar.gz \
&& tar xf nginx-*.tar.gz && rm nginx-*.tar.gz && mv nginx-* nginx \
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
&& make \
&& make install \
&& mkdir -p /var/lib/nginx/body && chown -R www-data:www-data /var/lib/nginx \
&& rm -r /docker/build \
&& apt-get -y purge git-core build-essential zlib1g-dev libpcre3-dev unzip wget libssl-dev automake autoconf libgeoip-dev libxml2-dev libcurl4-openssl-dev libyajl-dev liblmdb-dev \
&& apt-get remove --purge -y $(apt-mark showauto) \

## Expose ports
EXPOSE 80 443

## Set options
CMD ["/usr/sbin/nginx", "-g", "daemon off;"]

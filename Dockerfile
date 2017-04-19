FROM ubuntu:xenial
SHELL ["/bin/bash", "-c"]

## Set Versions
ENV NGINX_VER="1.11.12"
ENV PAGESPEED_VER=""

RUN apt-get update && apt-get -y install git-core build-essential zlib1g-dev libpcre3 libpcre3-dev unzip wget libssl-dev automake autoconf libtool pkg-config libgeoip-dev libxml2-dev libcurl4-openssl-dev libyajl-dev liblmdb-dev

## Setup Workdir
RUN mkdir -p /docker/build
WORKDIR /docker/build
RUN echo "$!/bin/bash" > /docker/env

## libmodsecurity
RUN git clone https://github.com/SpiderLabs/ModSecurity
WORKDIR /docker/build/ModSecurity
#RUN echo "export LIBMODSECURITY_VER=$(git tag -l --sort=-version:refname 'v*' | grep -v 'rc\|dev' | head -1)" >> /docker/env
#RUN source /docker/env && git checkout ${LIBMODSECURITY_VER}
RUN git checkout v3/master
RUN git submodule init
RUN git submodule update
RUN ./build.sh
RUN ./configure --prefix=/usr
RUN make
RUN make install

## Prepare NGINX
WORKDIR /docker/build
RUN echo "export NGINX_VER=$(wget -q -O -  http://nginx.org/download/ | sed -n 's/.*href="nginx-\([^"]*\)\.tar\.gz.*/\1/p' | sort -V | tail -n1)" >> /docker/env
RUN source /docker/env && wget http://nginx.org/download/nginx-${NGINX_VER}.tar.gz
RUN tar xf nginx-*.tar.gz && rm nginx-*.tar.gz && mv nginx-* nginx

## Install Modules
RUN mkdir -p /docker/build/nginx/modules
WORKDIR /docker/build/nginx/modules
### nginx-testcookie module
RUN git clone https://github.com/kyprizel/testcookie-nginx-module.git ngx_testcookie
### ngx_pagespeed module
RUN git clone https://github.com/pagespeed/ngx_pagespeed.git
WORKDIR /docker/build/nginx/modules/ngx_pagespeed
RUN echo "export PAGESPEED_VER=$(git tag -l --sort=-version:refname 'v*' | head -n1 | cut -c 2- )" >> /docker/env
RUN source /docker/env && git checkout v${PAGESPEED_VER}
RUN source /docker/env && wget $(scripts/format_binary_url.sh PSOL_BINARY_URL)
RUN source /docker/env && tar -zxvf $(echo ${PAGESPEED_VER} | awk -f '-' '{print $1}')*.tar.gz
### ModSecurity module
WORKDIR /docker/build/nginx/modules
RUN git clone https://github.com/SpiderLabs/ModSecurity-nginx.git ngx_modsecurity

## Configure NGINX
WORKDIR /docker/build/nginx/
RUN ./configure --prefix=/usr \
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
RUN make
RUN make install
## Create missing folders
RUN mkdir -p /var/lib/nginx/body && chown -R www-data:www-data /var/lib/nginx

## Expose ports
EXPOSE 80 443

## Set options
CMD ["/usr/sbin/nginx", "-g", "daemon off;"]

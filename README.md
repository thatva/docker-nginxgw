[![Build Status](https://semaphoreci.com/api/v1/alinuxninja/docker-nginxgw/branches/master/badge.svg)](https://semaphoreci.com/alinuxninja/docker-nginxgw) [![](https://images.microbadger.com/badges/image/alinuxninja/nginxgw.svg)](https://microbadger.com/images/alinuxninja/nginxgw) [![Docker Pulls](https://img.shields.io/docker/pulls/alinuxninja/nginxgw.svg)](https://hub.docker.com/r/alinuxninja/nginxgw/)

## About
This container is a stripped down version of NGINX optimized for usage as a frontend proxy.

Additional Modules:
- Modsecurity (v3)

## Building
When building, specify the correct NGINX version to build.

For example:
```
docker build --build-arg NGINX_VER=1.13.0 .
```

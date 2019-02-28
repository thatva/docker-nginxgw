## About
This container is a stripped down version of NGINX optimized for usage as a frontend proxy.

Additional Modules:
- Modsecurity (v3)

## Building
When building, specify the correct NGINX version to build.

For example:
```
docker build --build-arg NGINX_VER=1.14.2 .
```

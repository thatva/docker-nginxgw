==Nginx GW Edition Docker Container==
This container is likely useful to those that are running a web gateway setup where all content is proxied through a frontend server.
The version of NGINX here brings a few features that are likely useful.

Modules:
- Modsecurity (v3)
- testcookie
- pagespeed

NGINX has also been stripped down by a bit to make it more efficient. Only "latest" tag avaliable at the moment due to testing.

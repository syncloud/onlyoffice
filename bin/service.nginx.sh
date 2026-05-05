#!/bin/bash -e
mkdir -p $SNAP_DATA/nginx/{client_body_temp,proxy_temp,fastcgi_temp,uwsgi_temp,scgi_temp}
/bin/rm -f $SNAP_COMMON/web.socket
exec $SNAP/nginx/bin/nginx.sh -c $SNAP_DATA/config/nginx.conf -p $SNAP/nginx -e stderr

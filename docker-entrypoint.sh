#!/bin/sh

set -e

htpasswd -bc /etc/nginx/.htpasswd $USER $PASSWORD

exec "$@"
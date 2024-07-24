#!/bin/bash

# Enable debugging if DEBUG is set
if [ -n "${APP_DEBUG}" ]; then set -eux; fi

# Start nginx and php-fpm
php-fpm --allow-to-run-as-root --force-stderr --daemonize

sudo nginx -g "daemon off;"

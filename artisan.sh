#!/bin/bash

set -ex

docker compose run --rm artisan "$@"

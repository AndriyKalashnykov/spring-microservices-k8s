#!/bin/bash

set -e
set -x

. ./set-env.sh

. ./install-db.sh

. ./build-app.sh

. ./install-app.sh

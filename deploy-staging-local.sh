#!/bin/sh
set -eux

# Deploy to staging-local (build image + push image + deploy image)
kamal deploy -d staging-local
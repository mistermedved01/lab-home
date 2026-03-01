#!/bin/bash
set +e ; 

echo "Creating the certmanager issuer..."
if [ -f scripts/issuer.yml ]; then
  # The CRD may not exist yet. We need to retry until this passes
  while ! kubectl --namespace="$POD_NAMESPACE" apply -f scripts/issuer.yml; do
    sleep 1;
  done ;
fi ;

if [ -f scripts/gateway_issuer.yaml ]; then
  # The CRD may not exist yet. We need to retry until this passes
  while ! kubectl --namespace="$POD_NAMESPACE" apply -f scripts/gateway_issuer.yaml; do
    sleep 1;
  done ;
fi ;

set -e ; # reset `e` as active

#!/usr/bin/env bash
set -euo pipefail
umask 077

TALOS_VERSION="v1.14.5"
KUBERNETES_VERSION="v1.37.1"
CLUSTER_NAME="management"
CLUSTER_ENDPOINT="https://10.212.212.10:6443"
ADDITIONAL_SANS="kube.home.arpa"
NODE_IP="10.212.212.10"

#SCHEMATIC_ID=$(curl -X POST --data-binary @schematic.yaml https://factory.talos.dev/schematics)
SCHEMATIC_ID=$(
  curl -fsSL -X POST \
    --data-binary @schematic.yaml \
    https://factory.talos.dev/schematics |
    jq -r '.id'
)
INSTALL_IMAGE="factory.talos.dev/metal-installer-secureboot/${SCHEMATIC_ID}:${TALOS_VERSION}"

RENDER_DIR="./rendered"
SECRET_DIR="./secret"
COMMON_PATCH_DIR="./patches/common"
NODE_PATCH_DIR="./patches/nodes"

mkdir -p \
  "$RENDER_DIR" \
  "$SECRET_DIR" \
  "$HOME/.talos"

if [[ ! -f "$SECRET_DIR/secrets.yaml" ]]; then
  talosctl gen secrets \
    --talos-version "$TALOS_VERSION" \
    --output-file "$SECRET_DIR/secrets.yaml"
fi

chmod 600 "$SECRET_DIR/secrets.yaml"

talosctl gen config --force \
  "$CLUSTER_NAME" \
  "$CLUSTER_ENDPOINT" \
  --version "v1alpha1" \
  --talos-version "$TALOS_VERSION" \
  --kubernetes-version "$KUBERNETES_VERSION" \
  --install-image "$INSTALL_IMAGE" \
  --additional-sans "$ADDITIONAL_SANS" \
  --with-secrets "$SECRET_DIR/secrets.yaml" \
  --with-docs=false \
  --with-examples=false \
  --with-cluster-discovery=false \
  --with-kubespan=false \
  --output-types "controlplane,talosconfig" \
  --output "$SECRET_DIR"

# cp-0
talosctl machineconfig patch \
  "$SECRET_DIR/controlplane.yaml" \
  --patch @"$NODE_PATCH_DIR/cp-0/machine.yaml" \
  --patch @"$NODE_PATCH_DIR/cp-0/storage.yaml" \
  --patch @"$NODE_PATCH_DIR/cp-0/kubernetes.yaml" \
  --output "$RENDER_DIR/cp-0.yaml"

# cp-0
talosctl validate \
  --config "$RENDER_DIR/cp-0.yaml" \
  --mode metal

install --mode=600 "$SECRET_DIR/talosconfig" "$HOME/.talos/config"
talosctl config endpoint "$NODE_IP"
talosctl config node "$NODE_IP"

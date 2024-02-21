#!/usr/bin/env bash
# shellcheck disable=SC1091

set -ex

if [[ "${CI_BUILD}" == "no" ]]; then
  exit 1
fi

tar -xzf ./vscode.tar.gz .

cd vscode || { echo "'vscode' dir not found"; exit 1; }

export VSCODE_SYSROOT_PREFIX='-glibc-2.17'

VSCODE_HOST_MOUNT="$( pwd )"

export VSCODE_HOST_MOUNT

if [[ "${VSCODE_ARCH}" == "x64" || "${VSCODE_ARCH}" == "arm64" ]]; then
  VSCODE_REMOTE_DEPENDENCIES_CONTAINER_NAME="vscodium/vscodium-linux-build-agent:centos7-devtoolset8-${VSCODE_ARCH}"
elif [[ "${VSCODE_ARCH}" == "armhf" ]]; then
  VSCODE_REMOTE_DEPENDENCIES_CONTAINER_NAME="vscodium/vscodium-linux-build-agent:bionic-devtoolset-arm32v7"
elif [[ "${VSCODE_ARCH}" == "ppc64le" ]]; then
  VSCODE_REMOTE_DEPENDENCIES_CONTAINER_NAME="vscodium/vscodium-linux-build-agent:bionic-devtoolset-ppc64le"
fi

export VSCODE_REMOTE_DEPENDENCIES_CONTAINER_NAME

for i in {1..5}; do # try 5 times
  yarn --cwd build --frozen-lockfile --check-files && break
  if [[ $i == 3 ]]; then
    echo "Yarn failed too many times" >&2
    exit 1
  fi
  echo "Yarn failed $i, trying again..."
done

./build/azure-pipelines/linux/install.sh

EXPECTED_GLIBC_VERSION="2.17" EXPECTED_GLIBCXX_VERSION="3.4.22" ./build/azure-pipelines/linux/verify-glibc-requirements.sh

node build/azure-pipelines/distro/mixin-npm

export VSCODE_NODE_GLIBC='-glibc-2.17'

yarn gulp minify-vscode-reh
yarn gulp "vscode-reh-${VSCODE_PLATFORM}-${VSCODE_ARCH}-min-ci"

cd ..

echo "Building and moving REH"
cd "vscode-reh-${VSCODE_PLATFORM}-${VSCODE_ARCH}"
tar czf "../assets/${APP_NAME_LC}-reh-${VSCODE_PLATFORM}-${VSCODE_ARCH}-${RELEASE_VERSION}.tar.gz" .
cd ..

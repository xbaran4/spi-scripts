#!/bin/sh

set +x

DEVDIR=${DEVDIR:-${HOME}/dev}
PRIVATE_DOCKERREGISTRY=${PRIVATE_DOCKERREGISTRY:-quay.io/mvala}

SPIOPERATORDIR=${DEVDIR}/spi-operator
SPIOPERATORIMAGE=${PRIVATE_DOCKERREGISTRY}/spi-operator


export SHARED_SECRET=blabol

getBranch() {
  git br --show-current
}

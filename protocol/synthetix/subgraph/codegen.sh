#!/bin/bash

set -e
export CANNON_IPFS_URL="https://ipfs.synthetix.io"

codegen() {
  namespace=$1
  chainId=$2
  package=$3

  echo
  echo
  echo
  echo '>' cannon inspect "$package" --chain-id "$chainId" --write-deployments "./$namespace/deployments"
  yarn cannon inspect "$package" --chain-id "$chainId" --write-deployments "./$namespace/deployments"

  echo
  echo
  echo
  echo '>' graph codegen "subgraph.$namespace.yaml" --output-dir "$namespace/generated"
  yarn graph codegen "subgraph.$namespace.yaml" --output-dir "$namespace/generated"
  yarn prettier --write "$namespace/generated"

  echo
  echo
  echo
  echo '>' graph build "subgraph.$namespace.yaml" --output-dir "./build/$namespace"
  yarn graph build "subgraph.$namespace.yaml" --output-dir "./build/$namespace"
  yarn prettier --write "subgraph.$namespace.yaml"
}


# releaseVersion=$(yarn workspace "@synthetixio/main" node -p 'require(`./package.json`).version')
codegen base-sepolia-andromeda 84532 "synthetix-omnibus:latest@andromeda"
codegen base-mainnet-andromeda 8453 "synthetix-omnibus:latest@andromeda"

codegen mainnet 1 "synthetix-omnibus:latest@main"
codegen goerli 5 "synthetix-omnibus:latest@main"
codegen optimism-mainnet 10 "synthetix-omnibus:latest@main"
codegen optimism-goerli 420 "synthetix-omnibus:latest@main"

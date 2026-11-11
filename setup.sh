#!/usr/bin/env bash
# Downloads the two libraries this project uses (exact versions), then runs the tests once.
set -e
cd "$(dirname "$0")"
[ -d lib/forge-std ] || git clone --quiet --depth 1 --branch v1.17.0 https://github.com/foundry-rs/forge-std lib/forge-std
[ -d lib/openzeppelin-contracts ] || git clone --quiet --depth 1 --branch v5.0.2 https://github.com/OpenZeppelin/openzeppelin-contracts lib/openzeppelin-contracts
forge test

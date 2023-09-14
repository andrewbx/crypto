#!/bin/sh

# Postgre SQL.

docker run --name cl-postgres -e POSTGRES_PASSWORD=mysecretpassword -p 5432:5432 -d postgres

# Chainlink node.

docker run --platform linux/x86_64/v8 --name chainlink -v ./ -it -p 6688:6688 --add-host=host.docker.internal:host-gateway smartcontract/chainlink:2.3.0 node -config ./config.toml -secrets ./secrets.toml start

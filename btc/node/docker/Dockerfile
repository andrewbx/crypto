# syntax = docker/dockerfile:1
# Author: Andrew (andrew@devnull.uk)

FROM alpine:latest AS build.bitcoin.node
MAINTAINER Andrew <andrew@devnull.uk>

USER root

# Setup git vars.

ENV GIT_SSH=/tmp/ssh
ENV GIT_TRACE=1

# Setup alpine image.

RUN apk add --update alpine-sdk
RUN apk add --no-cache gcc git libffi musl-dev  libffi-dev autoconf automake
RUN apk add --no-cache openssh-client make db-dev openssl openssl-dev
RUN apk add --no-cache boost boost-dev libtool libevent libevent-dev

# Compile bitcoin.

RUN git clone https://github.com/bitcoin/bitcoin.git

RUN ( cd bitcoin && ./autogen.sh && \
                   ./configure --disable-tests \
                   --disable-bench --disable-static  \
                   --without-gui --disable-zmq \
                   --with-incompatible-bdb \
                   CFLAGS='-w' CXXFLAGS='-w' && \
                   make -j 4 && \
                   strip src/bitcoind && \
                   strip src/bitcoin-cli && \
                   strip src/bitcoin-tx && \
                   make install )

FROM alpine:latest

# Copy bitcoin binary to new container.

COPY --from=build.bitcoin.node /usr/local/bin/bitcoind /usr/local/bin

# Install dependencies.

RUN apk update && apk add boost boost-filesystem \
            boost-program_options \
            boost-system boost-thread busybox db-c++ \
            libevent libgcc openssl \
            libstdc++ musl

# Bitcoin node configuration.

ADD ./config/bitcoin.conf /bitcoin.conf

# Expose RPC port.

EXPOSE 8332/tcp
EXPOSE 8333/tcp

# Start the bitcoin server.

ENTRYPOINT ["/usr/local/bin/bitcoind"]
CMD ["-conf=/bitcoin.conf", "-regtest", "-rest=1", "-server=1", "-printtoconsole", "-txindex=1", "-datadir=/node/data" ]

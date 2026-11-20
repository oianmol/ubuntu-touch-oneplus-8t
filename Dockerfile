# Build environment for halium-generic-adaptation-build-tools (package list from its gsi-port-ci.yml).
# amd64 on purpose: the build tools download x86-64 clang/gcc prebuilts.
FROM --platform=linux/amd64 ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      bc bison build-essential ca-certificates cpio curl fakeroot flex git kmod libelf-dev libssl-dev \
      libtinfo5 lz4 python2 python3 sudo unzip wget xz-utils pahole libbpf-dev \
      gzip rsync device-tree-compiler libncurses-dev \
 && ln -sf python2 /usr/bin/python && rm -rf /var/lib/apt/lists/*

# MSRV
FROM rust:1.55-slim

# Non-Rust tooling
ENV TZ=US/New_York
RUN apt-get update -y
RUN DEBIAN_FRONTEND="noninteractive" apt-get install -y \
    rr \
    tree \
    vim \
    musl-tools

# Rust tooling
RUN rustup install 1.56.0-x86_64-unknown-linux-gnu
RUN rustup toolchain install nightly
RUN rustup component add rust-src --toolchain nightly
RUN rustup component add llvm-tools-preview
RUN rustup target add x86_64-unknown-linux-musl
RUN cargo install cargo-fuzz
RUN cargo install cargo-binutils
RUN cargo install cargo-bloat

# Src import
RUN mkdir /scapegoat
WORKDIR /scapegoat
COPY . /scapegoat/

# Test (uses 1.56 BTree{Set,Map} feature in tests)
RUN rustup default 1.56.0-x86_64-unknown-linux-gnu
RUN cargo test

# MSRV (1.55) Build
RUN rustup default 1.55.0-x86_64-unknown-linux-gnu
RUN cargo build


# Build Stage
FROM ubuntu:20.04 as builder

## Install build dependencies.
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y cmake clang curl
RUN curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
RUN ${HOME}/.cargo/bin/rustup default nightly
RUN ${HOME}/.cargo/bin/cargo install -f cargo-fuzz

## Add source code to the build stage.
ADD . /repo
WORKDIR /repo

## TODO: ADD YOUR BUILD INSTRUCTIONS HERE.
RUN cd fuzz && ${HOME}/.cargo/bin/cargo fuzz build

# Package Stage
FROM ubuntu:20.04

## TODO: Change <Path in Builder Stage>
COPY --from=builder /repo/target/x86_64-unknown-linux-gnu/release/sg_arena /
COPY --from=builder /repo/target/x86_64-unknown-linux-gnu/release/sg_map /
COPY --from=builder /repo/target/x86_64-unknown-linux-gnu/release/sg_set /

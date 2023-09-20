# Use ubuntu:20.04 as base for builder stage image
FROM ubuntu:20.04 as builder

# Set Pepenet branch/tag to be used for pepenetd compilation

ARG PEPENET_BRANCH=release-v0.18

# Added DEBIAN_FRONTEND=noninteractive to workaround tzdata prompt on installation
ENV DEBIAN_FRONTEND="noninteractive"

# Install dependencies for pepenetd and xmrblocks compilation
RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
    git \
    build-essential \
    cmake \
    miniupnpc \
    graphviz \
    doxygen \
    pkg-config \
    ca-certificates \
    zip \
    libboost-all-dev \
    libunbound-dev \
    libunwind8-dev \
    libssl-dev \
    libcurl4-openssl-dev \
    libgtest-dev \
    libreadline-dev \
    libzmq3-dev \
    libsodium-dev \
    libhidapi-dev \
    libhidapi-libusb0 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set compilation environment variables
ENV CFLAGS='-fPIC'
ENV CXXFLAGS='-fPIC'
ENV USE_SINGLE_BUILDDIR 1
ENV BOOST_DEBUG         1

WORKDIR /root

# Clone and compile pepenetd with all available threads
ARG NPROC
RUN git clone --recursive --branch ${PEPENET_BRANCH} https://github.com/pepenet-project/pepenet.git \
    && cd pepenet \
    && test -z "$NPROC" && nproc > /nproc || echo -n "$NPROC" > /nproc && make -j"$(cat /nproc)"


# Copy and cmake/make xmrblocks with all available threads
COPY . /root/onion-pepenet-blockchain-explorer/
WORKDIR /root/onion-pepenet-blockchain-explorer/build
RUN cmake .. && make -j"$(cat /nproc)"

# Use ldd and awk to bundle up dynamic libraries for the final image
RUN zip /lib.zip $(ldd xmrblocks | grep -E '/[^\ ]*' -o)

# Use ubuntu:20.04 as base for final image
FROM ubuntu:20.04

# Added DEBIAN_FRONTEND=noninteractive to workaround tzdata prompt on installation
ENV DEBIAN_FRONTEND="noninteractive"

# Install unzip to handle bundled libs from builder stage
RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends unzip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /lib.zip .
RUN unzip -o lib.zip && rm -rf lib.zip

# Add user and setup directories for pepenetd and xmrblocks
RUN useradd -ms /bin/bash pepenet \
    && mkdir -p /home/pepenet/.bitpepenet \
    && chown -R pepenet:pepenet /home/pepenet/.bitpepenet
USER pepenet

# Switch to home directory and install newly built xmrblocks binary
WORKDIR /home/pepenet
COPY --chown=pepenet:pepenet --from=builder /root/onion-pepenet-blockchain-explorer/build/xmrblocks .
COPY --chown=pepenet:pepenet --from=builder /root/onion-pepenet-blockchain-explorer/build/templates ./templates/

# Expose volume used for lmdb access by xmrblocks
VOLUME /home/pepenet/.bitpepenet

# Expose default explorer http port
EXPOSE 8081

ENTRYPOINT ["/bin/sh", "-c"]

# Set sane defaults that are overridden if the user passes any commands
CMD ["./xmrblocks --enable-json-api --enable-autorefresh-option  --enable-pusher"]

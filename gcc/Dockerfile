ARG DOCKER_USERNAME
ARG DOCKER_TAG
ARG DISTRO_VERSION
ARG DISTRO
ARG SUFFIX

FROM ubuntu:${DISTRO_VERSION} as builder

ARG GCC_VERSION

LABEL maintainer="Knuth Project <info@kth.cash>"

RUN apt-get -qq update \
    && apt-get -qq install -y --no-install-recommends --no-install-suggests -o=Dpkg::Use-Pty=0 \
       build-essential \
       gcc \
       g++ \
       libc6-dev \
       linux-libc-dev \
       make \
       curl \
       wget \
       zlib1g-dev \
       ca-certificates \
       autoconf-archive \
       bzip2 \
       flex \
       bison \
       texinfo \
       binutils \
       libgmp-dev \
       libmpfr-dev \
       libmpc-dev \
       libisl-dev \
       gawk \
       python3 \
       nasm \
       dh-autoreconf \
       libffi-dev \
       libssl-dev \
       pkg-config

# RUN wget -q --no-check-certificate http://mirrors.concertpass.com/gcc/releases/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.xz \
#     && tar Jxf gcc-${GCC_VERSION}.tar.xz

RUN wget -q --no-check-certificate https://ftp.fu-berlin.de/unix/languages/gcc/releases/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.xz \
    && tar Jxf gcc-${GCC_VERSION}.tar.xz

# INFO: GCC build reference: https://gcc.gnu.org/install/configure.html
# Disable multilib — Knuth no longer supports x86.
# No nls (native language support) — we only use English in Knuth.
# C and C++ only — kth does not link Fortran, dropping it also avoids
# libquadmath (the Fortran __float128 runtime).
# Use system GMP/MPFR/MPC from apt and skip ISL entirely. ISL is only
# used by GCC's graphite-loop-optimizations — not relevant for kth and
# not on by default.
# Bootstrap is enabled (the default): GCC 16 under --disable-bootstrap
# on Ubuntu 24.04's host gcc-13 hits "C compiler cannot create
# executables" while configuring libgomp. The full 3-stage bootstrap
# avoids that class of failure — the build is ~1h instead of ~15min,
# but is also reliable.

RUN cd gcc-${GCC_VERSION} \
    && ./configure \
                   --build=x86_64-linux-gnu \
                   --disable-multilib \
                   --disable-nls \
                   --enable-languages=c,c++ \
                   --disable-werror \
                   --with-system-zlib \
                   --prefix=/tmp/install \
    && (make -s -j$(nproc) || { \
         echo "=== BUILD FAILED — dumping libgomp/libgcc/libatomic config.log ==="; \
         for d in x86_64-linux-gnu/libgomp x86_64-linux-gnu/libgcc x86_64-linux-gnu/libatomic; do \
           [ -f "$d/config.log" ] || continue; \
           echo "========== $d/config.log =========="; \
           cat "$d/config.log"; \
         done; \
         exit 2; }) \
    && make install-strip

FROM ${DOCKER_USERNAME}/base-${DISTRO}${SUFFIX}:${DOCKER_TAG} as deploy

ARG GCC_VERSION
ARG LIBSTDCPP_PATCH_VERSION

COPY --from=builder /tmp/install /tmp/install
# COPY gcc_bootstrap.sh /opt/conan/gcc_bootstrap.sh

RUN sudo rm -rf /usr/lib/gcc/x86_64-linux-gnu/* \
    && sudo cp -a /tmp/install/lib/gcc/x86_64-linux-gnu/${GCC_VERSION} /usr/lib/gcc/x86_64-linux-gnu/ \
    && sudo cp -a /tmp/install/include/* /usr/local/include/ \
    && sudo cp -a /tmp/install/lib64/ /usr/local/ \
    && sudo cp -a /tmp/install/libexec/ /usr/local/ \
    && sudo cp -a /tmp/install/lib/* /usr/local/lib/ \
    && sudo cp -a /tmp/install/bin/* /usr/local/bin/ \
    && sudo rm -rf /tmp/install \
    && sudo update-alternatives --install /usr/local/bin/cc cc /usr/local/bin/gcc 100 \
    && sudo rm /etc/ld.so.cache \
    && sudo ldconfig -C /etc/ld.so.cache \
    && conan profile detect



    # && sudo chmod +x /opt/conan/gcc_bootstrap.sh \
    # && /opt/conan/gcc_bootstrap.sh \
    # && sudo rm -f /opt/conan/gcc_bootstrap.sh
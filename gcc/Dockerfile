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
       g++-multilib \
       gcc \
       curl \
       wget \
       zlib1g-dev \
       ca-certificates \
       autoconf-archive \
       binutils \
       libgmp-dev \
       libmpfr-dev \
       libmpc-dev \
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
# Disabling bootstrap save us around 1h
# Disable multilib as Knuth no longer supports x86
# Enable Fortran as lapack package is basically broken
# No nls (native language support) because we only use English in Knuth

RUN cd gcc-${GCC_VERSION} \
    && ./configure \
                   --build=x86_64-linux-gnu \
                   --disable-bootstrap \
                   --disable-multilib \
                   --disable-nls \
                   --enable-languages=c,c++,fortran \
                   --disable-werror \
                   --without-isl \
                   --with-system-zlib \
                   --prefix=/tmp/install \
    && make -s -j$(nproc) \
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
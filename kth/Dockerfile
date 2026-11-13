# syntax=docker/dockerfile:1
#
# Knuth (kth) Bitcoin Cash full node.
#
# The build stage reuses the project's own toolchain image so the compile
# profile matches the binaries published on packages.kth.cash. The kth package
# and all of its heavy dependencies (boost, openssl, lmdb, gmp, ...) are pulled
# prebuilt from that remote when one exists for this profile; anything missing
# is compiled here.

# Pinned by digest so a future `:latest` retag of the toolchain image
# doesn't silently change the binaries we produce. The publish workflow
# passes the toolchain kth's own CI names for the release being built
# (ci_utils/.github/matrix.json), resolved to its digest at build time, so a
# GCC bump in kth needs no edit here. This default applies only without that
# file. kth refuses GCC older than 16.2 (k-nuth/kth#865), so it is the GCC
# 16.2.0 toolchain image.
ARG TOOLCHAIN=kthnode/gcc16-ubuntu24.04@sha256:cde0d8a8b911ba290e4019fa4fac81723c7cae93cd864e509fd93a7c05d25dfe
ARG RUNTIME=ubuntu:24.04

FROM ${TOOLCHAIN} AS build

# kth release version without the leading "v" (e.g. 1.0.0).
ARG KNUTH_VERSION
ARG CURRENCY=BCH

RUN test -n "${KNUTH_VERSION}" || { echo "KNUTH_VERSION build-arg is required"; exit 1; }

# kthbuild is required to load the kth Conan recipe. Conan is upgraded the way
# kth's own CI does it: its openssl recipe requires Conan 2.25 or newer.
RUN pip install --no-cache-dir --upgrade "conan>=2.25,<3" "kthbuild>=4,<5"

RUN conan profile detect --force \
 && conan remote add kth https://packages.kth.cash/api/ --force \
 && conan install --requires=kth/${KNUTH_VERSION} \
      --deployer=direct_deploy --output-folder=/deploy --build=missing \
      -o "kth/*:currency=${CURRENCY}" \
      -o "kth/*:rpc=jsonrpc" \
      -o "kth/*:tests=False" \
      -o "utxoz/*:with_tests=False" \
      -o "utxoz/*:with_benchmarks=False" \
      -o "utxoz/*:with_large_benchmarks=False" \
      -o "boost/*:without_cobalt=True" \
      -o "boost/*:without_stacktrace_backtrace=True" \
      -s compiler.cppstd=23


FROM ${RUNTIME} AS runtime

LABEL org.opencontainers.image.title="Knuth (kth) node" \
      org.opencontainers.image.description="Knuth Bitcoin Cash full node" \
      org.opencontainers.image.source="https://github.com/k-nuth/kth" \
      org.opencontainers.image.url="https://kth.cash" \
      org.opencontainers.image.licenses="MIT"

# The binary is compiled with the toolchain image's GCC; ship its matching C++
# runtime so the image does not depend on the base distro's (older) libstdc++ /
# libgcc ABI. The CA bundle is copied too, so the runtime stage needs no package
# manager at all.
COPY --from=build /usr/local/lib64/libstdc++.so.6* /opt/kth/lib/
COPY --from=build /usr/local/lib64/libgcc_s.so.1*  /opt/kth/lib/
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
RUN echo /opt/kth/lib > /etc/ld.so.conf.d/kth.conf && ldconfig

COPY --from=build /deploy/direct_deploy/kth/bin/kth /usr/local/bin/kth

# Run the node as an unprivileged user. /data is owned by it so the node can
# persist its state there (and named volumes inherit that ownership).
RUN useradd --system --user-group --no-create-home --home-dir /data kth \
 && mkdir -p /data \
 && chown kth:kth /data
USER kth

# kth writes its data (blockchain/, archive/, hosts.cache, logs) relative to the
# working directory, so anchor it to a single mountable location.
WORKDIR /data
VOLUME ["/data"]

# P2P port (mainnet). Other ports depend on the chosen network / configuration.
EXPOSE 8333

ENTRYPOINT ["kth"]

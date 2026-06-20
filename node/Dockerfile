# syntax=docker/dockerfile:1
#
# Knuth (kth) Bitcoin Cash full node.
#
# The build stage reuses the project's own toolchain image so the compile
# profile matches the binaries published on packages.kth.cash. The kth package
# and all of its heavy dependencies (boost, openssl, lmdb, gmp, ...) are pulled
# prebuilt from that remote; only the few pieces that have no matching prebuilt
# for this profile (currently utxoz) are compiled here, which takes ~1-2 min.

ARG TOOLCHAIN=kthnode/gcc15-ubuntu24.04:latest
ARG RUNTIME=ubuntu:24.04

FROM ${TOOLCHAIN} AS build

# kth release version without the leading "v" (e.g. 1.0.0).
ARG KNUTH_VERSION
ARG CURRENCY=BCH

RUN test -n "${KNUTH_VERSION}" || { echo "KNUTH_VERSION build-arg is required"; exit 1; }

# kthbuild is required to load the kth Conan recipe.
RUN pip install --no-cache-dir --upgrade "kthbuild>=4,<5"

RUN conan profile detect --force \
 && conan remote add kth https://packages.kth.cash/api/ --force \
 && conan install --requires=kth/${KNUTH_VERSION} \
      --deployer=direct_deploy --output-folder=/deploy --build=missing \
      -o "kth/*:currency=${CURRENCY}" \
      -o "kth/*:console=True" \
      -o "utxoz/*:with_tests=False" \
      -o "utxoz/*:with_benchmarks=False" \
      -o "utxoz/*:with_large_benchmarks=False" \
      -s compiler.cppstd=23


FROM ${RUNTIME} AS runtime

LABEL org.opencontainers.image.title="Knuth (kth) node" \
      org.opencontainers.image.description="Knuth Bitcoin Cash full node" \
      org.opencontainers.image.source="https://github.com/k-nuth/kth" \
      org.opencontainers.image.url="https://kth.cash" \
      org.opencontainers.image.licenses="MIT"

# The binary is compiled with GCC 15; ship its matching C++ runtime so the image
# does not depend on the base distro's (older) libstdc++ / libgcc ABI. The CA
# bundle is copied too, so the runtime stage needs no package manager at all.
COPY --from=build /usr/local/lib64/libstdc++.so.6* /opt/kth/lib/
COPY --from=build /usr/local/lib64/libgcc_s.so.1*  /opt/kth/lib/
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
RUN echo /opt/kth/lib > /etc/ld.so.conf.d/kth.conf && ldconfig

COPY --from=build /deploy/direct_deploy/kth/bin/kth /usr/local/bin/kth

# kth writes its data (blockchain/, archive/, hosts.cache, logs) relative to the
# working directory, so anchor it to a single mountable location.
WORKDIR /data
VOLUME ["/data"]

# P2P port (mainnet). Other ports depend on the chosen network / configuration.
EXPOSE 8333

ENTRYPOINT ["kth"]

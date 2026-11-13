# syntax=docker/dockerfile:1
#
# Knuth (kth) Bitcoin Cash full node, built from a kth source tree.
#
# kth/Dockerfile installs a published release from packages.kth.cash. This one
# builds the node from the build context instead: a kth checkout at any commit
# or branch. It builds the way kth's own Linux CI does, with the Conan profile
# and lock file of that tree and then the CMake preset Conan generates, for the
# node-exe target only. Dependencies still come prebuilt from packages.kth.cash
# when one exists for this profile; anything missing is compiled here. The
# runtime stage is the same as kth/Dockerfile's.
#
#   docker build -f kth/source.Dockerfile --build-arg KNUTH_VERSION=1.5.2-commit.local -t kth ../kth

# The workflow passes the toolchain the commit's own CI names
# (ci_utils/.github/matrix.json), resolved to its digest at build time, so a
# GCC bump in kth needs no edit here. This default applies only without that
# file: kth requires GCC 16.2 or later from k-nuth/kth#865 on, and this digest
# is the gcc16-ubuntu24.04 image built with GCC 16.2.0.
ARG TOOLCHAIN=kthnode/gcc16-ubuntu24.04@sha256:cde0d8a8b911ba290e4019fa4fac81723c7cae93cd864e509fd93a7c05d25dfe
ARG RUNTIME=ubuntu:24.04

FROM ${TOOLCHAIN} AS build

# Version the node reports, without the leading "v" (e.g. 1.5.2-commit.30d8617e).
ARG KNUTH_VERSION
ARG CURRENCY=BCH

RUN test -n "${KNUTH_VERSION}" || { echo "KNUTH_VERSION build-arg is required"; exit 1; }

# kth's CI upgrades Conan before every build, since the toolchain image's copy
# can be older than the recipes on the remotes need. kthbuild is required to
# load the kth Conan recipe.
RUN pip install --no-cache-dir --upgrade "conan>=2,<3" "kthbuild>=4,<5"

WORKDIR /src
COPY . .

# The node options are kth/Dockerfile's. march_id=ZLm9Pjh is the
# microarchitecture ID kth's CI builds and publishes its packages with, so the
# binary does not depend on the CPU of the machine that builds it. The lock
# file pins the dependency revisions kth's CI uses; --lockfile-partial resolves
# anything it does not list, as `conan lock create` does in kth's CI.
RUN conan profile detect --force \
 && conan config install -t dir ci_utils/.conan \
 && conan install conanfile.py --version "${KNUTH_VERSION}" \
      --lockfile=conan.lock --lockfile-partial \
      --output-folder=build --build=missing \
      -pr:b linux-ci-cd -pr:h linux-ci-cd \
      -o march_id=ZLm9Pjh \
      -o "currency=${CURRENCY}" \
      -o rpc=True \
      -o tests=False \
      -o "utxoz/*:with_tests=False" \
      -o "utxoz/*:with_benchmarks=False" \
      -o "utxoz/*:with_large_benchmarks=False" \
 && cmake --preset conan-release -DGLOBAL_BUILD=ON -DCMAKE_BUILD_TYPE=Release \
 && cmake --build --preset conan-release -j"$(nproc)" --target node-exe


# Keep this stage the same as kth/Dockerfile's runtime stage.
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

# node-exe's output name is kth; Conan's layout puts the Release build tree
# under build/build/Release.
COPY --from=build /src/build/build/Release/src/node-exe/kth /usr/local/bin/kth

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

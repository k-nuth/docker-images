# docker-images

Docker images that support the Knuth project. Two distinct concerns live here on purpose; they share infra (one toolchain feeds the other) but they target different audiences.

## What's inside

| Directory | Audience | Published as | Trigger |
|-----------|----------|--------------|---------|
| [`base/`](base/) | Knuth CI | `kthnode/base-ubuntu24.04` (Docker Hub) | push to `master` of this repo |
| [`gcc/`](gcc/) | Knuth CI | `kthnode/gcc<N>-ubuntu24.04` (Docker Hub) | push to `master` of this repo |
| [`kth/`](kth/) | end users | `ghcr.io/k-nuth/kth:<version>` (GHCR) | release in [`k-nuth/kth`](https://github.com/k-nuth/kth) |

### Toolchain images (`base/`, `gcc/`)

The build foundation for everything Knuth compiles in CI. `base` is Ubuntu + cmake + Python + Conan; `gcc` is `base` plus a from-source GCC built inside the image so we control the C++23 frontend independently of the Ubuntu distribution. These rebuild only when their own Dockerfile changes (the workflow keys on the file hash, so an existing tag is reused when the image content hasn't moved).

### Node image (`kth/`)

The end-user image: the Knuth node, ready to run.

```bash
docker run --rm -v ./data:/data -p 8333:8333 ghcr.io/k-nuth/kth:latest
```

The build stage uses the `gcc<N>-ubuntu24.04` toolchain so the compile profile matches the binaries on `packages.kth.cash`. The runtime stage is a slim `ubuntu:24.04` carrying only the kth binary, its GCC C++ runtime, and the CA bundle (~100 MB). The node runs as an unprivileged user with `/data` as the persistence volume.

## Triggers

- `base/` and `gcc/` rebuild on push to `master` of this repo via [`knuth.yml`](.github/workflows/knuth.yml). Existing tags are reused when the image hash is unchanged.
- `kth/` rebuilds on every published release in [`k-nuth/kth`](https://github.com/k-nuth/kth) via [`build-node.yml`](.github/workflows/build-node.yml), invoked as a reusable workflow from there. `workflow_dispatch` is also wired so any version can be built on demand from the Actions tab. Stable releases also retag `:latest`; prereleases (anything with a `-` suffix) tag only the version itself so an RC build doesn't displace the stable `latest`.

## Manual builds

```bash
# Toolchain (base):
docker build ./base --build-arg DISTRO_VERSION=24.04 \
    --build-arg CMAKE_VERSION=4.2 --build-arg CMAKE_VERSION_FULL=4.2.1 \
    --build-arg PYTHON_VERSION=3.14.2 --build-arg CONAN_VERSION=2.24.0

# Toolchain (gcc):
docker build ./gcc --build-arg DISTRO_VERSION=24.04 \
    --build-arg DOCKER_USERNAME=kthnode --build-arg DISTRO=ubuntu \
    --build-arg SUFFIX=24.04 --build-arg DOCKER_TAG=latest \
    --build-arg GCC_VERSION=15.2.0

# Node image:
docker build ./kth --build-arg KNUTH_VERSION=1.0.0 -t kth
```

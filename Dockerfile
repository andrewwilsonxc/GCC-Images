ARG GCC_VERSION=6.2.0

FROM centos:7 as builder

RUN yum update -y \
  	&& yum install -y curl wget flex \
	&& yum group install -y "Development Tools" \
	&& yum clean all

ENV GPG_KEYS \
  B215C1633BCA0477615F1B35A5B3A004745C015A \
  B3C42148A44E6983B3E4CC0793FA9B1AB75C61B8 \
  90AA470469D3965A87A5DCB494D03953902C9419 \
  80F98B2E0DAB6C8281BDF541A7C8C3B2F71EDF1C \
  7F74F97C103468EE5D750B583AB00996FC26A641 \
  33C235A34C46AA3FFB293709A328C3A2C3C45C06

RUN set -xe \
	&& for key in $GPG_KEYS; do \
		gpg --keyserver keyserver.ubuntu.com --recv-keys "$key"; \
	done

ARG GCC_VERSION
ARG GITHUB_SHA="dev-build"
ARG GITHUB_RUN_ID="dev-build"
ARG GITHUB_SERVER_URL=""
ARG GITHUB_REPOSITORY=""

RUN set -x \
	&& curl -fSL "http://ftpmirror.gnu.org/gcc/gcc-$GCC_VERSION/gcc-$GCC_VERSION.tar.bz2" -o gcc.tar.bz2 \
	&& curl -fSL "http://ftpmirror.gnu.org/gcc/gcc-$GCC_VERSION/gcc-$GCC_VERSION.tar.bz2.sig" -o gcc.tar.bz2.sig \
	&& gpg --batch --verify gcc.tar.bz2.sig gcc.tar.bz2 \
	&& srcdir="$(mktemp -d)" \
	&& tar -xf gcc.tar.bz2 -C "$srcdir" --strip-components=1 \
	&& rm gcc.tar.bz2* \
	&& cd "$srcdir" \
	&& ./contrib/download_prerequisites \
	&& { rm *.tar.* || true; } \
	&& mkdir -p /usr/um/gcc-${GCC_VERSION} \
	&& builddir="$(mktemp -d)" \
	&& cd "$builddir" \
	&& "$srcdir"/configure \
		--prefix=/usr/um/gcc-${GCC_VERSION} \
		--disable-multilib \
		--enable-languages=c,c++ \
		--with-pkgversion="Project CAENTainer, Rev $GITHUB_SHA, Build $GITHUB_RUN_ID" \
		--with-bugurl="$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/issues" \
	&& make -j"$(nproc)" \
	&& make install-strip \
	&& cd .. \
	&& rm -rf "$srcdir" "$builddir"

FROM ghcr.io/caentainer/caentainer-base:latest

LABEL org.opencontainers.image.authors="CAENTainer Maintainers <caentainer-ops@umich.edu>"
LABEL org.opencontainers.image.source="https://github.com/CAENTainer/GCC-Images"

ARG GCC_VERSION

COPY --from=builder /usr/um/gcc-${GCC_VERSION} /usr/um/gcc-${GCC_VERSION}

ENV PATH="/usr/um/gcc-${GCC_VERSION}/bin:${PATH}"
ENV LD_RUN_PATH "/usr/um/gcc-${GCC_VERSION}/lib64"
ENV LD_LIBRARY_PATH "/usr/um/gcc-${GCC_VERSION}/lib64"

RUN dnf update -y \
  	&& dnf install -y --exclude=gcc gdb valgrind perf make glibc-devel \
	&& dnf clean all \
	&& printf "add-auto-load-safe-path /usr/um/gcc-${GCC_VERSION}/lib64/\n"  >> ${HOME}/.gdbinit
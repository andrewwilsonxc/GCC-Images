ARG GCC_VERSION=6.2.0

FROM --platform=x86-64 centos:7 as builder

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

# https://gcc.gnu.org/mirrors.html
ENV GCC_MIRRORS \
		https://ftpmirror.gnu.org/gcc \
		https://mirrors.kernel.org/gnu/gcc \
		https://bigsearcher.com/mirrors/gcc/releases \
		http://www.netgull.com/gcc/releases \
		https://ftpmirror.gnu.org/gcc \
# only attempt the origin FTP as a mirror of last resort
		ftp://ftp.gnu.org/gnu/gcc

ARG GCC_VERSION
ARG SRCDIR=/tmp/gcc-src

RUN set -ex; \
	_fetch() { \
		local fetch="$1"; shift; \
		local file="$1"; shift; \
		for mirror in $GCC_MIRRORS; do \
			if curl -fL "$mirror/$fetch" -o "$file"; then \
				return 0; \
			fi; \
		done; \
		echo >&2 "error: failed to download '$fetch' from several mirrors"; \
		return 1; \
	}; \
	\
	_fetch "gcc-$GCC_VERSION/gcc-$GCC_VERSION.tar.bz2.sig" 'gcc.tar.bz2.sig'; \
	_fetch "gcc-$GCC_VERSION/gcc-$GCC_VERSION.tar.bz2" 'gcc.tar.bz2'; \
	gpg --batch --verify gcc.tar.bz2.sig gcc.tar.bz2; \
	mkdir -p "$SRCDIR"; \
	tar -xf gcc.tar.bz2 -C "$SRCDIR" --strip-components=1; \
	rm gcc.tar.bz2*; \
	cd "$SRCDIR"; \
	./contrib/download_prerequisites; \
	{ rm *.tar.* || true; };

ARG TARGETARCH
ARG CROSS_CC_DIR=/opt/gcc-arm

ARG GITHUB_SHA="dev-build"
ARG GITHUB_RUN_ID="dev-build"
ARG GITHUB_SERVER_URL=""
ARG GITHUB_REPOSITORY=""

RUN set -ex; \
	mkdir -p /usr/um/gcc-${GCC_VERSION};

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
	&& printf "add-auto-load-safe-path /usr/um/gcc-${GCC_VERSION}/lib64/\n"  >> ${HOME}/.gdbini
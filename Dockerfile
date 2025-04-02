## builder
FROM alpine:3.21 as builder
LABEL image="ripe-atlas-builder"
ARG GIT_URL=https://github.com/RIPE-NCC/ripe-atlas-software-probe.git

WORKDIR /

RUN apk update && \
		apk upgrade && \
        apk add git alpine-sdk openssl-dev autoconf automake libtool linux-headers musl-dev psmisc net-tools
RUN git clone --recursive "$GIT_URL" /tmp/ripe-atlas-software-probe

WORKDIR /tmp/ripe-atlas-software-probe
# version 5110
RUN git checkout 5110

RUN autoreconf -iv
RUN ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --libdir=/usr/lib64 --runstatedir=/run --with-user=ripe-atlas --with-group=ripe-atlas --with-measurement-user=ripe-atlas --disable-systemd --enable-chown --enable-setcap-install
RUN make

## artifacts
FROM scratch AS artifacts
LABEL image="ripe-atlas-artifacts"

COPY --from=builder /tmp/ripe-atlas-software-probe /

## the actual image
FROM alpine:3.21
LABEL maintainer="c@3qx.nl"
LABEL image="ripe-atlas"

COPY --from=builder /tmp/ripe-atlas-software-probe /tmp/ripe-atlas-software-probe

ARG ATLAS_UID=101
ARG ATLAS_GID=656
RUN ln -s /bin/true /bin/systemctl \
	&& adduser --system --uid $ATLAS_UID ripe-atlas \
	&& addgroup --system --gid $ATLAS_GID ripe-atlas \
	&& apk update \
	&& apk upgrade \
	&& apk add libcap iproute2 openssh-client procps net-tools tini openssl-dev autoconf automake psmisc alpine-sdk libtool linux-headers bash setpriv
WORKDIR /tmp/ripe-atlas-software-probe
RUN make install

# Inprogress

COPY entrypoint.sh /usr/local/bin
RUN chmod +x /usr/local/bin/* \
	&& rm -rf /tmp/ripe-atlas-software-probe \
	&& apk del autoconf automake psmisc alpine-sdk libtool linux-headers

WORKDIR /
VOLUME [ "/etc/ripe-atlas", "/run/ripe-atlas/status", "/var/spool/ripe-atlas" ]

ENTRYPOINT [ "tini", "--", "entrypoint.sh" ]
CMD [ "ripe-atlas" ]

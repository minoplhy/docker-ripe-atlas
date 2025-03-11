## builder
FROM debian:12 as builder
LABEL image="ripe-atlas-builder"
ARG DEBIAN_FRONTEND=noninteractive
ARG GIT_URL=https://github.com/RIPE-NCC/ripe-atlas-software-probe.git

WORKDIR /tmp

RUN apt-get update -y && \
        apt-get install -y git build-essential debhelper libssl-dev autotools-dev psmisc net-tools
RUN git clone --recursive "$GIT_URL" /tmp/ripe-atlas-software-probe

WORKDIR /tmp/ripe-atlas-software-probe
# version 5100
RUN git checkout 5100
RUN autoreconf -iv
RUN ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --libdir=/usr/lib64 --runstatedir=/run --with-user=ripe-atlas --with-group=ripe-atlas --with-measurement-user=ripe-atlas --disable-systemd --enable-chown --enable-setcap-install
RUN make

## artifacts
FROM scratch AS artifacts
LABEL image="ripe-atlas-artifacts"

COPY --from=builder /tmp/ripe-atlas-software-probe /

## the actual image
FROM debian:12
LABEL maintainer="dockerhub@public.swineson.me"
LABEL image="ripe-atlas"

COPY --from=builder /tmp/ripe-atlas-software-probe /tmp/ripe-atlas-software-probe

ARG ATLAS_UID=101
ARG ATLAS_MEAS_UID=102
ARG ATLAS_GID=999
RUN ln -s /bin/true /bin/systemctl \
	&& adduser --system --uid $ATLAS_UID ripe-atlas \
	&& groupadd --force --system --gid $ATLAS_GID ripe-atlas \
	&& apt-get update -y \
	&& apt-get install -y libcap2-bin iproute2 openssh-client procps net-tools tini debhelper libssl-dev autotools-dev psmisc opensysusers

WORKDIR /tmp/ripe-atlas-software-probe
RUN make install

# Inprogress

COPY entrypoint.sh /usr/local/bin
RUN chmod +x /usr/local/bin/* \
	&& rm -rf /var/lib/apt/lists/* \
	&& rm -rf /tmp/ripe-atlas-software-probe \
	&& mkdir -p /opt/ripe-atlas \
	&& chown -R ripe-atlas:ripe-atlas /opt/ripe-atlas \
	&& chmod 777 /opt/ripe-atlas

WORKDIR /
VOLUME [ "/etc/ripe-atlas", "/run/ripe-atlas/status", "/var/spool/ripe-atlas" ]

ENTRYPOINT [ "tini", "--", "entrypoint.sh" ]
CMD [ "ripe-atlas" ]

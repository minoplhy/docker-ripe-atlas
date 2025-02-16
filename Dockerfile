## builder
FROM --platform=$BUILDPLATFORM debian:12-slim as builder
LABEL image="ripe-atlas-builder"
ARG BUILDPLATFORM
ARG TARGETPLATFORM
ARG DEBIAN_FRONTEND=noninteractive
ARG GIT_URL=https://github.com/RIPE-NCC/ripe-atlas-software-probe.git

WORKDIR /root

RUN if [ "$BUILDPLATFORM" != "$TARGETPLATFORM" ]; then \
        apt-get update -y && \
        apt-get install -y git build-essential debhelper libssl-dev autotools-dev psmisc net-tools; \
    fi

RUN git clone --recursive "$GIT_URL"

WORKDIR /root/ripe-atlas-software-probe
# version 5100
RUN git checkout 5100
RUN dpkg-buildpackage -b -us -uc
WORKDIR /root


## artifacts
FROM scratch AS artifacts
LABEL image="ripe-atlas-artifacts"

COPY --from=builder /root/ripe-atlas-probe*.deb /

## the actual image
FROM debian:12-slim
LABEL maintainer="dockerhub@public.swineson.me"
LABEL image="ripe-atlas"
ARG DEBIAN_FRONTEND=noninteractive

COPY --from=builder /root/ripe-atlas-probe*.deb /tmp

ARG ATLAS_UID=101
ARG ATLAS_GID=999
RUN ln -s /bin/true /bin/systemctl \
	&& adduser --system --uid $ATLAS_UID atlas \
	&& groupadd --force --system --gid $ATLAS_GID atlas \
	&& usermod -aG atlas atlas \
	&& apt-get update -y \
	&& apt-get install -y libcap2-bin iproute2 openssh-client procps net-tools tini \
	&& dpkg -i /tmp/ripe-atlas-probe*.deb \
	&& apt-get install -fy \
	&& rm -rf /var/lib/apt/lists/* \
	&& rm -f /tmp/ripe-atlas-probe*.deb \
	&& ln -s /usr/local/atlas/bin/ATLAS /usr/local/bin/atlas

COPY entrypoint.sh /usr/local/bin
RUN chmod +x /usr/local/bin/* \
	&& chown -R atlas:atlas /var/atlas-probe \
	&& mkdir -p /var/atlasdata \
	&& chown -R atlas:atlas /var/atlasdata \
	&& chmod 777 /var/atlasdata

WORKDIR /var/atlas-probe
VOLUME [ "/var/atlas-probe/etc", "/var/atlas-probe/status" ]

ENTRYPOINT [ "tini", "--", "entrypoint.sh" ]
CMD [ "atlas" ]

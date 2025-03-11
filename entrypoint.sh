#!/usr/bin/env bash
set -Eeuo pipefail

# test essential syscalls
if ! sleep 0 >/dev/null 2>&1; then
	>&2 echo "WARNING: clock_nanosleep or clock_nanosleep_time64 is not available on the system"
fi

export ATLAS_UID="${ATLAS_UID:-101}"
export ATLAS_GID="${ATLAS_GID:-999}"

usermod -u $ATLAS_UID ripe-atlas
groupmod -g $ATLAS_GID ripe-atlas

# create essential files and fix permission
mkdir -p /var/spool/ripe-atlas
chown -R ripe-atlas:ripe-atlas /var/spool/ripe-atlas || true
mkdir -p /var/spool/ripe-atlas/data
chown -R ripe-atlas:ripe-atlas /var/spool/ripe-atlas/data || true
mkdir -p /run/ripe-atlas/status
chown -R ripe-atlas:ripe-atlas /run/ripe-atlas/status || true
mkdir -p /etc/ripe-atlas
chown -R ripe-atlas:ripe-atlas /etc/ripe-atlas || true
#mkdir -p /var/atlas-probe/state
#chown -R ripe-atlas:ripe-atlas /var/atlas-probe/state || true

# (init) set atlas mode to prod
echo "prod" > /etc/ripe-atlas/mode || true

exec setpriv --reuid=$ATLAS_UID --regid=$ATLAS_GID --init-groups "$@"

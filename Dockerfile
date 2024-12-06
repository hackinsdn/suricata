FROM debian:12

RUN --mount=source=.,target=/mnt,type=bind \
 export DEBIAN_FRONTEND=noninteractive \
 && echo "deb http://deb.debian.org/debian bookworm-backports main" \
	| tee -a /etc/apt/sources.list.d/debian-backport.list \
 && apt-get update \
 && apt-get install -t bookworm-backports -y suricata python3-pygtail curl jq \
 && apt-get install --no-install-recommends -y cron \
						iproute2 \
						tcpdump \
						net-tools \
						iputils-ping \
						procps \
						socat \
 && cp -r /mnt/conf/* /etc/ \
 && install --mode 0755 --owner root /mnt/scripts/hackinsdn-guardian.py /usr/local/bin/ \
 && install --mode 0755 --owner root /mnt/scripts/block.sh /usr/local/bin/ \
 && install --mode 0755 --owner root /mnt/scripts/unblock.sh /usr/local/bin/ \
 && install --mode 0755 --owner root /mnt/scripts/update-suricata-misp.sh /usr/local/bin/ \
 && suricata-update --no-test \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /

COPY docker-entrypoint.sh /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]

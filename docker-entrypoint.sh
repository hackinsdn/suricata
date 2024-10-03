#!/bin/bash

# Wait for Suricata Interface to become available and then update suricata.yaml
# accordingly (Mininet-Sec will create it based on the topology) -- interface 
# name defaults to 'XXXINTFXXX'
until ip link show dev "$SURICATA_IFACE" >/dev/null 2>&1; do
	sleep 2
done
sed -i "s/XXXINTFXXX/$SURICATA_IFACE/g" /etc/suricata/suricata.yaml

# Update HOME_NET according to env variable (defaults to RFC1918 nets)
test -z "$SURICATA_HOME_NET" && SURICATA_HOME_NET="192.168.0.0/16,10.0.0.0/8,172.16.0.0/12"
sed -i "s#XXXHOMENETXXX#$SURICATA_HOME_NET#g" /etc/suricata/suricata.yaml

service suricata start
/etc/init.d/cron start

mkdir -p /var/log/suricata/
touch /var/log/suricata/{suricata.log,eve.json}

REMOTE_IPS_OPS=""
test -n "$BLOCKING_DURATION" && REMOTE_IPS_OPS="$REMOTE_IPS_OPS --block_duration $BLOCKING_DURATION"
if [ -n "$KYTOS_URL" ]; then
	nohup /usr/local/bin/hackinsdn-guardian.py --suricata_eve /var/log/suricata/eve.json $REMOTE_IPS_OPS &
fi

tail -f /var/log/suricata/suricata.log

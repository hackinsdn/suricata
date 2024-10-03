#!/bin/bash

VLAN=$1
IP=$2
echo "$(date) Unblock $VLAN $IP"

if [ -z "$KYTOS_URL" ]; then
	KYTOS_URL=http://127.0.0.1:8181
fi

BLOCK=$(tac /var/log/kytos-block.log | fgrep -m1 "[BLOCK] vlan=$VLAN ip=$IP ")

if [ -z "$BLOCK" ]; then
	echo "$(date) [WARN] could not unblock, it does not seems to be blocked! vlan=$VLAN ip=$IP"
	exit 0
fi

BLOCK_ID_A=$(echo "$BLOCK" | cut -d' ' -f6 | cut -d'=' -f2)
BLOCK_ID_Z=$(echo "$BLOCK" | cut -d' ' -f8 | cut -d'=' -f2)


RESULT_A=$(curl -s -H 'Content-type: application/json' -X DELETE $KYTOS_URL/api/hackinsdn/containment/v1/$BLOCK_ID_A)
RESULT_Z=$(curl -s -H 'Content-type: application/json' -X DELETE $KYTOS_URL/api/hackinsdn/containment/v1/$BLOCK_ID_Z)

echo "$(date -u +%Y-%m-%d,%H:%M:%s) [UNBLOCK] vlan=$VLAN ip=$IP result_a=$RESULT_A result_z=$RESULT_Z" >> /var/log/kytos-block.log

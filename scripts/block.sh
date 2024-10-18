#!/bin/bash

VLAN=$1
IP=$2
echo "$(date) Block $VLAN $IP"

if [ -z "$KYTOS_URL" ]; then
	KYTOS_URL=http://127.0.0.1:8181
fi

BLOCK_FIELD="ipv4_src"
if echo "$IP" | grep -q ":"; then
	BLOCK_FIELD="ipv6_src"
fi

curl -s $KYTOS_URL/api/kytos/mef_eline/v2/evc/ | jq -r '.[] | .id + " " + .uni_a.interface_id + " vlan=" + (.uni_a.tag.value|tostring) + " " + .uni_z.interface_id + " vlan=" + (.uni_z.tag.value|tostring)' > /tmp/evcs

VLAN_ID=$VLAN
VLAN_QUERY=$VLAN
if [ "$VLAN" = "untagged" ]; then
	VLAN_ID=0
	VLAN_QUERY="(null|untagged)"
fi


EVC=$(egrep -w "vlan=$VLAN_QUERY" /tmp/evcs)
if [ -z "$EVC" ]; then
	echo "$(date) [WARN] VLAN not found! vlan=$VLAN ip=$IP"
	exit 0
fi

INTFA=$(echo "$EVC" | cut -d ' ' -f2)
INTFZ=$(echo "$EVC" | cut -d ' ' -f4)

INTFA_SW=$(echo "$INTFA" | cut -d':' -f1-8)
INTFA_PORT=$(echo "$INTFA" | cut -d':' -f9)
INTFZ_SW=$(echo "$INTFZ" | cut -d':' -f1-8)
INTFZ_PORT=$(echo "$INTFZ" | cut -d':' -f9)

RESULT_A=$(curl -s -H 'Content-type: application/json' -X POST $KYTOS_URL/api/hackinsdn/containment/v1/ -d '{"switch": "'$INTFA_SW'", "interface": '$INTFA_PORT', "match": {"vlan": '$VLAN_ID', "'$BLOCK_FIELD'": "'$IP'"}}')
RESULT_Z=$(curl -s -H 'Content-type: application/json' -X POST $KYTOS_URL/api/hackinsdn/containment/v1/ -d '{"switch": "'$INTFZ_SW'", "interface": '$INTFZ_PORT', "match": {"vlan": '$VLAN_ID', "'$BLOCK_FIELD'": "'$IP'"}}')

BLOCK_ID_A=failed
if echo "$RESULT_A" | egrep -q '"containment_id":".*"'; then
	BLOCK_ID_A=$(echo "$RESULT_A" | jq -r '.containment_id')
else
	echo "$(date) [WARN] Failed to block vlan=$VLAN ip=$IP intf=$INTFA result=$RESULT_A"
fi
BLOCK_ID_Z=failed
if echo "$RESULT_Z" | egrep -q '"containment_id":".*"'; then
	BLOCK_ID_Z=$(echo "$RESULT_Z" | jq -r '.containment_id')
else
	echo "$(date) [WARN] Failed to block vlan=$VLAN ip=$IP intf=$INTFZ result=$RESULT_Z"
fi

echo "$(date -u +%Y-%m-%d,%H:%M:%s) [BLOCK] vlan=$VLAN ip=$IP intf_a=$INTFA block_a=$BLOCK_ID_A intf_z=$INTFZ block_z=$BLOCK_ID_Z" >> /var/log/kytos-block.log

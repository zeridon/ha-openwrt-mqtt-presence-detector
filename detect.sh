#!/bin/ash

# Allow further customization via ENV variables
: ${MQTT_BASETOPIC:="location"}
: ${MQTT_STATUS_TOPIC:="${MQTT_BASETOPIC}"}
: ${MQTT_USER:=""}
: ${MQTT_PASSWORD:=""}
: ${DEFAULT_MQTT_SERVER:="10.1.1.50"}

DEFAULT_UPDATE_PERIOD_S=120

MODE=$DEFAULT_MODE
MQTT_SERVER=$DEFAULT_MQTT_SERVER
UPDATE_PERIOD_S=$DEFAULT_LAST_SEEN_UPDATE_PERIOD_S

SCRIPT_NAME="$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")"

MQTT_ID="${SCRIPT_NAME}-0.1"

test_for_ipv4(){
	param_ip=$1
	echo $param_ip | grep -E '\b((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\.|$)){4}\b' > /dev/null
	if [ $? -eq 0 ]; then
		MQTT_SERVER=$param_ip
		return 0
	fi
	return 1
}

test_for_update_periode_s(){
	param_up=$1
	expr $param_up : '[0-9][0-9]*$'
	if [ $? -eq 0 ]; then
		UPDATE_PERIOD_S=$param_up
		return 0
	fi
	return 1
}

print_usage(){
cat << EOF
Supported optional parameters:
		The registered mac addresses are periodically pushed to the MQTT server
	MQTT server IP: the IPv4 address of the MQTT server (default ${DEFAULT_MQTT_SERVER})
	Udate periode [s]: only relevant for lastseen mode (default ${DEFAULT_UPDATE_PERIOD_S})
Examples:
	${SCRIPT_NAME}
	${SCRIPT_NAME} 192.168.1.2
	${SCRIPT_NAME} 300
	${SCRIPT_NAME} 192.168.1.2 300
EOF
}

for param in "$@"; do
	test_for_ipv4 $param || \
	test_for_update_periode_s $param || \
	{ print_usage; exit 1; }
done


echo "${SCRIPT_NAME}, MQTT server: ${MQTT_SERVER}, period: ${LAST_SEEN_UPDATE_PERIOD_S}"
while true; do
	# Publish lastseen state of wifi devices
	for interface in $(iw dev | grep Interface | cut -f 2 -s -d" ") ; do
		# for each interface, get mac addresses of connected stations/clients
		maclist=$(iw dev $interface station dump | grep Station | cut -f 2 -s -d" ")
		for mac in $maclist ; do
			mosquitto_pub \
				-u $MQTT_USER \
				-P $MQTT_PASSWORD \
				-h $MQTT_SERVER \
				-i $MQTT_ID \
				-t "${MQTT_STATUS_TOPIC}/${mac//:/_}" \
				-m "{\"topic\":${MQTT_STATUS_TOPIC}/${mac//:/_}\",\"payload\":\"home\"}" -r
		done
	done
	sleep $UPDATE_PERIOD_S
done

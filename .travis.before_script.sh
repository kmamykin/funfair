#!/bin/sh

# guest:guest has full access to /

#rabbitmqctl add_vhost /
#rabbitmqctl add_user guest guest
#rabbitmqctl set_permissions -p / guest ".*" ".*" ".*"

# Drop all exchanges and queues before tests
rabbitmqctl stop_app
rabbitmqctl reset
rabbitmqctl start_app

sleep 3

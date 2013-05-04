#!/bin/sh

# Drop all exchanges and queues before tests
rabbitmqctl stop_app
rabbitmqctl reset
rabbitmqctl start_app

sleep 3

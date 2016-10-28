#!/bin/bash
source .env
nohup ruby ./locations_queue_worker.rb > daemons/locations_queue_worker.out 2>&1 & echo $! > daemons/locations_queue_worker.pid

#!/bin/bash
source .env
nohup ruby ./locations_queue_worker.rb > /var/www/rollfindr/shared/log/locations_queue_worker.out 2>&1 & echo $! > /var/www/rollfindr/shared/tmp/pids/locations_queue_worker.pid

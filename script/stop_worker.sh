#!/bin/bash
kill -s SIGTERM `cat /var/www/rollfindr/shared/tmp/pids/locations_queue_worker.pid`

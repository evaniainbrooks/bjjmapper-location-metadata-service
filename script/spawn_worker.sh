#!/bin/bash
source .env
nohup ruby ./images_queue_worker.rb > daemons/images_queue_worker.out 2>&1 & echo $! > daemons/images_queue_worker.pid

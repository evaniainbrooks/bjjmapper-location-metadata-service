#!/bin/bash
kill -s SIGTERM `cat daemons/images_queue_worker.pid`

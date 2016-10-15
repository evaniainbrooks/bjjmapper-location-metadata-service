#!/bin/bash
source .env
nohup ruby application.rb > daemons/application.out 2>&1 & echo $! > daemons/application.pid

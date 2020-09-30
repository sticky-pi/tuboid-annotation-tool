#!/bin/sh

# Make sure the directory for individual app logs exists
env | grep -v 'IGNORE' | grep -v -P '^_' | perl -pe 's/^([^=]+)=(.+)$/$1='"'"'$2'"'"'/' >> /home/shiny/env.R
mkdir -p /var/log/shiny-server
chown shiny.shiny /var/log/shiny-server
export APPLICATION_LOGS_TO_STDOUT=true
export SHINY_LOG_STDERR=1
exec shiny-server  #2>&1 #>> /var/log/shiny-server.log 2>&1

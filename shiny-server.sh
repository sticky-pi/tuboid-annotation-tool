#!/bin/sh

# Make sure the directory for individual app logs exists
env | grep -v 'IGNORE' | grep -v -P '^_' | perl -pe 's/^([^=]+)=(.+)$/$1='"'"'$2'"'"'/' >> /home/shiny/env.R
mkdir -p /var/log/shiny-server
chown shiny.shiny /var/log/shiny-server
export APPLICATION_LOGS_TO_STDOUT=true
export SHINY_LOG_STDERR=1


# runtime make s3 conf
cp /home/shiny/s3cfg_template /home/shiny/.s3cfg
echo "secret_key = ${S3_PRIVATE_KEY}" >> /home/shiny/.s3cfg
echo "host_base = ${S3_HOST}" >> /home/shiny/.s3cfg
echo "host_bucket = ${S3_HOST}" >> /home/shiny/.s3cfg
echo "access_key = ${S3_ACCESS_KEY}" >> /home/shiny/.s3cfg

chown shiny.shiny  /opt/data_root_dir/


exec shiny-server  #2>&1 #>> /var/log/shiny-server.log 2>&1

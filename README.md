# A shiny tool to manually label tiled tuboids.

Typically, tuboids are generated by the sticky pi siamese-insect-matcher in a directory structure:
```
<sticky_pi_client_root_dir>/tiled_tuboids/<series_id>/<tuboid_id>/
```

## On your machine/workstation, manually copy/upload all tuboids to a dedicated s3 bucket

1. Set up an s3bucket
```
TUBOID_DATA_DIR=<sticky_pi_client_root_dir>/tiled_tuboids
BUCKET_NAME=tuboid-annotation-data-2021
s3cmd mb s3://${BUCKET_NAME}
```

1. Make index file, and upload it:
```sh
OUTPUT=/tmp/index.csv
#Rscript make_s3_bucket_index.R ${TUBOID_DATA_DIR} $OUTPUT
echo 'tuboid_id, tuboid_dir' > $OUTPUT
for i in $( s3cmd ls s3://$BUCKET_NAME/ --recursive  | grep metadata\.txt | cut  -d : -f 3 | cut -c2-); do echo  $(basename $(dirname $i)), $(dirname  $(realpath --relative-to="/$BUCKET_NAME" $i  -m)) >> $OUTPUT; done
s3cmd put $OUTPUT s3://${BUCKET_NAME} && rm $OUTPUT
``` 

1. Generate taxonomy file, and upload it:
```sh
OUTPUT=/tmp/taxonomy.json
python pull_taxonomy.py $OUTPUT
s3cmd put $OUTPUT s3://${BUCKET_NAME} && rm $OUTPUT 
```

1. Put all the files, recursively
```
s3cmd sync ${TUBOID_DATA_DIR}/ s3://${BUCKET_NAME}
```

1. Make candidate labels
```
OUTPUT=/tmp/candidate_labels.csv
python make_candidates.py $OUTPUT
s3cmd put $OUTPUT s3://${BUCKET_NAME} && rm $OUTPUT
```

## Deployment

1. copy/make a s3cmd config file and name it `.secret_s3cmd_conf`  (in this directory). this can be a read-only key


```sh
BUCKET_NAME=tuboid-annotation-data-2021
VERSION=6.0
LOCAL_VOLUME=/opt/tuboid_annotation_volume
# should be open to the world (e.g via nginx proxying)
PORT=8099
SHINY_UID=9991
mkdir -p ${LOCAL_VOLUME}

# make credential file
# add your password username here
# READ-ONLY users should have "allow_write": 0
echo  '{"user1" : {"password": "password1", "allow_write": 1}}' > ${LOCAL_VOLUME}/credentials.json

chmod 460 ${LOCAL_VOLUME}/credentials.json
chown ${SHINY_UID}:root -R ${LOCAL_VOLUME}
```

```
cd /tmp/
git clone https://github.com/sticky-pi/tuboid-annotation-tool.git  tuboid-annotation-tool
cd tuboid-annotation-tool
docker build --build-arg SHINY_UID=${SHINY_UID} .  --tag tuboid-annotation-tool:$VERSION
docker run --rm  --publish $PORT:80 --name tuboid-annotation-tool --env DATA_ROOT_DIR=/opt/data_root_dir  --env S3_BUCKET=${BUCKET_NAME} --volume ${LOCAL_VOLUME}:/opt/data_root_dir -d  tuboid-annotation-tool:$VERSION
```


## send the annotated tuboid on the production bucket

```
DEST_S3_PREFIX=s3://sticky-pi-api-prod/ml/insect-tuboid-classifier/data
s3cmd put --force database.db $DEST_S3_PREFIX/database.db
for i in $(sqlite3 database.db "SELECT tuboid_id from annotations;");
do
  s3cmd cp s3://tuboid-annotation-data/"${i%.*}"/$i/ $DEST_S3_PREFIX/"${i%.*}"/$i/ --recursive;
done
```


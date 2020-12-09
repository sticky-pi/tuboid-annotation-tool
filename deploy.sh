VERSION=3.0

# tuboids is created by sticky_pi (ml_trainer/)
LOCAL_VOLUME=/opt/tuboid_annotation_volume

# should be open to the world (e.g via nginx)
PORT=8099

S3_BUCKET='sticky-pi-insect-tuboid-classifier-raw-images'

docker build . --tag insect_annotation:$VERSION
docker run --rm  --publish $PORT:80 --name insect_annotation --env DATA_ROOT_DIR=/opt/data_root_dir  --env S3_BUCKET=${S3_BUCKET}  --volume $LOCAL_VOLUME:/opt/data_root_dir -d  insect_annotation:$VERSION

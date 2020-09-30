# build taxonomy  using  pull_taxonomy.py

VERSION=1.0
# should exist and have files: credentials.json, taxonomy.json (see above), and tuboids/
#
# e.g in 
# ==============
# {
#   "USER":"PASSWORD"
# }

# tuboids is created by sticky_pi (ml_trainer/)
LOCAL_VOLUME=/opt/insect_annotation_volume

# should be open to the world
PORT=8099


docker build . --tag insect_annotation:$VERSION
docker run --rm  --publish $PORT:80 --name insect_annotation --env DATA_ROOT_DIR=/opt/data_root_dir --volume $LOCAL_VOLUME:/opt/data_root_dir -d  insect_annotation:$VERSION

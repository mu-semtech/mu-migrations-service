#!/bin/bash
MIGRATION_FORMAT=$1
MIGRATION_NAME=$2

if [ -z $MIGRATION_FORMAT ]
then
    echo "Migration format not supplied, exiting"
    exit 1
fi

if [ -z $MIGRATION_NAME ]
then
    echo "Migration format or migration name not supplied, exiting"
    exit 1
fi

if [[ "$MIGRATION_FORMAT" != "sparql" && "$MIGRATION_FORMAT" != "ttl" ]]
then
    echo "Migration format should be either sparql or ttl."
    echo "Received format '$MIGRATION_FORMAT'"
    exit 1
fi

MIGRATION_TIMESTAMP=`date +%Y%0m%0d%0H%0M%0S`
FILENAME="$MIGRATION_TIMESTAMP-$MIGRATION_NAME.$MIGRATION_FORMAT"
echo "Creating migration with name $FILENAME"
mkdir -p /data/app/config/migrations/
cd /data/app/config/migrations/
touch $FILENAME
echo "config/migrations/$FILENAME"

if [[ "$MIGRATION_FORMAT" = "ttl" ]]
then
  GRAPH_FILE_NAME="$MIGRATION_TIMESTAMP-$MIGRATION_NAME.graph"
  touch $GRAPH_FILE_NAME
  echo "config/migrations/$GRAPH_FILE_NAME"
fi

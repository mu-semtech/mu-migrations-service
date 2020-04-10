#!/bin/bash
MIGRATION_NAME=$1
MIGRATION_TIMESTAMP=`date +%Y%0m%0d%0H%0M%0S`
FILENAME="$MIGRATION_TIMESTAMP-$MIGRATION_NAME.sparql"
echo "Creating migration with name $FILENAME"
mkdir -p /data/app/config/migrations/
cd /data/app/config/migrations/
touch $FILENAME
echo "config/migrations/$FILENAME"

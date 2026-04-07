#!/bin/bash
#./run_upload.sh

# Configuration variables
KEY_FILE="scripts/firebase-key.json"
BUCKET_NAME="route-bkk.firebasestorage.app" # Your actual bucket name
SOURCE_DIR="assets/gtfs_data"

# Auto-increment version logic
VERSION_FILE="scripts/.gtfs_version"
if [ ! -f "$VERSION_FILE" ]; then
    echo 1 > "$VERSION_FILE"
fi
VERSION=$(cat "$VERSION_FILE")

echo "Starting upload process for GTFS data version $VERSION..."

# Run the python script
python3 scripts/upload_gtfs_data.py \
    --key "$KEY_FILE" \
    --bucket "$BUCKET_NAME" \
    --version "$VERSION" \
    --source "$SOURCE_DIR"

if [ $? -eq 0 ]; then
    echo "Upload successful!"
    # Increment version for next time
    NEXT_VERSION=$((VERSION + 1))
    echo $NEXT_VERSION > "$VERSION_FILE"
    echo "Next upload will be version $NEXT_VERSION."
else
    echo "Upload failed. Please check the error messages above."
    exit 1
fi

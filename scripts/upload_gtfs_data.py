import os
import zipfile
import json
import argparse
import firebase_admin
from firebase_admin import credentials, storage

def zip_directory(dir_path, zip_path):
    print(f"Zipping {dir_path} to {zip_path}...")
    with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
        for root, _, files in os.walk(dir_path):
            for file in files:
                file_path = os.path.join(root, file)
                # Ensure we only zip the relative path, not the exact file system path
                arcname = os.path.relpath(file_path, dir_path)
                zipf.write(file_path, arcname)
    print("Zipping complete.")

def upload_to_firebase(bucket_name, source_file_name, destination_blob_name):
    print(f"Uploading {source_file_name} to Firebase Storage bucket {bucket_name} as {destination_blob_name}...")
    bucket = storage.bucket(bucket_name)
    blob = bucket.blob(destination_blob_name)
    blob.upload_from_filename(source_file_name)
    print("Upload complete.")

def update_version(bucket_name, new_version):
    print(f"Updating version file in bucket to version: {new_version}...")
    bucket = storage.bucket(bucket_name)
    blob = bucket.blob("gtfs_version.json")
    version_data = {"version": new_version}
    blob.upload_from_string(json.dumps(version_data), content_type='application/json')
    print("Version update complete.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Zip and upload GTFS data to Firebase Storage")
    parser.add_argument("--key", required=True, help="Path to the Firebase Service Account JSON key")
    parser.add_argument("--bucket", required=True, help="Firebase Storage bucket name (e.g. your-project.appspot.com)")
    parser.add_argument("--version", required=True, type=int, help="The new version number for this GTFS dataset")
    parser.add_argument("--source", default="../assets/gtfs_data", help="Path to the GTFS data directory")
    args = parser.parse_args()

    # Initialize Firebase Admin
    cred = credentials.Certificate(args.key)
    firebase_admin.initialize_app(cred, {
        'storageBucket': args.bucket
    })

    zip_file_path = f"gtfs_data_v{args.version}.zip"

    # Zip the data
    zip_directory(args.source, zip_file_path)

    # Upload the zip and version file
    upload_to_firebase(args.bucket, zip_file_path, "gtfs_data_latest.zip")
    update_version(args.bucket, args.version)
    
    # Cleanup local zip file
    os.remove(zip_file_path)
    print(f"Successfully uploaded GTFS data version {args.version}!")

import os
import time
import schedule
from firebase_admin import credentials, initialize_app, storage, firestore
from datetime import datetime

# Inicjalizacja Firebase
cred = credentials.Certificate("cloudproject-privatekey.json")
initialize_app(cred, {
    'storageBucket': 'cloudproject-bda5e.firebasestorage.app'
})
db = firestore.client()

# Ścieżka lokalnego folderu upload
UPLOAD_FOLDER = "upload"

# Funkcja do przesyłania plików do Firebase Cloud Storage i dodawania metadanych do Firestore
def upload_files_to_firebase():
    bucket = storage.bucket()
    # Logowanie rozpoczęcia uploadu
    print(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')} STARTING_UPLOAD")
    # Licznik przesłanych plików
    uploaded_count = 0
    
    for filename in os.listdir(UPLOAD_FOLDER):
        file_path = os.path.join(UPLOAD_FOLDER, filename)

        if os.path.isfile(file_path):  # Sprawdzenie, czy to plik
            blob_path_og = f"IMAGES/OG/{filename}"
            blob = bucket.blob(blob_path_og)

            # Sprawdzanie, czy plik już istnieje w Storage
            if blob.exists():
                print(f"[ERROR] File {filename} already exists in Storage at {blob_path_og}. Skipping upload.")
                continue

            # Sprawdzanie, czy dokument już istnieje w Firestore
            doc_ref = db.collection("METADATA").document(filename)
            if doc_ref.get().exists:
                print(f"[ERROR] Metadata for {filename} already exists in Firestore. Skipping upload.")
                continue

            try:
                # Upload pliku do Cloud Storage
                blob.upload_from_filename(file_path)
                uploaded_count += 1
                print(f"[SUCCESS] Uploaded {filename} to {blob_path_og}.")

                # Dodanie dokumentu do kolekcji METADATA w Firestore
                metadata_doc = {
                    "IMAGE_ID": filename,
                    "PATH_OG": f"gs://cloudproject-bda5e.appspot.com/{blob_path_og}",
                    "PATH_THUMB": f"gs://cloudproject-bda5e.appspot.com/IMAGES/THUMBNAILS/{filename}_thumbnail.jpg",
                    "TAGS": "",  # Puste tagi na razie
                    "UPLOAD_DATE": datetime.now().strftime("%d.%m.%Y")
                }

                db.collection("METADATA").document(filename).set(metadata_doc)
                # Usunięcie plików po wykonaniu uploadu
                #os.remove(file_path)
                #print(f"[INFO] Deleted local file: {file_path}")
                print(f"[SUCCESS] Metadata for {filename} added to Firestore.")
            except Exception as e:
                print(f"[ERROR] Failed to upload {filename} or add metadata: {e}")
                
    if uploaded_count > 0:
        print(f"[INFO] Uploaded {uploaded_count} files.")
    else:
        print("[INFO] No files to upload.")

# Uruchom funkcję raz przy starcie skryptu
upload_files_to_firebase()

# Ustawienie schedulera
schedule.every(4).hours.do(upload_files_to_firebase)

print("Scheduler is running. Press Ctrl+C to exit.")

# Główna pętla
while True:
    schedule.run_pending()
    time.sleep(1)
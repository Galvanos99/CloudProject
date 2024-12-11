import os
import time
import schedule
from datetime import datetime
from googleapiclient.discovery import build
from googleapiclient.http import MediaIoBaseDownload
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request
from firebase_admin import credentials, initialize_app, storage, firestore
import pickle
import io

# Inicjalizacja Firebase
cred = credentials.Certificate("cloudproject-privatekey.json")
initialize_app(cred, {
    'storageBucket': 'cloudproject-bda5e.firebasestorage.app'
})
db = firestore.client()

# Inicjalizacja Google Drive API
SCOPES = ['https://www.googleapis.com/auth/drive']
GDRIVE_FOLDER_ID = "1frv9jifGd-nQ7X8byZyX5AgIFLTM7vDQ"  # Zamień na ID folderu w Google Drive

# Funkcja do autoryzacji Google Drive API
def authenticate_google_drive():
    creds = None
    # Sprawdź, czy token już istnieje
    if os.path.exists('token.pickle'):
        with open('token.pickle', 'rb') as token:
            creds = pickle.load(token)
    # Jeśli brak tokena lub token jest nieważny
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            flow = InstalledAppFlow.from_client_secrets_file(
                'client_secret.apps.googleusercontent.com.json', SCOPES
            )
            creds = flow.run_local_server(port=0)
        # Zapisz token do pliku
        with open('token.pickle', 'wb') as token:
            pickle.dump(creds, token)
    return build('drive', 'v3', credentials=creds)

drive_service = authenticate_google_drive()

# Funkcja do przesyłania plików do Firebase Cloud Storage i dodawania metadanych do Firestore
def upload_files_to_firebase():
    bucket = storage.bucket()
    print(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')} STARTING_UPLOAD")

    results = drive_service.files().list(
        q=f"'{GDRIVE_FOLDER_ID}' in parents and trashed=false",
        spaces='drive',
        fields='files(id, name)'
    ).execute()
    files = results.get('files', [])

    if not files:
        print("[INFO] No files found in Google Drive folder.")
        return

    for file in files:
        file_id = file['id']
        file_name = file['name']

        blob_path_og = f"IMAGES/OG/{file_name}"
        blob = bucket.blob(blob_path_og)

        if blob.exists():
            print(f"[ERROR] File {file_name} already exists in Storage at {blob_path_og}. Skipping upload.")
            continue

        doc_ref = db.collection("METADATA").document(file_name)
        if doc_ref.get().exists:
            print(f"[ERROR] Metadata for {file_name} already exists in Firestore. Skipping upload.")
            continue

        try:
            # Pobierz plik z Google Drive do pamięci
            request = drive_service.files().get_media(fileId=file_id)
            file_data = io.BytesIO()
            downloader = MediaIoBaseDownload(file_data, request)
            done = False
            while not done:
                status, done = downloader.next_chunk()
                print(f"[INFO] Downloading {file_name}: {int(status.progress() * 100)}%")

        # Ustaw wskaźnik na początek strumienia
            file_data.seek(0)

            # Określenie typu zawartości (mimetype) na podstawie rozszerzenia pliku
            content_type = 'application/octet-stream'
            if '.' in file_name:
                ext = file_name.rsplit('.', 1)[1].lower()
                if ext in ['jpg', 'jpeg']:
                    content_type = 'image/jpeg'
                elif ext == 'png':
                    content_type = 'image/png'
                elif ext == 'gif':
                    content_type = 'image/gif'

            # Prześlij plik do Firebase Storage
            blob.upload_from_file(file_data, content_type=content_type)
            print(f"[SUCCESS] Uploaded {file_name} to {blob_path_og}.")

            metadata_doc = {
                "IMAGE_ID": file_name,
                "PATH_OG": f"gs://cloudproject-bda5e.appspot.com/{blob_path_og}",
                "PATH_THUMB": f"gs://cloudproject-bda5e.appspot.com/IMAGES/THUMBNAILS/{file_name}_thumbnail.jpg",
                "TAGS": "",
                "UPLOAD_DATE": datetime.now().strftime("%d.%m.%Y")
            }

            db.collection("METADATA").document(file_name).set(metadata_doc)
            print(f"[SUCCESS] Metadata for {file_name} added to Firestore.")

            # Usunięcie pliku z Google Drive
            drive_service.files().delete(fileId=file_id).execute()
            print(f"[INFO] Deleted file from Google Drive: {file_name}")

        except Exception as e:
            print(f"[ERROR] Failed to upload {file_name} or add metadata: {e}")

# Uruchom funkcję raz przy starcie skryptu
upload_files_to_firebase()

# Ustawienie schedulera
schedule.every(4).seconds.do(upload_files_to_firebase)

print("Scheduler is running. Press Ctrl+C to exit.")

while True:
    log = open('log.txt', 'a')
    log.write(f"[LOG] {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
    log.close()
    schedule.run_pending()
    time.sleep(1)
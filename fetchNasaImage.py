import httpx
from typing import Any, Dict, Optional, List
from datetime import datetime, timedelta
import random
import sys
import firebase_admin
from firebase_admin import credentials
from firebase_admin import storage
import os
from firebase_admin import credentials, db
import uuid

class FirebaseUploader:

    def __init__(self, database_service):
        self.bucket = storage.bucket()
        self.metadata_uploader = database_service

    def upload_image(self, image_content, image_name, unique_id):
        try:
            blob = self.bucket.blob(image_name)
            blob.metadata = {'id': unique_id}

            
            blob.upload_from_string(image_content, content_type="image/jpeg")
            public_url = blob.public_url
            print(f"Image uploaded successfully! Public URL: {public_url}")

            return public_url
            
        except httpx.RequestError as e:
            print(f"Failed to upload {public_url}: {e}")

        

class RestClient:

    def __init__(self, base_url: str):
        self.base_url = base_url

    async def get(self, endpoint: str, params: Optional[Dict[str, Any]] = None) -> Dict:


        async with httpx.AsyncClient() as client:
            response = await client.get(f"{self.base_url}{endpoint}", params=params)
            response.raise_for_status()
            return response.json()

class ApiService:

    def __init__(self, client: RestClient):
        self.client = client

    async def fetch_data(self, endpoint: str, query_params: Dict[str, Any]) -> List[Dict]:

        json_response = await self.client.get(endpoint, params=query_params)
        return self.parse_json(json_response)

    def parse_json(self, json_data: Dict) -> List[Dict]:

        if isinstance(json_data, list):
            return json_data
        elif isinstance(json_data, dict):
            return [json_data]
        else:
            raise ValueError("Unexpected JSON structure")

class FirebaseDatabaseHandler:

    def __init__(self, path):
        self.path = path

    def write_metadata(self, metadata, id):
        ref = db.reference(self.path + id)
        result = ref.set(metadata)
        print(result)
        print(f"Data saved to Firebase Realtime Database at path: {self.path}{id}")
  
class ImageDownloader:

    def __init__(self):
        pass
        

    def download_image(self, image_url, image_title):

        try:
            print(f"Downloading: {image_title} from {image_url}")

            with httpx.stream("GET", image_url) as response:
                response.raise_for_status()
                image_content = b"".join(response.iter_bytes())

            return image_content

            
        except httpx.RequestError as e:
            print(f"Failed to download {image_title} from {image_url}: {e}")

def get_random_date(start_year=2016, end_year=2024):
    
    start_date = datetime(start_year, 1, 1)
    end_date = datetime(end_year, 12, 31)
    random_days = random.randint(0, (end_date - start_date).days)
    random_date = start_date + timedelta(days=random_days)
    return random_date.strftime("%Y-%m-%d")
    
    


async def main():
    
    
    base_url = "https://api.nasa.gov"
    cred = credentials.Certificate(os.environ['GCP_JSON_PATH'])
    firebase_admin.initialize_app(cred, {
            'storageBucket': os.environ['BUCKET_NAME'],
            'databaseURL': os.environ['REALTIMEDB_NAME']
    })
    rest_client = RestClient(base_url)
    api_service = ApiService(rest_client)
    database_service = FirebaseDatabaseHandler("images/")
    uploader_service = FirebaseUploader(database_service)
    downloader_service = ImageDownloader()


    endpoint = "/planetary/apod"
    random_date = get_random_date()
    query_params = {"api_key": os.environ['NASA_API_KEY'], "start_date": random_date, "end_date": random_date}


    try:
        data = await api_service.fetch_data(endpoint, query_params)
        for i, item in enumerate(data):
            if "url" in item and item["media_type"] == "image":
                unique_id = str(uuid.uuid4())
                metadata = {
                    "title": item["title"],
                    "description": item["explanation"],
                    "date": item["date"]
                    }
                image_title = item.get("title", f"image_{i}").replace(" ", "_").replace("/", "-")
                image = downloader_service.download_image(item["url"],item["title"])
                public_url = uploader_service.upload_image(image, image_title + ".jpg", unique_id)
                metadata["url"] = public_url
                database_service.write_metadata(metadata,unique_id)

    except httpx.HTTPStatusError as e:
        print(f"HTTP error occurred: {e}")
    except Exception as e:
        print(f"An error occurred: {e}")


if __name__ == "__main__":
    import asyncio
    asyncio.run(main())
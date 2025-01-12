import requests
import json

# URL Twojej funkcji Cloud
CLOUD_FUNCTION_URL = "https://us-central1-nasaapp-446811.cloudfunctions.net/createThumbnails"

# Przykładowe dane wejściowe do testowania
payload = {
    "imageUrl": "https://firebasestorage.googleapis.com/v0/b/nasaapp-446811.firebasestorage.app/o/The_Great_Nebula_in_Carina.jpg?alt=media&token=8daff29a-a004-4910-9018-ccf9bef9ec1a",
    "width": 300,  # Szerokość miniatury
    "height": 300  # Wysokość miniatury
}

# Wysyłanie POST request
response = requests.post(
    CLOUD_FUNCTION_URL,
    headers={"Content-Type": "application/json"},
    data=json.dumps(payload)
)

# Wyświetlenie odpowiedzi
if response.status_code == 200:
    print("Thumbnail created successfully!")
    print("Response:", response.json())
else:
    print(f"Error ({response.status_code}): {response.text}")



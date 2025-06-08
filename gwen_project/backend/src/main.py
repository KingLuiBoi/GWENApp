from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
import os
import json
import openai
import requests
import tempfile
import time
from elevenlabs import generate, save, set_api_key
import math

app = Flask(__name__)
CORS(app)

# Configure API keys from environment variables
openai.api_key = os.environ.get("OPENAI_API_KEY")
elevenlabs_api_key = os.environ.get("ELEVENLABS_API_KEY")
gwen_voice_id = os.environ.get("GWEN_VOICE_ID")

# Set ElevenLabs API key
if elevenlabs_api_key:
    set_api_key(elevenlabs_api_key)

# In-memory storage for time capsules, reminders, and user location
time_capsules = []
location_reminders = []
user_location = {"latitude": 0, "longitude": 0}

# In-memory storage for places data to replace Google Places API
sample_places = {
    "restaurant": [
        {"name": "Cafe Delight", "place_id": "cafe_delight_01", "vicinity": "123 Main St", "latitude": 37.7749, "longitude": -122.4194, "rating": 4.5, "types": ["restaurant", "cafe"]},
        {"name": "Burger Joint", "place_id": "burger_joint_02", "vicinity": "456 Market St", "latitude": 37.7746, "longitude": -122.4172, "rating": 4.2, "types": ["restaurant", "fast_food"]},
        {"name": "Pizza Palace", "place_id": "pizza_palace_03", "vicinity": "789 Mission St", "latitude": 37.7850, "longitude": -122.4064, "rating": 4.7, "types": ["restaurant", "italian"]},
    ],
    "cafe": [
        {"name": "Morning Brew", "place_id": "morning_brew_01", "vicinity": "101 Howard St", "latitude": 37.7891, "longitude": -122.3964, "rating": 4.8, "types": ["cafe", "bakery"]},
        {"name": "Tea Time", "place_id": "tea_time_02", "vicinity": "202 Folsom St", "latitude": 37.7897, "longitude": -122.3905, "rating": 4.3, "types": ["cafe", "tea_house"]},
    ],
    "store": [
        {"name": "Market Fresh", "place_id": "market_fresh_01", "vicinity": "303 Beale St", "latitude": 37.7896, "longitude": -122.3913, "rating": 4.4, "types": ["store", "grocery"]},
        {"name": "Tech Shop", "place_id": "tech_shop_02", "vicinity": "404 Spear St", "latitude": 37.7902, "longitude": -122.3894, "rating": 4.6, "types": ["store", "electronics"]},
    ],
    "park": [
        {"name": "Green Gardens", "place_id": "green_gardens_01", "vicinity": "505 Bryant St", "latitude": 37.7832, "longitude": -122.3954, "rating": 4.9, "types": ["park", "garden"]},
        {"name": "City Park", "place_id": "city_park_02", "vicinity": "606 Brannan St", "latitude": 37.7786, "longitude": -122.3962, "rating": 4.7, "types": ["park", "playground"]},
    ]
}

# Sample place details to replace Google Place Details API
place_details = {
    "cafe_delight_01": {
        "name": "Cafe Delight",
        "address": "123 Main St, San Francisco, CA 94105",
        "phone": "+1 (415) 555-1234",
        "latitude": 37.7749,
        "longitude": -122.4194,
        "website": "https://cafedelight.example.com",
        "rating": 4.5,
        "opening_hours": [
            "Monday: 7:00 AM – 7:00 PM",
            "Tuesday: 7:00 AM – 7:00 PM",
            "Wednesday: 7:00 AM – 7:00 PM",
            "Thursday: 7:00 AM – 7:00 PM",
            "Friday: 7:00 AM – 8:00 PM",
            "Saturday: 8:00 AM – 8:00 PM",
            "Sunday: 8:00 AM – 6:00 PM"
        ],
        "reviews": [
            {"author": "Jane Smith", "rating": 5, "text": "Great coffee and atmosphere!", "time": int(time.time()) - 86400},
            {"author": "John Doe", "rating": 4, "text": "Good service but a bit pricey.", "time": int(time.time()) - 172800}
        ]
    }
}

# Add more sample place details for all place IDs
for category in sample_places:
    for place in sample_places[category]:
        if place["place_id"] not in place_details:
            place_details[place["place_id"]] = {
                "name": place["name"],
                "address": place["vicinity"] + ", San Francisco, CA 94105",
                "phone": "+1 (415) 555-" + "".join([str(i) for i in range(4)]),
                "latitude": place["latitude"],
                "longitude": place["longitude"],
                "website": "https://" + place["place_id"].replace("_", "") + ".example.com",
                "rating": place["rating"],
                "opening_hours": [
                    "Monday: 9:00 AM – 6:00 PM",
                    "Tuesday: 9:00 AM – 6:00 PM",
                    "Wednesday: 9:00 AM – 6:00 PM",
                    "Thursday: 9:00 AM – 6:00 PM",
                    "Friday: 9:00 AM – 7:00 PM",
                    "Saturday: 10:00 AM – 5:00 PM",
                    "Sunday: 10:00 AM – 4:00 PM"
                ],
                "reviews": [
                    {"author": "User" + str(i), "rating": min(5, int(place["rating"]) + (i % 2)), 
                     "text": "Sample review " + str(i), "time": int(time.time()) - (i * 86400)}
                    for i in range(1, 4)
                ]
            }

@app.route('/gwen', methods=['POST'])
def gwen_response():
    try:
        data = request.json
        prompt = data.get('prompt', '')
        
        if not prompt:
            return jsonify({"error": "No prompt provided"}), 400
        
        # Get response from OpenAI
        response = openai.ChatCompletion.create(
            model="gpt-4",
            messages=[
                {"role": "system", "content": "You are GWEN, a helpful AI assistant similar to Jarvis from Iron Man. You are concise, helpful, and slightly witty. You assist with day-to-day tasks, answer questions, and provide useful information."},
                {"role": "user", "content": prompt}
            ]
        )
        
        text_response = response.choices[0].message.content
        
        # Generate audio from text using ElevenLabs
        if not elevenlabs_api_key or not gwen_voice_id:
            return jsonify({"error": "ElevenLabs API key or voice ID not configured"}), 500
        
        audio = generate(
            text=text_response,
            voice=gwen_voice_id,
            model="eleven_monolingual_v1"
        )
        
        # Save audio to a temporary file
        temp_file = tempfile.NamedTemporaryFile(delete=False, suffix=".mp3")
        save(audio, temp_file.name)
        temp_file.close()
        
        # Return the audio file and text response
        return send_file(
            temp_file.name,
            mimetype="audio/mpeg",
            as_attachment=True,
            download_name="gwen_response.mp3",
            headers={"X-GWEN-Response-Text": text_response}
        )
    
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/timecapsule', methods=['GET', 'POST'])
def time_capsule():
    if request.method == 'POST':
        try:
            data = request.json
            note = data.get('note', '')
            timestamp = data.get('timestamp', time.time())
            
            if not note:
                return jsonify({"error": "No note provided"}), 400
            
            time_capsules.append({
                "id": len(time_capsules) + 1,
                "note": note,
                "timestamp": timestamp,
                "created_at": time.time()
            })
            
            return jsonify({"success": True, "id": len(time_capsules)}), 201
        
        except Exception as e:
            return jsonify({"error": str(e)}), 500
    
    else:  # GET
        return jsonify(time_capsules), 200

@app.route('/timecapsule/<int:capsule_id>', methods=['GET', 'DELETE'])
def time_capsule_detail(capsule_id):
    try:
        capsule = next((c for c in time_capsules if c["id"] == capsule_id), None)
        
        if not capsule:
            return jsonify({"error": "Time capsule not found"}), 404
        
        if request.method == 'DELETE':
            time_capsules.remove(capsule)
            return jsonify({"success": True}), 200
        
        return jsonify(capsule), 200
    
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/reminder/location', methods=['GET', 'POST'])
def location_reminder():
    if request.method == 'POST':
        try:
            data = request.json
            reminder = data.get('reminder', '')
            latitude = data.get('latitude')
            longitude = data.get('longitude')
            place_name = data.get('place_name', '')
            radius = data.get('radius', 100)  # Default radius in meters
            
            if not reminder or latitude is None or longitude is None:
                return jsonify({"error": "Missing required fields"}), 400
            
            location_reminders.append({
                "id": len(location_reminders) + 1,
                "reminder": reminder,
                "latitude": latitude,
                "longitude": longitude,
                "place_name": place_name,
                "radius": radius,
                "created_at": time.time()
            })
            
            return jsonify({"success": True, "id": len(location_reminders)}), 201
        
        except Exception as e:
            return jsonify({"error": str(e)}), 500
    
    else:  # GET
        return jsonify(location_reminders), 200

@app.route('/reminder/location/<int:reminder_id>', methods=['GET', 'DELETE'])
def location_reminder_detail(reminder_id):
    try:
        reminder = next((r for r in location_reminders if r["id"] == reminder_id), None)
        
        if not reminder:
            return jsonify({"error": "Location reminder not found"}), 404
        
        if request.method == 'DELETE':
            location_reminders.remove(reminder)
            return jsonify({"success": True}), 200
        
        return jsonify(reminder), 200
    
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/location/update', methods=['POST'])
def update_location():
    try:
        data = request.json
        latitude = data.get('latitude')
        longitude = data.get('longitude')
        
        if latitude is None or longitude is None:
            return jsonify({"error": "Missing latitude or longitude"}), 400
        
        user_location["latitude"] = latitude
        user_location["longitude"] = longitude
        
        # Check for nearby reminders
        nearby_reminders = []
        for reminder in location_reminders:
            # Calculate distance using Haversine formula
            lat1, lon1 = latitude, longitude
            lat2, lon2 = reminder["latitude"], reminder["longitude"]
            
            # Convert latitude and longitude from degrees to radians
            lat1_rad = math.radians(lat1)
            lon1_rad = math.radians(lon1)
            lat2_rad = math.radians(lat2)
            lon2_rad = math.radians(lon2)
            
            # Haversine formula
            dlon = lon2_rad - lon1_rad
            dlat = lat2_rad - lat1_rad
            a = math.sin(dlat/2)**2 + math.cos(lat1_rad) * math.cos(lat2_rad) * math.sin(dlon/2)**2
            c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
            distance = 6371000 * c  # Earth radius in meters
            
            if distance < reminder["radius"]:
                nearby_reminders.append(reminder)
        
        return jsonify({
            "success": True, 
            "nearby_reminders": nearby_reminders
        }), 200
    
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/places/search', methods=['GET'])
def search_places():
    try:
        latitude = request.args.get('latitude', type=float)
        longitude = request.args.get('longitude', type=float)
        place_type = request.args.get('type', 'restaurant')
        radius = request.args.get('radius', 1000, type=int)
        
        if latitude is None or longitude is None:
            return jsonify({"error": "Missing latitude or longitude"}), 400
        
        # Use our sample places data instead of Google Places API
        places = []
        
        # Get places of the requested type, or all places if type not found
        place_list = sample_places.get(place_type, [])
        if not place_list:
            # If specific type not found, return places from all categories
            for category in sample_places:
                places.extend(sample_places[category])
        else:
            places = place_list.copy()
        
        # Filter places by distance (using Haversine formula)
        filtered_places = []
        for place in places:
            # Calculate distance
            lat1, lon1 = latitude, longitude
            lat2, lon2 = place["latitude"], place["longitude"]
            
            # Convert latitude and longitude from degrees to radians
            lat1_rad = math.radians(lat1)
            lon1_rad = math.radians(lon1)
            lat2_rad = math.radians(lat2)
            lon2_rad = math.radians(lon2)
            
            # Haversine formula
            dlon = lon2_rad - lon1_rad
            dlat = lat2_rad - lat1_rad
            a = math.sin(dlat/2)**2 + math.cos(lat1_rad) * math.cos(lat2_rad) * math.sin(dlon/2)**2
            c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
            distance = 6371000 * c  # Earth radius in meters
            
            if distance <= radius:
                filtered_places.append(place)
        
        return jsonify(filtered_places), 200
    
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/places/detail/<place_id>', methods=['GET'])
def place_detail(place_id):
    try:
        if not place_id:
            return jsonify({"error": "Missing place_id"}), 400
        
        # Use our sample place details instead of Google Place Details API
        if place_id not in place_details:
            return jsonify({"error": "Place not found"}), 404
        
        return jsonify(place_details[place_id]), 200
    
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/geocode', methods=['GET'])
def geocode_address():
    try:
        address = request.args.get('address')
        
        if not address:
            return jsonify({"error": "No address provided"}), 400
        
        # Simple mock geocoding - in a real app, this would use MapKit on the client side
        # For this example, we'll return a fixed location in San Francisco
        mock_locations = {
            "san francisco": {"latitude": 37.7749, "longitude": -122.4194},
            "new york": {"latitude": 40.7128, "longitude": -74.0060},
            "los angeles": {"latitude": 34.0522, "longitude": -118.2437},
            "chicago": {"latitude": 41.8781, "longitude": -87.6298},
            "houston": {"latitude": 29.7604, "longitude": -95.3698}
        }
        
        # Try to find a match in our mock data
        address_lower = address.lower()
        location = None
        
        for key, value in mock_locations.items():
            if key in address_lower:
                location = value
                break
        
        # Default to San Francisco if no match
        if not location:
            location = mock_locations["san francisco"]
        
        return jsonify({
            "address": address,
            "latitude": location["latitude"],
            "longitude": location["longitude"]
        }), 200
    
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({
        "status": "healthy",
        "openai_api_key_set": bool(openai.api_key),
        "elevenlabs_api_key_set": bool(elevenlabs_api_key),
        "gwen_voice_id_set": bool(gwen_voice_id),
        "google_api_key_set": False,  # Always false now since we don't use Google API
        "using_apple_mapkit": True    # Indicate we're using Apple MapKit
    }), 200

if __name__ == '__main__':
    # Print startup message
    print("Starting GWEN backend server...")
    print(f"OpenAI API Key set: {bool(openai.api_key)}")
    print(f"ElevenLabs API Key set: {bool(elevenlabs_api_key)}")
    print(f"GWEN Voice ID set: {bool(gwen_voice_id)}")
    print(f"Using Apple MapKit: True")
    
    # Run the Flask app
    app.run(host='0.0.0.0', port=5050, debug=True)

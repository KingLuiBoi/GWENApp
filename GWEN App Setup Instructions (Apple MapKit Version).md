# GWEN App Setup Instructions (Apple MapKit Version)

This document provides detailed instructions for setting up and running the GWEN app, including both the backend server and the iOS/watchOS app.

## 1. Backend Setup

### Prerequisites
- Python 3.8 or higher
- pip (Python package installer)
- API keys for:
  - OpenAI
  - ElevenLabs (with a custom GWEN voice ID)

### Setup Steps

1. **Extract the backend files**
   - Extract `gwen_project_backend_apple_only.zip` to a location on your Mac

2. **Navigate to the backend directory**
   - Open Terminal
   - Use the `cd` command to navigate to the extracted backend directory
   ```bash
   cd path/to/gwen_project/backend
   ```

3. **Create and activate a virtual environment**
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   ```

4. **Install dependencies**
   ```bash
   pip install -r requirements.txt
   ```

5. **Set environment variables**
   ```bash
   export OPENAI_API_KEY="your_actual_openai_key_here"
   export ELEVENLABS_API_KEY="your_actual_elevenlabs_key_here"
   export GWEN_VOICE_ID="your_actual_gwen_voice_id_from_elevenlabs"
   ```
   Note: Google API key is no longer required as we've refactored to use Apple MapKit exclusively.

6. **Run the Flask server**
   ```bash
   python src/main.py
   ```

7. **Note the IP address**
   - When the server starts, it will display lines like:
   ```
   * Running on http://127.0.0.1:5050
   * Running on http://10.0.0.118:5050
   ```
   - Note the second IP address (e.g., `10.0.0.118:5050`) - this is what you'll need for the iOS app

## 2. iOS/watchOS App Setup

### Prerequisites
- Xcode 16.3 or higher
- iOS device or simulator (for testing the iOS app)
- Apple Watch device or simulator (for testing the watchOS app)

### Setup Steps

1. **Extract the Xcode project files**
   - Extract `GWENApp_iOS_watchOS.zip` to a location on your Mac

2. **Create a new Xcode project**
   - Open Xcode
   - Create a new iOS App project (File > New > Project > iOS > App)
   - Name it "GWENApp" or any name you prefer
   - Select SwiftUI for the interface and Swift for the language

3. **Add the GWEN app files to your project**
   - In Finder, navigate to the extracted `GWENApp` folder
   - Select all folders (Models, Services, ViewModels, Views) and the GWENAppApp.swift file
   - Drag them into your Xcode project navigator
   - When prompted, ensure "Copy items if needed" is checked and your app target is selected

4. **Update the backend IP address**
   - In Xcode, navigate to Services/NetworkingService.swift
   - Find the line with `private let baseURL = "http://127.0.0.1:5050"` (or similar)
   - Replace it with your actual backend IP address:
   ```swift
   private let baseURL = "http://YOUR_MAC_IP:5050"
   ```
   - Replace `YOUR_MAC_IP` with the IP address noted from step 7 of the backend setup

5. **Build and run the app**
   - Select your target device or simulator
   - Click the Play button or press Cmd+R to build and run the app

## 3. Testing the App

1. **Test GWEN Chat**
   - On the app's main screen, tap the microphone button and say "Hey GWEN, what's the weather today?"
   - GWEN should respond with an audio reply and display a text transcript

2. **Test Time Capsule**
   - Navigate to the Time Capsule tab
   - Create a new time capsule entry
   - Verify it appears in the list

3. **Test Reminders**
   - Navigate to the Reminders tab
   - Create a new location-based reminder
   - Verify it appears on the map (using Apple Maps)

4. **Test Places**
   - Navigate to the Places tab
   - Search for nearby places
   - Verify they appear on the map (using Apple Maps)

## 4. Troubleshooting

### Backend Issues
- Ensure all API keys are correctly set
- Check that the Flask server is running without errors
- Verify your Mac's firewall isn't blocking the connection

### iOS App Issues
- Ensure the backend IP address is correctly set in NetworkingService.swift
- Make sure your iOS device is on the same network as your Mac
- Check Xcode console for any error messages

### Connection Issues
- If the app can't connect to the backend, try restarting the Flask server
- Verify your Mac's IP address hasn't changed (if it has, update NetworkingService.swift)

## 5. Important Notes About Apple MapKit Integration

The app now uses Apple MapKit exclusively for all location-based features:

- The frontend (iOS/watchOS) uses MapKit for displaying maps and handling user interactions
- The backend uses a simplified location service that doesn't require Google API keys
- All place data is handled locally, eliminating external API dependencies
- This approach provides a fully native Apple experience and simplifies deployment

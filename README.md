# GWEN AI Assistant App

A voice-powered AI assistant for iPhone and Apple Watch that helps with daily tasks, reminders, time capsules, and location-based features.

## Features

- **Voice Interaction**: "Hey GWEN" wake word detection and voice commands
- **AI Chat**: Powered by OpenAI GPT-4 with ElevenLabs voice synthesis
- **Time Capsule**: Create and manage time-delayed messages
- **Location Reminders**: Set location-based reminders using Apple MapKit
- **Places Search**: Find nearby places using Apple MapKit
- **Apple Watch Support**: Full functionality on Apple Watch

## Prerequisites

- Xcode 16.3 or higher
- iOS 17.0+ / watchOS 10.0+
- Python 3.8+ (for backend)
- API Keys:
  - OpenAI API Key
  - ElevenLabs API Key with custom GWEN voice ID

## Setup Instructions

### 1. Backend Setup

1. **Navigate to backend directory**:
   ```bash
   cd gwen_project/backend
   ```

2. **Create virtual environment**:
   ```bash
   python3 -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

3. **Install dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

4. **Set environment variables**:
   ```bash
   export OPENAI_API_KEY="your_openai_api_key"
   export ELEVENLABS_API_KEY="your_elevenlabs_api_key"
   export GWEN_VOICE_ID="your_gwen_voice_id"
   ```

5. **Start the backend server**:
   ```bash
   python src/main.py
   ```

6. **Note the server IP address** (you'll need this for the iOS app):
   - Look for output like: `Running on http://10.0.0.118:5050`
   - Use the second IP address (not 127.0.0.1)

### 2. iOS App Setup

1. **Open the project in Xcode**:
   - Open `GWENApp 3/` folder in Xcode
   - Or create a new iOS App project and add the files

2. **Update backend URL**:
   - Open `Services/NetworkingService.swift`
   - Update the `baseURL` to your backend IP:
   ```swift
   private let baseURL = "http://YOUR_MAC_IP:5050"
   ```

3. **Configure app permissions**:
   - Add these to your `Info.plist`:
   ```xml
   <key>NSMicrophoneUsageDescription</key>
   <string>GWEN needs microphone access for voice commands</string>
   <key>NSSpeechRecognitionUsageDescription</key>
   <string>GWEN needs speech recognition for voice commands</string>
   <key>NSLocationWhenInUseUsageDescription</key>
   <string>GWEN needs location access for location-based features</string>
   ```

4. **Build and run**:
   - Select your target device/simulator
   - Press Cmd+R to build and run

## Usage

### Voice Commands
- Say "Hey GWEN" to wake up the assistant
- Ask questions like "What's the weather today?" or "Set a reminder"
- Tap the microphone button for manual voice input

### Features
- **Chat**: Type or speak to GWEN for AI-powered assistance
- **Time Capsule**: Create messages that will be delivered at a future date
- **Reminders**: Set location-based reminders that trigger when you're nearby
- **Places**: Search for nearby restaurants, cafes, stores, and parks

## Troubleshooting

### Backend Issues
- Ensure all API keys are correctly set
- Check that the Flask server is running without errors
- Verify your Mac's firewall isn't blocking port 5050

### iOS App Issues
- Ensure the backend IP address is correctly set in NetworkingService.swift
- Make sure your iOS device is on the same network as your Mac
- Check Xcode console for any error messages
- Verify microphone and speech recognition permissions are granted

### Connection Issues
- If the app can't connect to the backend, try restarting the Flask server
- Verify your Mac's IP address hasn't changed
- Check that both devices are on the same WiFi network

## Architecture

The app follows MVVM architecture with protocol-oriented design:

- **Models**: Data structures for chat, time capsules, reminders, and places
- **Views**: SwiftUI views for iOS and watchOS
- **ViewModels**: Business logic and state management
- **Services**: Protocol-based services for networking, voice input, audio playback, location, and MapKit

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the MIT License.
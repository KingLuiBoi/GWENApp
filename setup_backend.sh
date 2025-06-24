#!/bin/bash

echo "🚀 GWEN AI Assistant Backend Setup"
echo "=================================="

# Check if Python 3 is installed
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is not installed. Please install Python 3.8 or higher."
    exit 1
fi

# Navigate to backend directory
cd gwen_project/backend

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo "📦 Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
echo "🔧 Activating virtual environment..."
source venv/bin/activate

# Install dependencies
echo "📚 Installing dependencies..."
pip install -r requirements.txt

# Check if environment variables are set
echo "🔑 Checking environment variables..."

if [ -z "$OPENAI_API_KEY" ]; then
    echo "⚠️  OPENAI_API_KEY is not set"
    echo "   Please set it with: export OPENAI_API_KEY='your_key_here'"
fi

if [ -z "$ELEVENLABS_API_KEY" ]; then
    echo "⚠️  ELEVENLABS_API_KEY is not set"
    echo "   Please set it with: export ELEVENLABS_API_KEY='your_key_here'"
fi

if [ -z "$GWEN_VOICE_ID" ]; then
    echo "⚠️  GWEN_VOICE_ID is not set"
    echo "   Please set it with: export GWEN_VOICE_ID='your_voice_id_here'"
fi

echo ""
echo "✅ Backend setup complete!"
echo ""
echo "📋 Next steps:"
echo "1. Set your API keys (see warnings above)"
echo "2. Run: python src/main.py"
echo "3. Note the IP address shown when the server starts"
echo "4. Update the iOS app's NetworkingService.swift with that IP"
echo ""
echo "🔗 For detailed instructions, see README.md" 
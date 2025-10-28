#!/bin/bash

echo "ToggleTalk Flask Server Startup Script"
echo "====================================="

# Check if we're on Linux/Raspberry Pi
echo "Checking system..."
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "Linux system detected"
else
    echo "This script is designed for Linux systems"
    exit 1
fi

# Check if Python is installed
echo "Checking Python installation..."
if command -v python3 &> /dev/null; then
    echo "Python 3 is installed"
    PYTHON_CMD=python3
elif command -v python &> /dev/null; then
    echo "Python is installed"
    PYTHON_CMD=python
else
    echo "Python is not installed"
    echo "Please install Python 3.7 or later"
    exit 1
fi

# Check if virtual environment exists, create if not
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    $PYTHON_CMD -m venv venv
    if [ $? -ne 0 ]; then
        echo "Failed to create virtual environment"
        exit 1
    fi
    echo "Virtual environment created"
else
    echo "Virtual environment already exists"
fi

# Activate virtual environment
echo "Activating virtual environment..."
source venv/bin/activate
if [ $? -ne 0 ]; then
    echo "Failed to activate virtual environment"
    exit 1
fi
echo "Virtual environment activated"

# Upgrade pip
echo "Upgrading pip..."
pip install --upgrade pip
if [ $? -ne 0 ]; then
    echo "Failed to upgrade pip"
    exit 1
fi

# Install requirements
echo "Installing requirements..."
pip install -r requirements.txt
if [ $? -ne 0 ]; then
    echo "Failed to install requirements"
    exit 1
fi
echo "Requirements installed"

# Set environment variables
echo "Setting environment variables..."
export AUTHORIZED_CHAT_ID="1767023771"
export SERVER_PORT="${SERVER_PORT:-7850}"

# Start the Flask server
echo "Starting ToggleTalk Flask Server..."
echo "The server will be available at http://localhost:${SERVER_PORT:-7850}"
echo "Press Ctrl+C to stop the server"
$PYTHON_CMD ToggleTalkBotServer.py

# Deactivate virtual environment when done
echo "Deactivating virtual environment..."
deactivate

echo "Server stopped"
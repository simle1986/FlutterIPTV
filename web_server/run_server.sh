#!/bin/bash

echo "Starting Flutter IPTV Web Server..."
echo

# Check if Dart is installed
if ! command -v dart &> /dev/null; then
    echo "Error: Dart is not installed or not in PATH"
    echo "Please install Dart SDK first"
    exit 1
fi

# Get dependencies
echo "Installing dependencies..."
dart pub get

# Create data directory
mkdir -p data

# Start the server
echo
echo "Starting server on http://localhost:8080"
echo "Press Ctrl+C to stop the server"
echo
dart run bin/server.dart
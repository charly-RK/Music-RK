#!/bin/bash

echo "Starting backend setup..."

# Configure Tor to allow control port without auth for internal rotation
if [ -f /etc/tor/torrc ]; then
    echo "Configuring Tor control port..."
    # Ensure ControlPort and CookieAuthentication settings are set
    sed -i '/ControlPort/d' /etc/tor/torrc
    sed -i '/CookieAuthentication/d' /etc/tor/torrc
    echo "ControlPort 9051" >> /etc/tor/torrc
    echo "CookieAuthentication 0" >> /etc/tor/torrc
fi

# Start Tor service in the background
echo "Starting Tor service..."
tor &

# Wait for Tor to boot and establish proxy port
echo "Waiting for Tor proxy to establish connection..."
for i in {1..15}; do
    if curl --socks5-hostname 127.0.0.1:9050 -s https://www.google.com > /dev/null; then
        echo "Tor connection successfully established!"
        break
    fi
    echo "Tor starting... (attempt $i/15)"
    sleep 2
done

# Run the Flask application using Gunicorn
PORT=${PORT:-5001}
echo "Starting Gunicorn server on port $PORT..."
gunicorn -w 2 -b 0.0.0.0:$PORT --timeout 300 server:app

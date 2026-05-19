FROM python:3.10-slim

# Install system dependencies: ffmpeg, tor, curl, and procps
RUN apt-get update && apt-get install -y \
    ffmpeg \
    tor \
    curl \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements and install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application files
COPY . .

# Expose default port
EXPOSE 5001

# Copy start script, set permissions, and define entrypoint
RUN chmod +x start.sh

CMD ["./start.sh"]

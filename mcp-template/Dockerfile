FROM python:3.11-slim

WORKDIR /app

# Install system dependencies for database drivers
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc libpq-dev unixodbc-dev && \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY src/ ./src/

# Create buffer directory
RUN mkdir -p /app/buffer

CMD ["python", "src/main.py"]

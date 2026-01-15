# Usar la imagen de Python 3.11 slim
FROM python:3.11-slim

# Instalar dependencias del sistema incluyendo FFmpeg
RUN apt-get update && apt-get install -y \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Establecer el directorio de trabajo
WORKDIR /app

# Copiar primero el archivo de requerimientos para un mejor aprovechamiento de la caché
COPY requirements.txt .

# Instalar las dependencias de Python
RUN pip install --no-cache-dir -r requirements.txt

# Copiar el código de la aplicación
COPY . .

# Crear el directorio de descargas
RUN mkdir -p downloads

# Exponer el puerto (Railway sobrescribirá esto con la variable $PORT)
EXPOSE 8000

# Ejecutar la aplicación
CMD ["sh", "-c", "gunicorn server:app --bind 0.0.0.0:${PORT:-8000} --timeout 300 --workers 2"]

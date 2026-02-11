# Use Python 3.11 slim image
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies for OpenCV and PyTorch
RUN apt-get update && apt-get install -y \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY requirements.txt .

# Install Python dependencies
# First install PyTorch CPU-only with minimal dependencies (much smaller, ~200MB vs ~3GB with CUDA)
RUN pip install --no-cache-dir torch torchvision --index-url https://download.pytorch.org/whl/cpu

# Then install other dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Set environment variables for memory optimization
ENV OMP_NUM_THREADS=1
ENV MKL_NUM_THREADS=1
ENV NUMEXPR_NUM_THREADS=1
ENV PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:128

# Copy only necessary application files (exclude datasets, runs, etc.)
COPY api/ ./api/
COPY utils/ ./utils/
COPY models/ ./models/
COPY config.yaml ./
COPY __init__.py ./

# Expose port (Render/Fly.io will set PORT env var)
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD python -c "import requests; import os; requests.get(f'http://localhost:{os.getenv(\"PORT\", 8080)}/health')" || exit 1

# Run the application with dynamic PORT (Render sets this, defaults to 8080)
CMD ["sh", "-c", "uvicorn api.main:app --host 0.0.0.0 --port ${PORT:-8080}"]


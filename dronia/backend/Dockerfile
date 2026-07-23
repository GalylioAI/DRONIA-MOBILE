# DronIA Backend — Hugging Face Spaces (Docker SDK)
FROM python:3.11-slim

WORKDIR /app

# Dépendances système pour OpenCV / PyTorch
RUN apt-get update && apt-get install -y \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# PyTorch CPU-only (léger : ~200 Mo au lieu de ~3 Go avec CUDA)
COPY requirements.txt .
RUN pip install --no-cache-dir torch torchvision --index-url https://download.pytorch.org/whl/cpu
RUN pip install --no-cache-dir -r requirements.txt

# Optimisations mémoire
ENV OMP_NUM_THREADS=1
ENV MKL_NUM_THREADS=1
ENV NUMEXPR_NUM_THREADS=1
ENV PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:128

# Cache HuggingFace dans un dossier accessible en écriture (téléchargement des poids au démarrage)
ENV HF_HOME=/app/.cache/huggingface
ENV HF_HUB_CACHE=/app/.cache/huggingface

# Code applicatif (les .pth/.pt ne sont PAS copiés : téléchargés depuis HF Hub au boot)
COPY api/ ./api/
COPY utils/ ./utils/
COPY config.yaml ./
COPY __init__.py ./
RUN mkdir -p models .cache/huggingface

# HF Spaces exécute le conteneur sous un utilisateur non-root (uid 1000)
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

# HF Spaces impose le port 7860 (app_port dans le frontmatter du README)
EXPOSE 7860

CMD ["sh", "-c", "uvicorn api.main:app --host 0.0.0.0 --port ${PORT:-7860}"]

# ⚡ Speed Up Dataset Scanning/Loading

Ways to make the scanning phase faster using your computer resources.

## 🚀 Quick Fixes

### 1. **Increase Workers** (Faster Parallel Processing)

More workers = faster scanning. Edit `config.yaml`:

```yaml
training:
  workers: 8  # Increase this (try 8, 12, or 16)
```

**How it works:**
- Workers = number of CPU cores used for parallel image loading
- More workers = faster scanning, but uses more RAM
- **Recommended:** Number of CPU cores you have (check with `python -c "import os; print(os.cpu_count())"`)

### 2. **Use RAM Cache** (Faster Subsequent Runs)

Add cache parameter to training script. Already added! The script now uses:
- `cache='ram'` for CPU (loads images into RAM for faster access)

### 3. **Close Other Programs**

Free up CPU and RAM:
- Close browser tabs
- Close other applications
- Stop background processes

### 4. **Use SSD Instead of HDD**

If your dataset is on HDD, move it to SSD:
- **HDD:** ~100-150 MB/s read speed
- **SSD:** ~500-3000 MB/s read speed
- **Result:** 3-10x faster scanning!

### 5. **Reduce Dataset Size for Testing**

Scan a smaller subset first:

```bash
# Create 10% subset
python scripts/create_subset.py --source datasets/plantvillage_yolo --output datasets/plantvillage_small --ratio 0.1
```

## 📊 Speed Comparison

| Method | Speed Improvement | Resource Usage |
|--------|------------------|----------------|
| Increase workers (4→8) | **2x faster** | More CPU/RAM |
| Use SSD | **3-10x faster** | Same resources |
| RAM cache | **5-10x faster** (2nd run) | More RAM |
| Close programs | **10-20% faster** | Less competition |

## 🎯 Best Settings for Your PC

### Check Your CPU Cores

```python
import os
print(f"CPU cores: {os.cpu_count()}")
```

### Recommended Workers

- **4 cores:** `workers: 4`
- **8 cores:** `workers: 8`
- **16+ cores:** `workers: 12-16`

### Check Available RAM

```python
import psutil
ram_gb = psutil.virtual_memory().total / (1024**3)
print(f"Total RAM: {ram_gb:.1f} GB")
```

**For 18K images:**
- **8GB RAM:** `workers: 4`, `cache: False`
- **16GB RAM:** `workers: 8`, `cache: 'ram'`
- **32GB+ RAM:** `workers: 12-16`, `cache: 'ram'`

## ⚙️ Current Optimizations

The script now automatically:
- ✅ Uses optimal workers for CPU
- ✅ Uses RAM cache when possible
- ✅ Reduces batch size for CPU

## 💡 Pro Tips

1. **First run is always slowest** - It's building the cache
2. **Subsequent runs use cache** - Much faster!
3. **SSD makes huge difference** - Move dataset to SSD if possible
4. **More RAM = faster** - RAM cache loads everything into memory

## 🔧 Manual Tuning

Edit `backend/config.yaml`:

```yaml
training:
  workers: 8  # Adjust based on your CPU cores
```

Then restart training - scanning will be faster!


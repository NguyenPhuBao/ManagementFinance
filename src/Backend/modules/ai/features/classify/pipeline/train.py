"""
F012 — Transaction Classifier — Training Script

Usage: python train.py <data.csv> <output_dir>

Steps:
1. Load CSV (description, category columns)
2. Preprocess text (lowercase, remove punctuation, normalize Vietnamese)
3. Train fastText supervised model
4. Evaluate (cross-validation, accuracy, precision/recall per category)
5. Export model.bin + labels.json + metrics.json
"""
import sys
import json
import csv
import os

def load_data(csv_path):
    """Load training data from CSV. Returns list of (label, text) tuples."""
    data = []
    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            label = f"__label__{row['category']}"
            text = row['description'].strip()
            data.append((label, text))
    return data

def preprocess(text):
    """Clean and normalize text before training."""
    text = text.lower()
    # TODO: Add Vietnamese-specific preprocessing
    return text

def train(data_path, output_dir):
    # 1. Load data
    data = load_data(data_path)
    print(f"Loaded {len(data)} samples")

    # 2. Preprocess
    processed = [(label, preprocess(text)) for label, text in data]

    # 3. Write to fastText format
    train_path = os.path.join(output_dir, 'train.txt')
    with open(train_path, 'w', encoding='utf-8') as f:
        for label, text in processed:
            f.write(f"{label} {text}\n")

    # 4. Train fastText model
    # TODO: import fasttext; model = fasttext.train_supervised(...)

    # 5. Evaluate
    # TODO: Cross-validation, accuracy, F1-score

    # 6. Export model + metrics
    metrics = {"accuracy": 0.0, "f1_score": 0.0, "total_samples": len(data)}
    print(json.dumps(metrics))
    return metrics

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python train.py <data.csv> <output_dir>")
        sys.exit(1)
    train(sys.argv[1], sys.argv[2])

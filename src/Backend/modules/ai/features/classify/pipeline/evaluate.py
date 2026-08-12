"""
F012 — Transaction Classifier — Evaluation Script

Usage: python evaluate.py <model.bin> <test.csv>

Output: metrics.json with accuracy, precision, recall, F1 per category.
"""
import sys
import json

def evaluate(model_path, test_path):
    # TODO: Load model, run test set, compute metrics
    metrics = {
        "accuracy": 0.0,
        "f1_score": 0.0,
        "per_category": {}
    }
    print(json.dumps(metrics))
    return metrics

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python evaluate.py <model.bin> <test.csv>")
        sys.exit(1)
    evaluate(sys.argv[1], sys.argv[2])

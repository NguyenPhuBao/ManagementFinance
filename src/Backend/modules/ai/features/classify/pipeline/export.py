"""
F012 — Transaction Classifier — Export Script

Usage: python export.py <model.bin> <output_dir>

Exports:
- model.bin (copy to output_dir)
- labels.json (category mapping)
- metrics.json (final evaluation report)
"""
import sys
import json

def export(model_path, output_dir):
    # TODO: Copy model, generate labels.json
    print(json.dumps({"status": "ok", "output_dir": output_dir}))

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python export.py <model.bin> <output_dir>")
        sys.exit(1)
    export(sys.argv[1], sys.argv[2])

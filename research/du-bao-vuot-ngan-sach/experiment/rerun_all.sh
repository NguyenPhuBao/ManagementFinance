#!/bin/sh
# Rerun every experiment after a change in core.py (2026-11-09: wider lambda grid). ~25 min with three jobs in parallel.
cd "$(dirname "$0")"
python -u run_berka.py > run_berka.log 2>&1 &
python -u run_berka.py --nofixed > run_berka_nofixed.log 2>&1 &
python -u run_tabformer.py > run_tabformer.log 2>&1 &
python -u run_synthetic.py > run_synth.log 2>&1
wait
M3_ROWS=12000 KAPPAS=1.0 python -u run_berka.py > run_berka_rows12000.log 2>&1 &
python -u bootstrap.py > bootstrap.log 2>&1 &
python -u bootstrap.py tabformer > bootstrap_tabformer.log 2>&1
wait
echo ALL_DONE

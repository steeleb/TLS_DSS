# run using bash command: /Users/steeleb/miniconda3/envs/mod_nw/bin/python /Users/steeleb/Documents/GitHub/NASA-NW/modeling/get_forecasts/fetch_cbrfc_bakc2.py
# Optional --date YYYY-MM-DD argument; defaults to today.

#!/Users/steeleb/miniconda3/envs/mod_nw/bin/python

import requests
import pandas as pd
import argparse
import os
import sys
from datetime import date
from io import StringIO

# --- Constants -----------------------------------------------------------

CBRFC_URL  = "https://www.cbrfc.noaa.gov/product/hydrofcst/RVFCSV/BAKC2.fflw24.csv"
SITE_ID    = "BAKC2"

OUTPUT_DIR = os.environ.get(
    'CBRFC_OUTPUT_DIR',
    '/Users/steeleb/Documents/GitHub/NASA-NW/data/CBRFC_operational'
)


# --- Core function -------------------------------------------------------

def fetch_cbrfc_bakc2(run_date: str) -> None:
    output_path = os.path.join(OUTPUT_DIR, f"CBRFC_{SITE_ID}_{run_date}.csv")
    if os.path.exists(output_path):
        print(f"Skipping CBRFC {SITE_ID} {run_date} — file already exists.")
        return

    print(f"Fetching CBRFC {SITE_ID} forecast for {run_date}...")
    resp = requests.get(CBRFC_URL, timeout=30)
    resp.raise_for_status()

    lines = resp.text.splitlines()
    # Skip metadata header rows; find the line that starts the column names
    try:
        header_idx = next(i for i, ln in enumerate(lines) if ln.upper().startswith('DATE'))
    except StopIteration:
        print("Could not locate DATE header in CBRFC response.", file=sys.stderr)
        sys.exit(1)

    df = pd.read_csv(StringIO('\n'.join(lines[header_idx:])))
    df.columns = df.columns.str.strip()
    df['issued_date'] = run_date
    df['site_id']     = SITE_ID

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    df[['site_id', 'issued_date', 'DATE', 'TIME', 'FLOW']].to_csv(output_path, index=False)
    print(f"Saved {len(df)} rows → {output_path}")


# --- Entry point ---------------------------------------------------------

if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description=f"Fetch today's CBRFC deterministic forecast for {SITE_ID}."
    )
    parser.add_argument(
        '--date', default=None,
        help="Issued date as YYYY-MM-DD (default: today)."
    )
    args = parser.parse_args()

    run_date = args.date if args.date else date.today().strftime('%Y-%m-%d')
    fetch_cbrfc_bakc2(run_date)

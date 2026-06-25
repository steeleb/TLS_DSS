# Optional --date YYYY-MM-DD argument; defaults to today.

import requests
import pandas as pd
import argparse
import os
import sys
from datetime import date
from io import StringIO

# --- Constants -----------------------------------------------------------

SITES = {
    "BAKC2": "https://www.cbrfc.noaa.gov/product/hydrofcst/RVFCSV/BAKC2.fflw24.csv",
    "SMRC2": "https://www.cbrfc.noaa.gov/product/hydrofcst/RVFCSV/SMRC2.fflw24.csv",
}

OUTPUT_DIR = os.environ.get(
    'CBRFC_OUTPUT_DIR',
    'data_submodule/forecasts/CBRFC_operational'
)


# --- Core function -------------------------------------------------------

def fetch_cbrfc_site(site_id: str, url: str, run_date: str) -> None:
    output_path = os.path.join(OUTPUT_DIR, f"CBRFC_{site_id}_{run_date}.csv")
    if os.path.exists(output_path):
        print(f"Skipping CBRFC {site_id} {run_date} — file already exists.")
        return

    print(f"Fetching CBRFC {site_id} forecast for {run_date}...")
    resp = requests.get(url, timeout=30)
    resp.raise_for_status()

    lines = resp.text.splitlines()
    # Skip metadata header rows; find the line that starts the column names
    try:
        header_idx = next(i for i, ln in enumerate(lines) if ln.upper().startswith('DATE'))
    except StopIteration:
        print(f"Could not locate DATE header in CBRFC response for {site_id}.", file=sys.stderr)
        sys.exit(1)

    df = pd.read_csv(StringIO('\n'.join(lines[header_idx:])))
    df.columns = df.columns.str.strip()
    df['issued_date'] = run_date
    df['site_id']     = site_id

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    df[['site_id', 'issued_date', 'DATE', 'TIME', 'FLOW']].to_csv(output_path, index=False)
    print(f"Saved {len(df)} rows → {output_path}")


# --- Entry point ---------------------------------------------------------

if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description="Fetch today's CBRFC deterministic forecasts for all configured sites."
    )
    parser.add_argument(
        '--date', default=None,
        help="Issued date as YYYY-MM-DD (default: today)."
    )
    args = parser.parse_args()

    run_date = args.date if args.date else date.today().strftime('%Y-%m-%d')
    for site_id, url in SITES.items():
        fetch_cbrfc_site(site_id, url, run_date)

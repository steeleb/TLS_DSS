# Optional --date YYYY-MM-DD argument; defaults to today.

from herbie import FastHerbie
import pandas as pd
import xarray as xr
import argparse
import os
import sys
import time
from datetime import date

xr.set_options(use_new_combine_kwarg_defaults=True)

# --- Constants -----------------------------------------------------------

SMR_LAT =  40.22
SMR_LON = -105.85

INIT_HOUR = 6    # 06:00 UTC initialization
PRODUCT   = 'atmos.25'

# One noon-local valid time per forecast day (fxx = 12, 36, … 156)
# Initialized at 06:00 UTC → valid 18:00 UTC ≈ noon MDT for each day 1-7
FXX_LIST = [12 + 24 * (h - 1) for h in range(1, 8)]  # [12, 36, 60, 84, 108, 132, 156]

# All 31 ensemble members (control + 30 perturbations)
MEMBERS = ['c00'] + [f'p{i:02d}' for i in range(1, 31)]

# One search string per variable to avoid coordinate conflicts across levels
SEARCH_TEMP = ":TMP:2 m above ground:"
SEARCH_UGRD = ":UGRD:10 m above ground:"
SEARCH_VGRD = ":VGRD:10 m above ground:"
SEARCH_RAD  = ":DSWRF:surface:"

OUTPUT_DIR = os.environ.get(
    'GEFS_OUTPUT_DIR',
    'data_submodule/forecasts/GEFS_operational'
)


# --- Core functions ------------------------------------------------------

def fetch_member(dt_str, member):
    """Download the 7 noon-horizon steps for one ensemble member.

    Uses FastHerbie so all 7 fxx files are fetched concurrently (threaded I/O,
    no extra CPU cores). Returns a list of row dicts ready for DataFrame assembly.
    """
    FH = FastHerbie([dt_str], model='gefs', product=PRODUCT,
                    member=member, fxx=FXX_LIST, verbose=False)

    # One xarray call per variable; remove_grib=False keeps files on disk
    # so subsequent calls re-use the same downloads
    sel_kw = dict(latitude=SMR_LAT, longitude=SMR_LON % 360, method='nearest')

    ds_t2m  = FH.xarray(SEARCH_TEMP, remove_grib=False).sel(**sel_kw)
    ds_ugrd = FH.xarray(SEARCH_UGRD, remove_grib=False).sel(**sel_kw)
    ds_vgrd = FH.xarray(SEARCH_VGRD, remove_grib=False).sel(**sel_kw)
    ds_rad  = FH.xarray(SEARCH_RAD,  remove_grib=False).sel(**sel_kw)

    # squeeze drops any size-1 dims (e.g. time) regardless of whether they exist
    t2m_steps  = ds_t2m.squeeze()
    ugrd_steps = ds_ugrd.squeeze()
    vgrd_steps = ds_vgrd.squeeze()
    rad_steps  = ds_rad.squeeze()

    records = []
    for fxx in FXX_LIST:
        step = pd.Timedelta(hours=fxx)
        records.append({
            'member':  member,
            'horizon': fxx,
            't2m':     float(t2m_steps.sel(step=step)['t2m']),
            'u10':     float(ugrd_steps.sel(step=step)['u10']),
            'v10':     float(vgrd_steps.sel(step=step)['v10']),
            'sdswrf':  float(rad_steps.sel(step=step)['sdswrf']),
        })
    return records


def fetch_smr_gefs(run_date: str, retries: int = 3, retry_delay: int = 30) -> None:
    output_path = os.path.join(OUTPUT_DIR, f"GEFS_p25_{run_date}.csv")
    if os.path.exists(output_path):
        print(f"Skipping {run_date} — file already exists.")
        return

    dt_str = f"{run_date} {INIT_HOUR:02d}:00"
    print(f"Fetching GEFS ({len(MEMBERS)} members × {len(FXX_LIST)} steps) for {dt_str}...")

    for attempt in range(retries):
        try:
            all_records = []
            for member in MEMBERS:
                print(f"  {member}...", flush=True)
                all_records.extend(fetch_member(dt_str, member))

            df = pd.DataFrame(all_records)
            df['init_date'] = dt_str
            df[['u10', 'v10', 't2m', 'sdswrf', 'init_date', 'horizon', 'member']].to_csv(
                output_path, index=False
            )
            print(f"Saved {len(df)} rows → {output_path}")
            return

        except Exception as e:
            if attempt < retries - 1:
                print(f"Attempt {attempt + 1} failed: {e}. Retrying in {retry_delay}s...")
                time.sleep(retry_delay)
            else:
                print(f"All {retries} attempts failed for {run_date}: {e}", file=sys.stderr)
                sys.exit(1)


# --- Entry point ---------------------------------------------------------

if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description="Fetch today's GEFS ensemble forecast for SMR (7-day horizon, all members)."
    )
    parser.add_argument(
        '--date', default=None,
        help="Initialization date as YYYY-MM-DD (default: today)."
    )
    args = parser.parse_args()

    run_date = args.date if args.date else date.today().strftime('%Y-%m-%d')
    fetch_smr_gefs(run_date)

"""
SMR Farr Pump Scenario Operational Forecast — Streamlit App

Run with:
    `streamlit run streamlit_app/app.py`
"""
import io
import json
import time
import warnings
warnings.filterwarnings('ignore')
from pathlib import Path

import joblib
import matplotlib
matplotlib.use('Agg')
import matplotlib.dates as mdates
import matplotlib.pyplot as plt
from matplotlib.transforms import blended_transform_factory
import numpy as np
import pandas as pd
import streamlit as st
from tensorflow import keras

# ── Page config ───────────────────────────────────────────────────────────────
st.set_page_config(
    page_title="SMR Farr Pump Scenario Forecast",
    layout="wide",
)

# ── Constants ─────────────────────────────────────────────────────────────────
BASE_DIR        = Path(__file__).parent
REPO_DIR        = BASE_DIR.parent
MODEL_DIR       = (REPO_DIR / 'model_submodule' / 'model_dev' / 'lagged_temp').resolve()
GEFS_DIR        = (REPO_DIR / 'data_submodule' / 'forecasts' / 'GEFS_operational').resolve()
CBRFC_DIR       = (REPO_DIR / 'data_submodule' / 'forecasts' / 'CBRFC_operational').resolve()
RAW_DIR         = (REPO_DIR / 'data_submodule' / 'raw_data' / 'target_output').resolve()
FLOW_DIR        = (REPO_DIR / 'data_submodule' / 'streamflow').resolve()

TARGETS         = ['mean_1m_temp_degC', 'mean_0_5m_temp_degC']
HORIZONS        = list(range(1, 8))
NOON_HORIZONS   = {h: 12 + (h - 1) * 24 for h in HORIZONS}
NEEDED_HORIZONS = set(NOON_HORIZONS.values())
GEFS_VARS       = ['gefs_temp_degC', 'gefs_wind_mps', 'gefs_sol_rad_Wpm2']

# Okabe-Ito colorblind-safe palette (Nature Methods 2011)
SCENARIO_COLORS       = ['#E69F00', '#56B4E9', '#009E73', '#CC79A7']
SCENARIO_COLORS_LIGHT = ['#F4CC7E', '#ABD9F4', '#80CEBC', '#E5BCD4']  # pastel pairs for 0–5m depth
BASELINE_COLOR        = '#888888'
DEFAULT_NAMES   = ['Scenario A', 'Scenario B', 'Scenario C', 'Scenario D']


@st.dialog("How to Use This App", width="large")
def _show_help():
    st.markdown((BASE_DIR / "how_to_use.md").read_text())


# ── Cached loaders ────────────────────────────────────────────────────────────

@st.cache_resource
def load_models():
    with open(MODEL_DIR / 'feature_cols.json') as f:
        feature_cols = json.load(f)
    cv_models  = [keras.models.load_model(MODEL_DIR / f'model_fold{k}.keras') for k in range(1, 6)]
    cv_scalers = [joblib.load(MODEL_DIR / f'scaler_fold{k}.pkl')              for k in range(1, 6)]
    return cv_models, cv_scalers, feature_cols


@st.cache_data(ttl=3600)
def load_data():
    # File names:
    abt = pd.read_csv(RAW_DIR / 'adams_tunnel_data.csv',         parse_dates=['date'])
    ei  = pd.read_csv(RAW_DIR / 'grand_east_inlet_daily.csv',    parse_dates=['date'])
    ni  = pd.read_csv(RAW_DIR / 'grand_north_inlet_daily.csv',   parse_dates=['date'])

    abt_dict = dict(zip(abt['date'], abt['value']))
    ei_dict  = dict(zip(ei['date'],  ei['q_cfs']))
    ni_dict  = dict(zip(ni['date'],  ni['q_cfs']))

    # CBRFC: per-day files (CBRFC_BAKC2_YYYY-MM-DD.csv)
    cbrfc_files = sorted(CBRFC_DIR.glob('CBRFC_BAKC2_*.csv'))
    if cbrfc_files:
        frames = []
        for f in cbrfc_files:
            df = pd.read_csv(f)
            df['issue_date'] = pd.to_datetime(df['issued_date'])
            df['date']       = pd.to_datetime(df['DATE'], format='mixed')
            df['flow_cfs']   = df['FLOW']
            frames.append(df[['issue_date', 'date', 'flow_cfs']])
        bakc2_df = pd.concat(frames, ignore_index=True)
    else:
        bakc2_df = pd.DataFrame(columns=['issue_date', 'date', 'flow_cfs'])

    coeff_nf = pd.read_csv(FLOW_DIR / 'northfork_q_handoff_COLBAKCO_COLGRAND.csv').set_index('month')
    coeff_ei = pd.read_csv(FLOW_DIR / 'northfork_q_handoff_COLBAKCO_EASINLET.csv').set_index('month')
    coeff_ni = pd.read_csv(FLOW_DIR / 'northfork_q_handoff_COLBAKCO_NORINLET.csv').set_index('month')

    return abt_dict, ei_dict, ni_dict, bakc2_df, coeff_nf, coeff_ei, coeff_ni


@st.cache_data(ttl=3600)
def load_realtime_state(init_date):
    """Read raw TLS_DSS files to build lag features and a recent-obs DataFrame.

    Returns:
        lag_state (pd.Series): model input lag features keyed by column name
        obs_df    (pd.DataFrame): recent observations indexed by date for plotting
    """
    ref      = pd.Timestamp(init_date) - pd.Timedelta(days=1)
    lookback = 10  # days of history to retain for plotting

    # ── North Fork flow (northfork_daily.csv: datetime, value, date) ──────────
    nf_raw = pd.read_csv(RAW_DIR / 'northfork_daily.csv', parse_dates=['date'])
    nf_ser = nf_raw.set_index('date')['value'].rename('nf_flow_cfs')

    # ── Pump flow (granby_daily_pump_data.csv: datetime, value, date) ─────────
    pump_raw = pd.read_csv(RAW_DIR / 'granby_daily_pump_data.csv', parse_dates=['date'])
    pump_ser = pump_raw.set_index('date')['value'].rename('pump_flow_cfs')

    # ── Chipmunk flow (chipmunk.csv: long format, filter parameter == 'flow_cfs') ─
    chip_raw = pd.read_csv(RAW_DIR / 'chipmunk.csv', parse_dates=['dateTime'])
    chip_raw['date'] = chip_raw['dateTime'].dt.normalize()
    chip_ser = (chip_raw[chip_raw['parameter'] == 'flow_cfs']
                .groupby('date')['value'].mean()
                .rename('chipmunk_flow_cfs'))

    # ── Buoy temperature (SM_MID_L1.csv: sub-hourly, depth_m, temp_C, flag_temp) ─
    buoy_raw = pd.read_csv(RAW_DIR / 'SM_MID_L1.csv', parse_dates=['dateTime'])
    buoy_raw = buoy_raw[buoy_raw['flag_temp'].isna()]
    buoy_raw['date'] = buoy_raw['dateTime'].dt.normalize()
    temp_1m_ser   = buoy_raw[buoy_raw['depth_m'] <= 1.0].groupby('date')['temp_C'].mean()
    temp_0_5m_ser = buoy_raw[buoy_raw['depth_m'] <= 5.0].groupby('date')['temp_C'].mean()

    # ── Past GEFS control-member noon forecasts for "observed" ───────────────────────────────
    gefs_records = {}
    cutoff = ref - pd.Timedelta(days=lookback)
    for gf in sorted(GEFS_DIR.glob('GEFS_p25_*.csv')):
        gd = pd.Timestamp(gf.stem.replace('GEFS_p25_', ''))
        if gd < cutoff:
            continue
        gk  = pd.read_csv(gf)
        row = gk[(gk['member'] == 'c00') & (gk['horizon'] == 12)]
        if len(row) == 1:
            r = row.iloc[0]
            gefs_records[gd] = dict(
                gefs_temp_degC    = float(r['t2m']) - 273.15,
                gefs_wind_mps     = float(np.sqrt(r['u10'] ** 2 + r['v10'] ** 2)),
                gefs_sol_rad_Wpm2 = float(r['sdswrf']),
            )
    gefs_df = pd.DataFrame.from_dict(gefs_records, orient='index') if gefs_records else pd.DataFrame()

    # ── obs_df: combined DataFrame for plotting ───────────────────────────────
    for _s in (nf_ser, pump_ser, chip_ser, temp_1m_ser, temp_0_5m_ser):
        if _s.index.tz is not None:
            _s.index = _s.index.tz_convert(None)
    obs_df = pd.concat([nf_ser, pump_ser, chip_ser,
                        temp_1m_ser.rename('temp_1m_degC'),
                        temp_0_5m_ser.rename('temp_0_5m_degC')], axis=1)
    if not gefs_df.empty:
        obs_df = obs_df.join(gefs_df, how='outer')
    else:
        for col in ['gefs_temp_degC', 'gefs_wind_mps', 'gefs_sol_rad_Wpm2']:
            obs_df[col] = np.nan

    # ── lag_state: Series of model input feature names ────────────────────────
    # Forward-fill pump so that explicit NA rows in the source file don't
    # propagate NaN into model features; obs_df retains original gaps for plotting.
    pump_ser_ff = pump_ser.ffill()

    state = {}
    for k in range(1, 6):
        d = ref - pd.Timedelta(days=k - 1)
        state[f'nf_flow_cfs_lag{k}']        = nf_ser.get(d, np.nan)
        state[f'pump_flow_cfs_lag{k}']      = pump_ser_ff.get(d, np.nan)
        state[f'chipmunk_flow_cfs_lag{k}']  = chip_ser.get(d, np.nan)
        rec = gefs_records.get(d, {})
        state[f'gefs_temp_degC_lag{k}']     = rec.get('gefs_temp_degC',    np.nan)
        state[f'gefs_wind_mps_lag{k}']      = rec.get('gefs_wind_mps',     np.nan)
        state[f'gefs_sol_rad_Wpm2_lag{k}']  = rec.get('gefs_sol_rad_Wpm2', np.nan)

    for k in [1, 2]:
        d = ref - pd.Timedelta(days=k - 1)
        state[f'mean_1m_temp_degC_lag{k}']   = temp_1m_ser.get(d, np.nan)
        state[f'mean_0_5m_temp_degC_lag{k}']  = temp_0_5m_ser.get(d, np.nan)

    return pd.Series(state), obs_df


# ── Core model logic  ───────────────────────────────

def _apply_reg(bakc2_cfs, coeff_df, month_abbrev):
    """Apply monthly linear regression: flow = intercept + slope * bakc2_cfs."""
    row = coeff_df.loc[month_abbrev]
    return max(0.0, float(row['intercept'] + row['slope'] * bakc2_cfs))


def get_bakc2_flow_estimates(init_date, bakc2_df, coeff_nf, coeff_ei, coeff_ni):
    """Return per-horizon dicts of estimated NF, EI, NI flows from BAKC2 forecasts.

    For each horizon h=1..7, looks for a BAKC2 forecast issued on init_date
    (or init_date-1 as fallback for h=1 where same-day coverage is absent).
    Returns dicts keyed by h; value is float or None (caller uses persistence).
    """
    nf_est = {}
    ei_est = {}
    ni_est = {}
    prev_day = init_date - pd.Timedelta(days=1)

    issued_today = bakc2_df[bakc2_df['issue_date'] == init_date]
    issued_prev  = bakc2_df[bakc2_df['issue_date'] == prev_day]

    for h in HORIZONS:
        target_date = init_date + pd.Timedelta(days=h - 1)

        row = issued_today[issued_today['date'] == target_date]
        if row.empty:
            row = issued_prev[issued_prev['date'] == target_date]

        if row.empty:
            nf_est[h] = ei_est[h] = ni_est[h] = None
            continue

        bakc2_cfs    = float(row.iloc[0]['flow_cfs'])
        month_abbrev = target_date.strftime('%b')
        nf_est[h] = _apply_reg(bakc2_cfs, coeff_nf, month_abbrev)
        ei_est[h] = _apply_reg(bakc2_cfs, coeff_ei, month_abbrev)
        ni_est[h] = _apply_reg(bakc2_cfs, coeff_ni, month_abbrev)

    return nf_est, ei_est, ni_est


def build_feature_vector(h, member, gefs_d, target_row, target_date, rolled_preds,
                          nf_flows, ei_flows, ni_flows,
                          abt_dict, feature_cols,
                          pump_schedule=None, abt_schedule=None):
    feat = {}

    gefs0 = gefs_d.loc[(member, NOON_HORIZONS[h])]
    feat['gefs_temp_degC']    = gefs0['gefs_temp_degC']
    feat['gefs_wind_mps']     = gefs0['gefs_wind_mps']
    feat['gefs_sol_rad_Wpm2'] = gefs0['gefs_sol_rad_Wpm2']
    feat['nf_flow_cfs']       = nf_flows[h]

    abt_h = abt_schedule[h - 1] if abt_schedule is not None else abt_dict.get(target_date, np.nan)
    feat['chipmunk_flow_cfs'] = ei_flows[h] + ni_flows[h] - abt_h

    # k_obs: the target_row lag index that corresponds to lag k from target_date.
    # target_date = init_date + (h-1), so lag k from target_date lands at
    # init_date - (k - h + 1), which is target_row lag (k - h + 1).
    # This shift only applies when k >= h (observable); when k < h the date is
    # in the future and we use a model prediction instead.

    for k in [1, 2]:
        for ti, t in enumerate(TARGETS):
            prior_h = h - k
            if prior_h >= 1 and prior_h in rolled_preds:
                feat[f'{t}_lag{k}'] = rolled_preds[prior_h][ti]
            else:
                k_obs = k - (h - 1)
                feat[f'{t}_lag{k}'] = target_row[f'{t}_lag{k_obs}']

    for k in range(1, 6):
        lag_date = target_date - pd.Timedelta(days=k)
        k_obs    = k - (h - 1)  # target_row lag index when k >= h

        feat[f'nf_flow_cfs_lag{k}'] = (
            nf_flows[h - k] if k <= h - 1 else target_row[f'nf_flow_cfs_lag{k_obs}']
        )

        if pump_schedule is not None and k <= h - 1:
            feat[f'pump_flow_cfs_lag{k}'] = pump_schedule[h - k - 1]
        else:
            feat[f'pump_flow_cfs_lag{k}'] = target_row[f'pump_flow_cfs_lag{k_obs}']

        if k <= h - 1:
            abt_k = abt_schedule[h - k - 1] if abt_schedule is not None else abt_dict.get(lag_date, np.nan)
            feat[f'chipmunk_flow_cfs_lag{k}'] = ei_flows[h - k] + ni_flows[h - k] - abt_k
        else:
            feat[f'chipmunk_flow_cfs_lag{k}'] = target_row[f'chipmunk_flow_cfs_lag{k_obs}']

    for k in range(1, 6):
        if k < h:
            h_k = 12 + (h - 1 - k) * 24
            gk  = gefs_d.loc[(member, h_k)]
            feat[f'gefs_temp_degC_lag{k}']    = gk['gefs_temp_degC']
            feat[f'gefs_wind_mps_lag{k}']     = gk['gefs_wind_mps']
            feat[f'gefs_sol_rad_Wpm2_lag{k}'] = gk['gefs_sol_rad_Wpm2']
        else:
            k_obs = k - (h - 1)
            feat[f'gefs_temp_degC_lag{k}']    = target_row[f'gefs_temp_degC_lag{k_obs}']
            feat[f'gefs_wind_mps_lag{k}']     = target_row[f'gefs_wind_mps_lag{k_obs}']
            feat[f'gefs_sol_rad_Wpm2_lag{k}'] = target_row[f'gefs_sol_rad_Wpm2_lag{k_obs}']

    return np.array([feat[col] for col in feature_cols], dtype=float)


def run_scenario(scenario_name, pump_schedule, abt_schedule,
                 init_date, gefs_d, realtime_state, abt_dict,
                 cv_models, cv_scalers, feature_cols,
                 nf_flows, ei_flows, ni_flows):
    """Run forecast for one scenario. Returns a list of record dicts."""
    members = sorted(gefs_d.index.get_level_values('member').unique())
    rolled  = {m: {} for m in members}
    records = []

    for h in HORIZONS:
        target_date = init_date + pd.Timedelta(days=h - 1)
        target_row  = realtime_state  # lag features from raw data at init time

        valid_members, feats = [], []
        for m in members:
            if (m, NOON_HORIZONS[h]) not in gefs_d.index:
                continue
            valid_members.append(m)
            feats.append(build_feature_vector(
                h, m, gefs_d, target_row, target_date, rolled[m],
                nf_flows, ei_flows, ni_flows,
                abt_dict, feature_cols,
                pump_schedule=pump_schedule,
                abt_schedule=abt_schedule,
            ))

        if not valid_members:
            continue

        X           = np.stack(feats)
        preds_folds = [model(scaler.transform(X), training=False).numpy()
                       for model, scaler in zip(cv_models, cv_scalers)]
        ens = np.mean(preds_folds, axis=0)

        for i_m, m in enumerate(valid_members):
            rolled[m][h] = ens[i_m]
            records.append(dict(
                target_date=target_date, horizon=h, member=m,
                scenario=scenario_name,
                pred_1m=ens[i_m, 0], pred_0_5m=ens[i_m, 1],
            ))

    return records


def make_met_flow_figure(gefs_d, obs_df, abt_dict, ei_dict, ni_dict,
                         nf_flows, ei_flows, ni_flows,
                         pump_schedules, abt_schedules,
                         persist_pump_sch, persist_abt_sch,
                         scenario_names, init_date,
                         is_retrospective=False):
    obs_start = init_date - pd.Timedelta(days=7)
    obs_end   = init_date - pd.Timedelta(days=1)
    obs_dates = pd.date_range(obs_start, obs_end, freq='D')

    pump_obs = [float(obs_df['pump_flow_cfs'].get(d, np.nan))    for d in obs_dates]
    abt_obs  = [float(abt_dict.get(d, np.nan))                   for d in obs_dates]
    nf_obs   = [float(obs_df['nf_flow_cfs'].get(d, np.nan))      for d in obs_dates]
    ei_obs   = [float(ei_dict.get(d, np.nan))                    for d in obs_dates]
    ni_obs   = [float(ni_dict.get(d, np.nan))                    for d in obs_dates]
    temp_obs = [float(obs_df['gefs_temp_degC'].get(d, np.nan))   for d in obs_dates]
    sol_obs  = [float(obs_df['gefs_sol_rad_Wpm2'].get(d, np.nan)) for d in obs_dates]
    wind_obs = [float(obs_df['gefs_wind_mps'].get(d, np.nan))    for d in obs_dates]

    fc_dates = pd.DatetimeIndex([init_date + pd.Timedelta(days=h - 1) for h in HORIZONS])

    fc_temp_mean, fc_temp_std = [], []
    fc_sol_mean,  fc_sol_std  = [], []
    fc_wind_mean, fc_wind_std = [], []
    for h in HORIZONS:
        sub = gefs_d.xs(NOON_HORIZONS[h], level='horizon')
        fc_temp_mean.append(sub['gefs_temp_degC'].mean());    fc_temp_std.append(sub['gefs_temp_degC'].std())
        fc_sol_mean.append(sub['gefs_sol_rad_Wpm2'].mean());  fc_sol_std.append(sub['gefs_sol_rad_Wpm2'].std())
        fc_wind_mean.append(sub['gefs_wind_mps'].mean());     fc_wind_std.append(sub['gefs_wind_mps'].std())

    nf_fc = [nf_flows[h] for h in HORIZONS]
    ei_fc = [ei_flows[h] for h in HORIZONS]
    ni_fc = [ni_flows[h] for h in HORIZONS]

    fig, axes = plt.subplots(5, 1, figsize=(11, 18), sharex=True)
    vline_kw = dict(color='#444', linestyle='--', linewidth=1, alpha=0.6)
    vline_x  = init_date - pd.Timedelta(hours=12)

    # ── Panel 1: Pump & ABT deliveries (bar chart) ───────────────────────────
    ax = axes[0]
    obs_nums = mdates.date2num([pd.Timestamp(d) for d in obs_dates])
    fc_nums  = mdates.date2num([pd.Timestamp(d) for d in fc_dates])

    bar_w_obs = 0.7 / 2
    n_bars_fc = (len(pump_schedules) + 1) * 2
    bar_w_fc  = 0.7 / n_bars_fc

    ax.bar(obs_nums - bar_w_obs / 2, pump_obs, width=bar_w_obs,
           color='#222222', alpha=0.8, hatch='///', edgecolor='white', label='Farr Pump observed')
    ax.bar(obs_nums + bar_w_obs / 2, abt_obs,  width=bar_w_obs,
           color='#222222', alpha=0.8, edgecolor='white', label='Adams Tunnel observed')

    bar_idx = 0
    pump_off = (2 * bar_idx     - (n_bars_fc - 1) / 2) * bar_w_fc
    abt_off  = (2 * bar_idx + 1 - (n_bars_fc - 1) / 2) * bar_w_fc
    ax.bar(fc_nums + pump_off, persist_pump_sch, width=bar_w_fc,
           color=BASELINE_COLOR, alpha=0.6, hatch='///', edgecolor='white', label='Persistence – Farr Pump')
    ax.bar(fc_nums + abt_off,  persist_abt_sch,  width=bar_w_fc,
           color=BASELINE_COLOR, alpha=0.6, label='Persistence – AT')
    bar_idx += 1

    for i, (name, p_sch, a_sch) in enumerate(zip(scenario_names, pump_schedules, abt_schedules)):
        sc_color = SCENARIO_COLORS[i % len(SCENARIO_COLORS)]
        pump_off = (2 * bar_idx     - (n_bars_fc - 1) / 2) * bar_w_fc
        abt_off  = (2 * bar_idx + 1 - (n_bars_fc - 1) / 2) * bar_w_fc
        if is_retrospective and i == 0:
            obs_mask = [
                pd.notna(obs_df['pump_flow_cfs'].get(pd.Timestamp(td), np.nan) if obs_df is not None else np.nan) or
                pd.notna(abt_dict.get(pd.Timestamp(td), np.nan))
                for td in fc_dates
            ]
            p_gray  = [p if m else np.nan for p, m in zip(p_sch, obs_mask)]
            a_gray  = [a if m else np.nan for a, m in zip(a_sch, obs_mask)]
            p_free  = [p if not m else np.nan for p, m in zip(p_sch, obs_mask)]
            a_free  = [a if not m else np.nan for a, m in zip(a_sch, obs_mask)]
            ax.bar(fc_nums + pump_off, p_gray, width=bar_w_fc,
                   color='#222222', alpha=0.8, hatch='///', edgecolor='white', label=f'{name} – Farr Pump')
            ax.bar(fc_nums + abt_off,  a_gray, width=bar_w_fc,
                   color='#222222', alpha=0.8, label=f'{name} – AT')
            ax.bar(fc_nums + pump_off, p_free, width=bar_w_fc,
                   color=sc_color, alpha=0.8, hatch='///', edgecolor='white')
            ax.bar(fc_nums + abt_off,  a_free, width=bar_w_fc,
                   color=sc_color, alpha=0.8)
        else:
            ax.bar(fc_nums + pump_off, p_sch, width=bar_w_fc,
                   color=sc_color, alpha=0.8, hatch='///', edgecolor='white', label=f'{name} – Farr Pump')
            ax.bar(fc_nums + abt_off,  a_sch, width=bar_w_fc,
                   color=sc_color, alpha=0.8, label=f'{name} – AT')
        bar_idx += 1

    ax.xaxis_date()
    ax.axvline(vline_x, **vline_kw)
    _trans = blended_transform_factory(ax.transData, ax.transAxes)
    ax.text(mdates.date2num(vline_x) + 0.17, 0.97, 'forecast period →',
            transform=_trans, fontsize=8, va='top', ha='left', color='#555')
    ax.set_ylabel('Delivery (cfs)')
    ax.legend(fontsize=8, ncol=2)
    ax.grid(True, alpha=0.3, axis='y')

    # ── Panel 2: NF / EI / NI inflows ────────────────────────────────────────
    ax = axes[1]
    for _lbl, _color, _obs_vals, _fc_vals in [
        ('NF', '#009E73', nf_obs, nf_fc),
        ('EI', '#D55E00', ei_obs, ei_fc),
        ('NI', '#CC79A7', ni_obs, ni_fc),
    ]:
        ax.plot(obs_dates, _obs_vals, color=_color, linewidth=2, label=_lbl)
        ax.plot([obs_dates[-1], *fc_dates], [_obs_vals[-1], *_fc_vals],
                color=_color, linewidth=2, linestyle='--')
    ax.axvline(vline_x, **vline_kw)
    ax.set_ylabel('Flow (cfs)')
    ax.legend(fontsize=8, ncol=2)
    ax.grid(True, alpha=0.3)

    # ── Panels 3–5: Meteorological inputs ────────────────────────────────────
    def _met_panel(ax, obs_vals, fc_mean, fc_std, ylabel, color):
        arr_m = np.array(fc_mean); arr_s = np.array(fc_std)
        ax.plot(obs_dates, obs_vals, color=color, linewidth=2, label='GEFS (mean)')
        ax.plot([obs_dates[-1], *fc_dates], [obs_vals[-1], *arr_m],
                color=color, linewidth=2, linestyle='--')
        ax.fill_between(fc_dates, arr_m - arr_s, arr_m + arr_s, color=color, alpha=0.2, label='±1 std (forecast)')
        ax.axvline(vline_x, **vline_kw)
        ax.set_ylabel(ylabel)
        ax.legend(fontsize=8)
        ax.grid(True, alpha=0.3)

    _met_panel(axes[2], temp_obs, fc_temp_mean, fc_temp_std, 'Air temp (°C)',      '#F0E442')
    _met_panel(axes[3], sol_obs,  fc_sol_mean,  fc_sol_std,  'Solar rad (W m⁻²)', '#CC79A7')
    _met_panel(axes[4], wind_obs, fc_wind_mean, fc_wind_std, 'Wind speed (m s⁻¹)','#56B4E9')

    axes[4].set_xlabel('Date')
    axes[-1].xaxis.set_major_locator(mdates.DayLocator())
    axes[-1].xaxis.set_major_formatter(mdates.DateFormatter('%b %-d'))
    plt.setp(axes[-1].get_xticklabels(), rotation=45, ha='right')
    fig.tight_layout()
    return fig


def make_unified_figure(forecast_df, obs_df, abt_dict, init_date, scenario_names,
                        pump_schedules, abt_schedules,
                        persist_pump_sch=None, persist_abt_sch=None,
                        is_retrospective=False):
    today = pd.Timestamp.today().normalize()

    obs_end   = init_date - pd.Timedelta(days=1)
    obs_start = obs_end - pd.Timedelta(days=6)
    obs_dates = pd.date_range(obs_start, obs_end, freq='D')

    target_dates = sorted(forecast_df['target_date'].unique())
    all_scenarios = forecast_df['scenario'].unique()

    color_map = {}
    for i, name in enumerate(scenario_names):
        color_map[name] = SCENARIO_COLORS[i % len(SCENARIO_COLORS)]
    if 'Persistence' in all_scenarios:
        color_map['Persistence'] = BASELINE_COLOR

    color_map_light = {}
    for i, name in enumerate(scenario_names):
        color_map_light[name] = SCENARIO_COLORS_LIGHT[i % len(SCENARIO_COLORS_LIGHT)]
    if 'Persistence' in all_scenarios:
        color_map_light['Persistence'] = '#BBBBBB'

    fig, axes = plt.subplots(2, 1, figsize=(12, 8), sharex=True,
                             gridspec_kw={'height_ratios': [3, 1.5]})
    vline_kw = dict(color='#444', linestyle='--', linewidth=1, alpha=0.6)
    vline_x  = init_date - pd.Timedelta(hours=12)

    ax = axes[0]
    full_range = pd.date_range(obs_start, pd.Timestamp(target_dates[-1]), freq='D')
    draw_order = [s for s in all_scenarios if s != 'Persistence']
    if 'Persistence' in all_scenarios:
        draw_order = ['Persistence'] + draw_order

    for pred_col, obs_col, depth_label, lw, obs_color, cmap in [
        ('pred_1m',   'temp_1m_degC',   '1m',   2.0, 'black',   color_map),
        ('pred_0_5m', 'temp_0_5m_degC', '0–5m', 1.5, '#444444', color_map_light),
    ]:
        obs_temp = pd.Series(dtype=float)
        if obs_df is not None and obs_col in obs_df.columns:
            obs_temp = obs_df[obs_col].reindex(full_range).dropna()
            obs_temp = obs_temp[obs_temp.index < today]
            if not obs_temp.empty:
                ax.plot(obs_temp.index, obs_temp.values,
                        color=obs_color, linewidth=lw, marker='o', markersize=4,
                        label=f'Observed ({depth_label})', zorder=5)

        last_obs_date = obs_temp.index[-1] if not obs_temp.empty else None
        last_obs_val  = float(obs_temp.iloc[-1]) if not obs_temp.empty else np.nan

        for scenario in draw_order:
            sub = forecast_df[forecast_df['scenario'] == scenario]
            agg = sub.groupby('target_date')[pred_col].agg(['mean', 'std']).reindex(target_dates)
            mu, sig = agg['mean'], agg['std']
            c = cmap.get(scenario, '#000000')
            if (last_obs_date is not None and not np.isnan(last_obs_val)
                    and last_obs_date < pd.Timestamp(target_dates[0])):
                fc_dates_plot = [last_obs_date] + list(target_dates)
                fc_mu_plot    = [last_obs_val]  + list(mu.values)
            else:
                fc_dates_plot = list(target_dates)
                fc_mu_plot    = list(mu.values)
            ax.plot(fc_dates_plot, fc_mu_plot, color=c, linewidth=lw, linestyle='--',
                    label=f'{scenario} ({depth_label})')
            ax.fill_between(target_dates, mu - sig, mu + sig, color=c, alpha=0.15)

    ax.axvline(vline_x, **vline_kw)
    _trans = blended_transform_factory(ax.transData, ax.transAxes)
    ax.text(mdates.date2num(vline_x) + 0.17, 0.97, 'forecast period →',
            transform=_trans, fontsize=9, va='top', ha='left', color='#555')
    ax.set_ylabel('Temperature (°C)')
    ax.legend(fontsize=10)
    ax.grid(True, alpha=0.3)

    # Operations panel: observed bars (history) + scenario bars (forecast)
    ax = axes[1]
    obs_nums = mdates.date2num([pd.Timestamp(d) for d in obs_dates])
    fc_nums  = mdates.date2num([pd.Timestamp(d) for d in target_dates])

    pump_obs = [obs_df['pump_flow_cfs'].get(d, np.nan) if obs_df is not None else np.nan
                for d in obs_dates]
    abt_obs  = [float(abt_dict.get(d, np.nan)) for d in obs_dates]

    bar_w_obs = 0.35
    ax.bar(obs_nums - bar_w_obs / 2, pump_obs, width=bar_w_obs,
           color='#888888', alpha=0.8, hatch='///', edgecolor='white', label='Observed – Farr Pump')
    ax.bar(obs_nums + bar_w_obs / 2, abt_obs,  width=bar_w_obs,
           color='#888888', alpha=0.8, label='Observed – AT')

    show_persist_bars = persist_pump_sch is not None and persist_abt_sch is not None
    n_sc    = len(pump_schedules) + (1 if show_persist_bars else 0)
    n_bars  = n_sc * 2
    bar_w_fc = 0.7 / n_bars if n_bars > 0 else 0.35

    bar_idx = 0
    if show_persist_bars:
        c = BASELINE_COLOR
        pump_off = (2 * bar_idx     - (n_bars - 1) / 2) * bar_w_fc
        abt_off  = (2 * bar_idx + 1 - (n_bars - 1) / 2) * bar_w_fc
        ax.bar(fc_nums + pump_off, persist_pump_sch, width=bar_w_fc,
               color=c, alpha=0.6, hatch='///', edgecolor='white', label='Persistence – Farr Pump')
        ax.bar(fc_nums + abt_off,  persist_abt_sch,  width=bar_w_fc,
               color=c, alpha=0.6, label='Persistence – AT')
        bar_idx += 1

    for idx, (name, pump_sch, abt_sch) in enumerate(zip(scenario_names, pump_schedules, abt_schedules)):
        sc_color = color_map.get(name, '#000000')
        pump_off = (2 * bar_idx     - (n_bars - 1) / 2) * bar_w_fc
        abt_off  = (2 * bar_idx + 1 - (n_bars - 1) / 2) * bar_w_fc
        if is_retrospective and idx == 0:
            obs_mask = [
                pd.notna(obs_df['pump_flow_cfs'].get(pd.Timestamp(td), np.nan) if obs_df is not None else np.nan) or
                pd.notna(abt_dict.get(pd.Timestamp(td), np.nan))
                for td in target_dates
            ]
            pump_gray  = [p if m else np.nan for p, m in zip(pump_sch, obs_mask)]
            abt_gray   = [a if m else np.nan for a, m in zip(abt_sch,  obs_mask)]
            pump_free  = [p if not m else np.nan for p, m in zip(pump_sch, obs_mask)]
            abt_free   = [a if not m else np.nan for a, m in zip(abt_sch,  obs_mask)]
            ax.bar(fc_nums + pump_off, pump_gray, width=bar_w_fc,
                   color='#888888', alpha=0.8, hatch='///', edgecolor='white', label=f'{name} – Farr Pump')
            ax.bar(fc_nums + abt_off,  abt_gray,  width=bar_w_fc,
                   color='#888888', alpha=0.8, label=f'{name} – AT')
            ax.bar(fc_nums + pump_off, pump_free, width=bar_w_fc,
                   color=sc_color, alpha=0.8, hatch='///', edgecolor='white')
            ax.bar(fc_nums + abt_off,  abt_free,  width=bar_w_fc,
                   color=sc_color, alpha=0.8)
        else:
            ax.bar(fc_nums + pump_off, pump_sch, width=bar_w_fc,
                   color=sc_color, alpha=0.8, hatch='///', edgecolor='white', label=f'{name} – Farr Pump')
            ax.bar(fc_nums + abt_off,  abt_sch,  width=bar_w_fc,
                   color=sc_color, alpha=0.8, label=f'{name} – AT')
        bar_idx += 1

    ax.xaxis_date()
    ax.axvline(vline_x, **vline_kw)
    ax.set_ylabel('Flow (cfs)')
    ax.legend(fontsize=9, ncol=2)
    ax.grid(True, alpha=0.3, axis='y')

    axes[-1].set_xlabel('Date')
    axes[-1].xaxis.set_major_locator(mdates.DayLocator())
    axes[-1].xaxis.set_major_formatter(mdates.DateFormatter('%b %-d'))
    plt.setp(axes[-1].get_xticklabels(), rotation=45, ha='right')
    fig.suptitle(f'SMR 7-day temperature forecast — init {init_date.date()}', fontsize=13)
    fig.tight_layout()
    return fig


def compute_water_balance(pump_schedule, abt_schedule, ei_flows, ni_flows, nf_flows, init_date):
    """Per-day SMR water balance (all flows in cfs).

    SMR/GL volume is assumed constant; if total_inflow < ABT, a volume deficit occurs.
    SMR outflow = total_inflow - ABT (excludes chipmunk, which is an
    intermediate gauge, not an independent source).
    ei_flows/ni_flows/nf_flows are dicts keyed by horizon h=1..7.
    """
    rows = []
    for j in range(7):
        h        = j + 1
        ei       = ei_flows[h]
        ni       = ni_flows[h]
        nf       = nf_flows[h]
        total_in = pump_schedule[j] + ei + ni + nf
        smr_out  = total_in - abt_schedule[j]
        rows.append({
            'Date':              (init_date + pd.Timedelta(days=j)).date(),
            'Farr Pump (cfs)':   pump_schedule[j],
            'EI (cfs)':          round(ei, 1),
            'NI (cfs)':          round(ni, 1),
            'NF (cfs)':          round(nf, 1),
            'Total In (cfs)':    round(total_in, 1),
            'Adams Tunnel (cfs)': abt_schedule[j],
            'SMR Outflow (cfs)': round(smr_out, 1),
            'Deficit':           smr_out < 0,
        })
    return pd.DataFrame(rows)


def make_summary(forecast_df, init_date, scenario_names, show_persistence):
    rows = []
    persist_df = forecast_df[forecast_df['scenario'] == 'Persistence'] if show_persistence else None

    for h in HORIZONS:
        target_date = init_date + pd.Timedelta(days=h - 1)
        for pred_col, label in [('pred_1m', '1m'), ('pred_0_5m', '0_5m')]:
            row = {'horizon': h, 'target_date': str(target_date.date()), 'temp_target': label}
            for sc_name in scenario_names:
                sc_sub = forecast_df[
                    (forecast_df['scenario'] == sc_name) & (forecast_df['horizon'] == h)
                ][pred_col]
                row[f'[{sc_name}] mean_degC'] = round(sc_sub.mean(), 3)
                row[f'[{sc_name}] std_degC']  = round(sc_sub.std(),  3)
                if persist_df is not None:
                    bl_sub = persist_df[persist_df['horizon'] == h][pred_col]
                    row[f'[{sc_name}] delt_vs_persistence'] = round(sc_sub.mean() - bl_sub.mean(), 3)
            rows.append(row)

    return pd.DataFrame(rows)


def _crps_ensemble(preds: np.ndarray, obs: float) -> float:
    """Energy-score CRPS for a finite ensemble vs scalar observation."""
    m = len(preds)
    mae_term    = np.mean(np.abs(preds - obs))
    spread_term = np.sum(np.abs(preds[:, None] - preds[None, :])) / (2 * m ** 2)
    return float(mae_term - spread_term)


def _prep_gefs_d(gefs_path):
    """Load a GEFS CSV and return the member×horizon indexed DataFrame."""
    raw = pd.read_csv(gefs_path)
    raw = raw[raw['horizon'].isin(NEEDED_HORIZONS)].copy()
    raw['gefs_temp_degC']    = raw['t2m'] - 273.15
    raw['gefs_wind_mps']     = np.sqrt(raw['u10'] ** 2 + raw['v10'] ** 2)
    raw['gefs_sol_rad_Wpm2'] = raw['sdswrf'].fillna(0.0)
    return raw[['member', 'horizon'] + GEFS_VARS].set_index(['member', 'horizon'])


@st.cache_data(ttl=3600)
def compute_ytd_crps(today_str: str) -> pd.DataFrame:
    """Retrospective CRPS over all archived GEFS dates with matching observations."""
    cv_models, cv_scalers, feature_cols = load_models()
    abt_dict, ei_dict, ni_dict, bakc2_df, coeff_nf, coeff_ei, coeff_ni = load_data()

    pump_raw = pd.read_csv(RAW_DIR / 'granby_daily_pump_data.csv', parse_dates=['date'])
    pump_ser = pump_raw.set_index('date')['value'].ffill()

    buoy_raw = pd.read_csv(RAW_DIR / 'SM_MID_L1.csv', parse_dates=['dateTime'])
    buoy_raw = buoy_raw[buoy_raw['flag_temp'].isna()]
    buoy_raw['date'] = buoy_raw['dateTime'].dt.normalize()
    obs_1m  = buoy_raw[buoy_raw['depth_m'] <= 1.0].groupby('date')['temp_C'].mean()
    obs_05m = buoy_raw[buoy_raw['depth_m'] <= 5.0].groupby('date')['temp_C'].mean()
    obs_1m.index  = pd.DatetimeIndex(obs_1m.index).tz_localize(None)
    obs_05m.index = pd.DatetimeIndex(obs_05m.index).tz_localize(None)

    today   = pd.Timestamp(today_str)
    records = []

    for gefs_file in sorted(GEFS_DIR.glob('GEFS_p25_*.csv')):
        init_date = pd.Timestamp(gefs_file.stem.replace('GEFS_p25_', ''))
        if init_date >= today:
            continue

        try:
            gefs_d = _prep_gefs_d(gefs_file)
        except Exception:
            continue

        realtime_state, _ = load_realtime_state(init_date.strftime('%Y-%m-%d'))
        nf_flows_raw, ei_flows_raw, ni_flows_raw = get_bakc2_flow_estimates(
            init_date, bakc2_df, coeff_nf, coeff_ei, coeff_ni
        )
        prev = init_date - pd.Timedelta(days=1)
        nf_flows = {h: (nf_flows_raw[h] if nf_flows_raw[h] is not None
                        else float(obs_1m.get(prev, np.nan)))  for h in HORIZONS}
        ei_flows = {h: (ei_flows_raw[h] if ei_flows_raw[h] is not None
                        else float(ei_dict.get(prev, np.nan))) for h in HORIZONS}
        ni_flows = {h: (ni_flows_raw[h] if ni_flows_raw[h] is not None
                        else float(ni_dict.get(prev, np.nan))) for h in HORIZONS}

        pump_schedule = [float(pump_ser.get(init_date + pd.Timedelta(days=i), np.nan))
                         for i in range(6)]
        abt_schedule  = [float(abt_dict.get(init_date + pd.Timedelta(days=i), np.nan))
                         for i in range(7)]

        try:
            sc_records = run_scenario(
                'control', pump_schedule, abt_schedule,
                init_date, gefs_d, realtime_state, abt_dict,
                cv_models, cv_scalers, feature_cols,
                nf_flows, ei_flows, ni_flows,
            )
        except Exception:
            continue

        for h in HORIZONS:
            valid_date = (init_date + pd.Timedelta(days=h - 1)).normalize()
            obs1  = obs_1m.get(valid_date,  np.nan)
            obs05 = obs_05m.get(valid_date, np.nan)
            h_recs = [r for r in sc_records if r['horizon'] == h]
            if not h_recs:
                continue
            ens_1m  = np.array([r['pred_1m']  for r in h_recs])
            ens_05m = np.array([r['pred_0_5m'] for r in h_recs])
            if not np.isnan(obs1):
                records.append({'horizon': h, 'depth': '0–1 m',
                                'crps': _crps_ensemble(ens_1m, obs1)})
            if not np.isnan(obs05):
                records.append({'horizon': h, 'depth': '0–5 m',
                                'crps': _crps_ensemble(ens_05m, obs05)})

    return pd.DataFrame(records)


def make_crps_figure(crps_df: pd.DataFrame):
    """Grouped bar chart of mean CRPS by forecast horizon for both depths."""
    summary = (crps_df
               .groupby(['horizon', 'depth'])['crps']
               .agg(mean_crps='mean', n='count')
               .reset_index())

    depths = ['0–1 m', '0–5 m']
    colors = ['#56B4E9', '#009E73']
    x      = np.arange(len(HORIZONS))
    width  = 0.35

    fig, ax = plt.subplots(figsize=(9, 4))
    for i, (depth, color) in enumerate(zip(depths, colors)):
        sub  = summary[summary['depth'] == depth].set_index('horizon')
        vals = [sub.loc[h, 'mean_crps'] if h in sub.index else np.nan for h in HORIZONS]
        ns   = [int(sub.loc[h, 'n'])    if h in sub.index else 0      for h in HORIZONS]
        bars = ax.bar(x + (i - 0.5) * width, vals, width,
                      label=depth, color=color, alpha=0.85)
        for bar, n in zip(bars, ns):
            if n > 0:
                ax.text(bar.get_x() + bar.get_width() / 2,
                        bar.get_height() + 0.005,
                        f'n={n}', ha='center', va='bottom', fontsize=7)

    ax.set_xticks(x)
    ax.set_xticklabels([f'Day {h}' for h in HORIZONS])
    ax.set_xlabel('Forecast Horizon')
    ax.set_ylabel('Mean CRPS (°C)')
    ax.set_title('Year-to-Date Forecast Performance (Control Scenario)')
    ax.legend(title='Depth')
    ax.set_ylim(bottom=0)
    fig.tight_layout()
    return fig


# ── Session state init ────────────────────────────────────────────────────────

def _init_scenario(sid, name, pump_default=300, abt_default=200):
    st.session_state[f'sc_name_{sid}'] = name
    for j in range(7):
        st.session_state[f'pump_{sid}_{j}'] = pump_default
        st.session_state[f'abt_{sid}_{j}']  = abt_default


if 'scenarios' not in st.session_state:
    st.session_state.scenarios = [{'id': 0, 'name': 'Scenario A'}]
    st.session_state.next_id   = 1
    _init_scenario(0, 'Scenario A')

if '_show_baseline' not in st.session_state:
    st.session_state['_show_baseline'] = False


def _add_scenario():
    n   = len(st.session_state.scenarios)
    sid = st.session_state.next_id
    st.session_state.next_id += 1
    name = DEFAULT_NAMES[min(n, 3)]
    st.session_state.scenarios.append({'id': sid, 'name': name})
    _init_scenario(sid, name)


def _remove_scenario():
    if len(st.session_state.scenarios) > 1:
        removed = st.session_state.scenarios.pop()
        sid = removed['id']
        for key in ([f'sc_name_{sid}'] +
                    [f'pump_{sid}_{j}' for j in range(7)] +
                    [f'abt_{sid}_{j}'  for j in range(7)]):
            st.session_state.pop(key, None)


# ── Sidebar ───────────────────────────────────────────────────────────────────

with st.sidebar:
    _c1, _c2 = st.columns(2)
    if _c1.button("How to Use", use_container_width=True):
        _show_help()
    _c2.link_button(
        "Contact / Suggest",
        "mailto:b.steele@colostate.edu?subject=SMR%20Forecast%20App%20Feedback",
        use_container_width=True,
    )
    st.header("Forecast Settings")

    # Load static data (cached)
    abt_dict, ei_dict, ni_dict, bakc2_df, coeff_nf, coeff_ei, coeff_ni = load_data()

    # Date range from available GEFS operational files, restricted to Jun 1–Sep 30
    gefs_files = sorted(GEFS_DIR.glob('GEFS_p25_*.csv'))
    gefs_files = [f for f in gefs_files
                  if 6 <= pd.Timestamp(f.stem.replace('GEFS_p25_', '')).month <= 9]
    if gefs_files:
        min_date = pd.Timestamp(gefs_files[0].stem.replace('GEFS_p25_', '')).date()
        max_date = pd.Timestamp(gefs_files[-1].stem.replace('GEFS_p25_', '')).date()
    else:
        today    = pd.Timestamp.today().date()
        min_date = max_date = today

    init_date_raw = st.date_input(
        "Initialization date",
        value=max_date,
        min_value=min_date,
        max_value=max_date,
        help="Forecast covers 7 days starting from this date.",
    )
    init_date = pd.Timestamp(init_date_raw)
    prev_date = init_date - pd.Timedelta(days=1)

    # GEFS file status
    gefs_path = GEFS_DIR / f'GEFS_p25_{init_date.strftime("%Y-%m-%d")}.csv'
    gefs_ok   = gefs_path.exists()

    # Real-time observed state for persistence baseline
    _, obs_df     = load_realtime_state(init_date)
    persist_nf    = float(obs_df['nf_flow_cfs'].get(prev_date, np.nan))
    persist_ei    = float(ei_dict.get(prev_date, np.nan))
    persist_ni    = float(ni_dict.get(prev_date, np.nan))
    persist_pump  = float(obs_df['pump_flow_cfs'].get(prev_date, np.nan))
    persist_abt   = float(abt_dict.get(prev_date, np.nan))

    # Fall back to last observed value (persistence) when prev_date data is missing
    _pump_persist_date = None
    _abt_persist_date  = None
    if np.isnan(persist_pump):
        _s = obs_df['pump_flow_cfs'].dropna()
        _s = _s[_s.index <= prev_date]
        if not _s.empty:
            persist_pump       = float(_s.iloc[-1])
            _pump_persist_date = _s.index[-1]
    if np.isnan(persist_nf):
        _s = obs_df['nf_flow_cfs'].dropna()
        _s = _s[_s.index <= prev_date]
        if not _s.empty:
            persist_nf = float(_s.iloc[-1])
    if np.isnan(persist_abt):
        _abt_valid = sorted(
            [(d, v) for d, v in abt_dict.items() if pd.notna(v) and d <= prev_date]
        )
        if _abt_valid:
            _last_abt_date, persist_abt = _abt_valid[-1]
            _abt_persist_date           = _last_abt_date

    prev_ok = not (np.isnan(persist_pump) or np.isnan(persist_nf))

    # BAKC2-derived flow estimates
    nf_est, ei_est, ni_est = get_bakc2_flow_estimates(
        init_date, bakc2_df, coeff_nf, coeff_ei, coeff_ni
    )

    # Resolve per-horizon flow dicts (fall back to persistence where BAKC2 is missing)
    nf_flows = {h: nf_est[h] if nf_est.get(h) is not None else persist_nf for h in HORIZONS}
    ei_flows = {h: ei_est[h] if ei_est.get(h) is not None else persist_ei for h in HORIZONS}
    ni_flows = {h: ni_est[h] if ni_est.get(h) is not None else persist_ni for h in HORIZONS}

    # Store flow dicts in session_state for use in run_clicked block
    st.session_state['nf_flows'] = nf_flows
    st.session_state['ei_flows'] = ei_flows
    st.session_state['ni_flows'] = ni_flows

    is_retrospective = (init_date_raw != max_date)

    # Auto-fill Scenario A with observed ops when switching to a retrospective date
    if st.session_state.get('_last_init_date') != init_date:
        st.session_state['_last_init_date'] = init_date
        sid = st.session_state.scenarios[0]['id']
        if is_retrospective:
            st.session_state[f'sc_name_{sid}'] = 'Scenario A'
            for j in range(7):
                day = init_date + pd.Timedelta(days=j)
                obs_pump = obs_df['pump_flow_cfs'].get(day, np.nan)
                obs_abt  = abt_dict.get(day, np.nan)
                st.session_state[f'pump_{sid}_{j}'] = int(obs_pump) if pd.notna(obs_pump) else 300
                st.session_state[f'abt_{sid}_{j}']  = int(obs_abt)  if pd.notna(obs_abt)  else 200
            while len(st.session_state.scenarios) > 2:
                _remove_scenario()
        else:
            _init_scenario(sid, 'Scenario A')

    can_run = gefs_ok and prev_ok

    if prev_ok:
        _pump_note = (f" *(assumed from {_pump_persist_date.strftime('%b %-d')}, previous day data unavailable)*"
                      if _pump_persist_date else "")
        _abt_note  = (f" *(assumed from {_abt_persist_date.strftime('%b %-d')}, previous day data unavailable)*"
                      if _abt_persist_date else "")
        st.caption(f"**Prior-day ops ({prev_date.strftime('%b %-d')}):**  \n"
                   f"Farr Pump {persist_pump:.0f} cfs{_pump_note}  \n"
                   f"Adams Tunnel {persist_abt:.0f} cfs{_abt_note}")

    st.subheader("Operational Scenarios")

    _max_scenarios = 2 if is_retrospective else 4
    c1, c2 = st.columns(2)
    c1.button("＋ Add",    on_click=_add_scenario,    key="btn_add",
              disabled=len(st.session_state.scenarios) >= _max_scenarios,
              use_container_width=True)
    c2.button("－ Remove", on_click=_remove_scenario, key="btn_remove",
              disabled=len(st.session_state.scenarios) <= 1,
              use_container_width=True)

    # Sync display names before creating tabs
    for sc in st.session_state.scenarios:
        sc['name'] = st.session_state.get(f'sc_name_{sc["id"]}', sc['name'])

    sc_tabs = st.tabs([sc['name'] for sc in st.session_state.scenarios])

    for i, (tab, sc) in enumerate(zip(sc_tabs, st.session_state.scenarios)):
        sid = sc['id']
        lock_sc_a = is_retrospective and (i == 0)
        with tab:
            st.text_input("Name", key=f'sc_name_{sid}', disabled=lock_sc_a)
            if lock_sc_a:
                st.caption("Scenario A reflects observed operations. Days with observed data cannot be edited.")

            h1, h2, h3 = st.columns(3)
            h1.write("**Date**")
            h2.write("**Farr Pump (cfs)**")
            h3.write("**Adams Tunnel (cfs)**")
            for j in range(7):
                day_date = init_date + pd.Timedelta(days=j)
                lbl = f"{day_date.strftime('%a %b')} {day_date.day}"
                c1, c2, c3 = st.columns(3)
                c1.write(lbl)
                if lock_sc_a:
                    lock_pump = pd.notna(obs_df['pump_flow_cfs'].get(day_date, np.nan))
                    lock_abt  = pd.notna(abt_dict.get(day_date, np.nan))
                else:
                    lock_pump = lock_abt = False
                c2.number_input(lbl, min_value=0, max_value=800, step=50,
                                key=f'pump_{sid}_{j}', label_visibility="collapsed",
                                disabled=lock_pump)
                c3.number_input(lbl, min_value=0, max_value=600, step=50,
                                key=f'abt_{sid}_{j}', label_visibility="collapsed",
                                disabled=lock_abt)

            # ── Water balance check (live) ────────────────────────────────────
            if prev_ok:
                _pump_j = [int(st.session_state.get(f'pump_{sid}_{j}', 300)) for j in range(7)]
                _abt_j  = [int(st.session_state.get(f'abt_{sid}_{j}',  200)) for j in range(7)]
                _wb = compute_water_balance(_pump_j, _abt_j,
                                            ei_flows, ni_flows, nf_flows, init_date)
                _deficit_rows = _wb[_wb['Deficit']]
                if not _deficit_rows.empty:
                    day_strs = ', '.join(str(d) for d in _deficit_rows['Date'])
                    st.warning(f"Inflow < AT on: {day_strs} — reservoir volume will be impacted.")


# ── Scenario fingerprint for auto-run detection ───────────────────────────────
_sc_fingerprint = (
    init_date,
    tuple(
        (
            st.session_state.get(f'sc_name_{sc["id"]}', sc['name']),
            tuple(st.session_state.get(f'pump_{sc["id"]}_{j}', 300) for j in range(7)),
            tuple(st.session_state.get(f'abt_{sc["id"]}_{j}',  200) for j in range(7)),
        )
        for sc in st.session_state.scenarios
    ),
)

# ── Main area ─────────────────────────────────────────────────────────────────

st.markdown(
    "<h1 style='line-height:1.2; margin-bottom:0'>Shadow Mountain Reservoir<br>7-Day Temperature Forecast</h1>",
    unsafe_allow_html=True,
)

if not can_run and not gefs_ok:
    st.info("Select a date that has an available GEFS operational file to enable the forecast.")

# Debounce: wait 0.5 s of inactivity before running the forecast
_fingerprint_changed = _sc_fingerprint != st.session_state.get('_last_fingerprint')
if _fingerprint_changed:
    if st.session_state.get('_pending_fingerprint') != _sc_fingerprint:
        st.session_state['_pending_fingerprint'] = _sc_fingerprint
        st.session_state['_pending_since'] = time.time()
    elapsed = time.time() - st.session_state['_pending_since']
    if elapsed < 0.5:
        time.sleep(0.5 - elapsed)
        st.rerun()

should_run = can_run and _fingerprint_changed

if should_run:
    cv_models, cv_scalers, feature_cols = load_models()
    abt_dict, ei_dict, ni_dict, bakc2_df, coeff_nf, coeff_ei, coeff_ni = load_data()
    realtime_state, obs_df = load_realtime_state(init_date)
    nf_flows = st.session_state['nf_flows']
    ei_flows = st.session_state['ei_flows']
    ni_flows = st.session_state['ni_flows']

    # Load and transform GEFS file
    gefs_d = _prep_gefs_d(gefs_path)

    # Collect scenario configs from widget state
    scenario_names = []
    pump_schedules = []
    abt_schedules  = []
    for sc in st.session_state.scenarios:
        sid  = sc['id']
        name = st.session_state.get(f'sc_name_{sid}', sc['name'])
        pump = [int(st.session_state.get(f'pump_{sid}_{j}', 300)) for j in range(7)]
        abt  = [int(st.session_state.get(f'abt_{sid}_{j}',  200)) for j in range(7)]
        scenario_names.append(name)
        pump_schedules.append(pump)
        abt_schedules.append(abt)

    all_records = []

    # Persistence baseline: previous day's pump/ABT repeated, same BAKC2 flows
    prev_date    = init_date - pd.Timedelta(days=1)
    persist_pump = float(obs_df['pump_flow_cfs'].get(prev_date, np.nan))
    persist_abt  = float(abt_dict.get(prev_date, np.nan))
    if np.isnan(persist_pump):
        _s = obs_df['pump_flow_cfs'].dropna()
        _s = _s[_s.index <= prev_date]
        persist_pump = float(_s.iloc[-1]) if not _s.empty else 0.0
    if np.isnan(persist_abt):
        _abt_valid = sorted(
            [(d, v) for d, v in abt_dict.items() if pd.notna(v) and d <= prev_date]
        )
        persist_abt = float(_abt_valid[-1][1]) if _abt_valid else 0.0
    persist_pump_sch = [int(persist_pump)] * 7
    persist_abt_sch  = [int(persist_abt)]  * 7

    with st.spinner("Running ensemble forecast across all scenarios…"):
        for name, pump_sch, abt_sch in zip(scenario_names, pump_schedules, abt_schedules):
            all_records.extend(run_scenario(
                name, pump_sch, abt_sch,
                init_date, gefs_d, realtime_state, abt_dict,
                cv_models, cv_scalers, feature_cols,
                nf_flows, ei_flows, ni_flows,
            ))

        all_records.extend(run_scenario(
            'Persistence', persist_pump_sch, persist_abt_sch,
            init_date, gefs_d, realtime_state, abt_dict,
            cv_models, cv_scalers, feature_cols,
            nf_flows, ei_flows, ni_flows,
        ))

    forecast_df = pd.DataFrame(all_records)
    st.session_state['forecast_df']             = forecast_df
    st.session_state['forecast_scenario_names'] = scenario_names
    st.session_state['forecast_init_date']      = init_date

    wb_by_scenario = {}
    for name, pump_sch, abt_sch in zip(scenario_names, pump_schedules, abt_schedules):
        wb_by_scenario[name] = compute_water_balance(
            pump_sch, abt_sch, ei_flows, ni_flows, nf_flows, init_date
        )
    st.session_state['water_balance'] = wb_by_scenario

    st.session_state['gefs_d_raw']         = gefs_d
    st.session_state['obs_df']             = obs_df
    st.session_state['met_flow_init_date'] = init_date
    st.session_state['met_nf_flows']       = nf_flows
    st.session_state['met_ei_flows']       = ei_flows
    st.session_state['met_ni_flows']       = ni_flows
    st.session_state['pump_schedules']     = pump_schedules
    st.session_state['abt_schedules']      = abt_schedules
    st.session_state['pump_persist_sch']   = persist_pump_sch
    st.session_state['abt_persist_sch']    = persist_abt_sch
    st.session_state['is_retrospective']   = is_retrospective
    st.session_state['_last_fingerprint']  = _sc_fingerprint

if 'forecast_df' in st.session_state:
    _fdf   = st.session_state['forecast_df']
    _names = st.session_state['forecast_scenario_names']
    _idate = st.session_state['forecast_init_date']

    show_baseline = st.checkbox(
        "Show persistence (previous day pump/AT operations)",
        value=st.session_state['_show_baseline'],
    )
    st.session_state['_show_baseline'] = show_baseline

    disp_df = _fdf if show_baseline else _fdf[_fdf['scenario'] != 'Persistence']

    fig = make_unified_figure(
        disp_df,
        st.session_state.get('obs_df'),
        abt_dict,
        _idate,
        _names,
        st.session_state.get('pump_schedules', []),
        st.session_state.get('abt_schedules',  []),
        st.session_state.get('pump_persist_sch') if show_baseline else None,
        st.session_state.get('abt_persist_sch') if show_baseline else None,
        is_retrospective=st.session_state.get('is_retrospective', False),
    )
    st.pyplot(fig)

    png_buf = io.BytesIO()
    fig.savefig(png_buf, format='png', dpi=150, bbox_inches='tight')
    png_buf.seek(0)
    st.download_button(
        "Download PNG",
        data=png_buf,
        file_name=f'SMR_forecast_{_idate.strftime("%Y%m%d")}.png',
        mime='image/png',
    )
    plt.close(fig)

    tab_compare, tab_tables, tab_wb, tab_inputs, tab_crps = st.tabs(
        ["Scenario Comparison", "Summary Tables", "Water Balance", "Met & Flow Inputs", "YTD Performance"]
    )

    with tab_tables:
        summary = make_summary(_fdf, _idate, _names, show_baseline)
        _drop_cols = ['temp_target', 'horizon'] + [c for c in summary.columns if 'std_degC' in c]
        _rename = lambda c: (
            'Forecast Date' if c == 'target_date'
            else c.replace('mean_degC', 'Mean Predicted Water Temperature (°C)')
                   .replace('delt_vs_persistence', 'Departure from Persistence Forecast')
        )

        st.subheader("0–1 m depth (near-surface)")
        tbl_1m = (summary[summary['temp_target'] == '1m']
                  .drop(columns=_drop_cols)
                  .rename(columns=_rename)
                  .reset_index(drop=True))
        st.dataframe(tbl_1m, use_container_width=True, hide_index=True)

        st.subheader("0–5 m depth (integrated)")
        tbl_05m = (summary[summary['temp_target'] == '0_5m']
                   .drop(columns=_drop_cols)
                   .rename(columns=_rename)
                   .reset_index(drop=True))
        st.dataframe(tbl_05m, use_container_width=True, hide_index=True)

        csv_buf = io.StringIO()
        summary.to_csv(csv_buf, index=False)
        st.download_button(
            "Download CSV",
            data=csv_buf.getvalue(),
            file_name=f'pump_summary_{_idate.strftime("%Y%m%d")}.csv',
            mime='text/csv',
        )

    with tab_wb:
        st.caption(
            "SMR volume is constant. Total inflow = Farr Pump + EI + NI + NF. "
            "SMR Outflow = Total Inflow − AT. Rows where inflow < AT are flagged "
            "— the reservoir cannot sustain that operation without drawing down volume."
        )
        if 'water_balance' in st.session_state:
            _wb_dict = st.session_state['water_balance']
            for name in _names:
                if name not in _wb_dict:
                    continue
                wb = _wb_dict[name]
                st.subheader(name)
                deficit_rows = wb[wb['Deficit']]
                if not deficit_rows.empty:
                    day_strs = ', '.join(str(d) for d in deficit_rows['Date'])
                    st.warning(f"Inflow < AT on: {day_strs} — reservoir volume will be impacted.")
                disp_wb = wb.drop(columns=['Deficit']).reset_index(drop=True)

                def _style_row(row):
                    style = 'background-color: #ffe0e0; color: black' if row['SMR Outflow (cfs)'] < 0 else ''
                    return [style] * len(row)

                st.dataframe(
                    disp_wb.style.apply(_style_row, axis=1),
                    use_container_width=True,
                    hide_index=True,
                )

    with tab_compare:
        all_options = ['Persistence'] + _names
        ref_sc = st.selectbox(
            "Reference scenario (all others compared against this):",
            options=all_options,
            index=0,
            key='compare_ref',
        )

        ref_agg = (
            _fdf[_fdf['scenario'] == ref_sc]
            .groupby('target_date')[['pred_1m', 'pred_0_5m']].mean()
        )

        compare_scs = [s for s in all_options if s != ref_sc]
        rows_1m, rows_05m = [], []
        for sc in compare_scs:
            sc_agg = (
                _fdf[_fdf['scenario'] == sc]
                .groupby('target_date')[['pred_1m', 'pred_0_5m']].mean()
            )
            diff = sc_agg - ref_agg
            row_1m  = {'Scenario': sc}
            row_05m = {'Scenario': sc}
            for td in sorted(diff.index):
                lbl = pd.Timestamp(td).strftime('%b %-d')
                row_1m[lbl]  = round(float(diff.loc[td, 'pred_1m']),  2)
                row_05m[lbl] = round(float(diff.loc[td, 'pred_0_5m']), 2)
            rows_1m.append(row_1m)
            rows_05m.append(row_05m)

        if compare_scs:
            st.caption(
                f"Delta °C = scenario mean − {ref_sc} mean. "
                "Positive = warmer than reference; negative = cooler."
            )
            df_1m  = pd.DataFrame(rows_1m)
            df_05m = pd.DataFrame(rows_05m)
            date_cols = [c for c in df_1m.columns if c != 'Scenario']
            max_abs = max(
                df_1m[date_cols].abs().max().max(),
                df_05m[date_cols].abs().max().max(),
                0.1,
            )

            st.subheader(f"Change in Temperature vs {ref_sc} — 0–1 m depth")
            st.dataframe(
                df_1m.style.background_gradient(
                    cmap='coolwarm', axis=None, subset=date_cols,
                    vmin=-max_abs, vmax=max_abs,
                ).format({c: '{:+.2f}' for c in date_cols}),
                use_container_width=True, hide_index=True,
            )

            st.subheader(f"Change in Temperature vs {ref_sc} — 0–5 m depth (integrated)")
            st.dataframe(
                df_05m.style.background_gradient(
                    cmap='coolwarm', axis=None, subset=date_cols,
                    vmin=-max_abs, vmax=max_abs,
                ).format({c: '{:+.2f}' for c in date_cols}),
                use_container_width=True, hide_index=True,
            )
        else:
            st.info("Add at least two scenarios to enable comparison.")

    with tab_inputs:
        if 'gefs_d_raw' in st.session_state:
            abt_dict, ei_dict, ni_dict, bakc2_df, coeff_nf, coeff_ei, coeff_ni = load_data()
            fig_inp = make_met_flow_figure(
                st.session_state['gefs_d_raw'],
                st.session_state['obs_df'],
                abt_dict, ei_dict, ni_dict,
                st.session_state['met_nf_flows'],
                st.session_state['met_ei_flows'],
                st.session_state['met_ni_flows'],
                st.session_state['pump_schedules'],
                st.session_state['abt_schedules'],
                st.session_state['pump_persist_sch'],
                st.session_state['abt_persist_sch'],
                _names,
                st.session_state['met_flow_init_date'],
                is_retrospective=st.session_state.get('is_retrospective', False),
            )
            st.caption(
                "Dashed vertical line marks the forecast initialization date. "
                "Left of line = observed; right of line = forecast. "
                "Met variables show GEFS ensemble mean ± 1 std (shaded band)."
            )
            st.pyplot(fig_inp)
            plt.close(fig_inp)
        else:
            st.info("Run the forecast to view meteorological and flow inputs.")

    with tab_crps:
        st.caption(
            "CRPS (Continuous Ranked Probability Score) measures ensemble forecast accuracy — "
            "lower is better. Computed retrospectively using actual observed Farr Pump and AT "
            "operations and GEFS forecasts issued on each historical date."
        )
        with st.spinner("Computing year-to-date CRPS…"):
            _today_str = pd.Timestamp.today().strftime('%Y-%m-%d')
            crps_df = compute_ytd_crps(_today_str)
        if crps_df.empty:
            st.info("No verified forecast–observation pairs available yet for the current season.")
        else:
            fig_crps = make_crps_figure(crps_df)
            st.pyplot(fig_crps)
            plt.close(fig_crps)

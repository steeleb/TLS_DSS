# How to Use This App

This tool generates a **7-day water temperature forecast** for Shadow Mountain Reservoir (SMR) under one or more user-defined pump and delivery scenarios. It uses a machine-learning ensemble model driven by real-time GEFS meteorological forecasts and CBRFC streamflow forecasts.

---

## Sidebar: Forecast Settings

### Initialization Date

Choose the date from which the 7-day forecast runs. Only dates with an available GEFS operational file are selectable (typically the current season). The most recent available date is selected by default.

**Prior-day operations** (Farr Pump and Adams Tunnel flows from the day before) are shown below the date picker and are used to build the persistence baseline.

---

### Operational Scenarios

You can compare up to **4 scenarios** simultaneously. Each scenario represents a different proposed pump and delivery schedule for the 7-day forecast window.

- **＋ Add / － Remove** — add or remove scenarios (minimum 1, maximum 4)
- Each scenario has a **Name** field and a daily table with two inputs:
  - **Farr Pump (cfs)** — water pumped *into* SMR (0–800 cfs, step 50)
  - **Adams Tunnel (cfs)** — water delivered *out* of SMR (0–600 cfs, step 50)

> **Tip:** When viewing a past date, Scenario A is automatically pre-filled with the actual observed operations for that period.

#### Water Balance Warning

A live water balance check runs as you enter values. If the total inflow (Farr Pump + East Inlet + North Inlet + North Fork) falls below the Adams Tunnel delivery on any day, a **warning** appears — that operation would draw down reservoir volume.

---

## Main Panel

The forecast runs automatically whenever you change the date or any scenario values.

### Temperature Forecast Chart

The main chart shows predicted SMR water temperature for each scenario across the 7-day window.

- **Solid lines** — observed temperatures (black = 0–1 m depth, dark gray = 0–5 m depth)
- **Dashed lines** — scenario forecasts (each scenario has its own color)
- **Shaded bands** — ensemble spread (±1 standard deviation across GEFS members)
- **Dashed vertical line** — forecast initialization date; left is observed, right is forecast
- **Persistence** — a gray baseline scenario that repeats the prior day's Farr Pump and Adams Tunnel values for all 7 days (toggle with the checkbox below the chart)

> **Download PNG** — saves the current chart as a high-resolution image.

---

### Tabs

#### Summary Tables

Tabular view of the mean predicted temperature for each scenario at each forecast date, shown separately for **0–1 m** and **0–5 m** depths. When the persistence baseline is shown, a **Departure from Persistence** column indicates how much warmer or cooler each scenario is expected to be relative to the no-change baseline.

> **Download CSV** — saves the full summary table.

#### Water Balance

A day-by-day breakdown of SMR inflows and outflows for each scenario:

| Column | Description |
|---|---|
| Farr Pump | Pumped inflow you specified |
| EI / NI / NF | East Inlet, North Inlet, North Fork (apportioned from SMRC2 forecast — see below) |
| Total In | Sum of all inflows |
| Adams Tunnel | Delivery out of SMR you specified |
| SMR Outflow | Total In minus Adams Tunnel |

Rows where **SMR Outflow < 0** are highlighted in red — those days would require drawing down reservoir storage.

**How tributary inflows are estimated:** The app uses the CBRFC **SMRC2** forecast (total streamflow at Shadow Mountain Reservoir) to project East Inlet, North Inlet, and North Fork flows over the 7-day window. Because SMRC2 gives only a combined total, it is apportioned to the three tributaries using the proportions observed on the prior day:

> prop(EI) = EI_observed / (EI + NI + NF)_observed, and similarly for NI and NF.

Each day's SMRC2 forecast total is then multiplied by those fixed proportions to get per-tributary estimates (minimum 1 cfs applied to each). **Day 1** always uses prior-day observed values directly, since the SMRC2 forecast does not issue a same-day value. If SMRC2 data are unavailable for any day, that day also falls back to prior-day observed values (persistence). The proportions used are shown in the sidebar caption beneath the initialization date.

#### Scenario Comparison

Side-by-side temperature difference (Δ°C) between each scenario and a user-selected reference.

- **Reference scenario** — choose any scenario (including Persistence) as the baseline; defaults to Persistence.
- Tables show signed Δ°C (positive = warmer than reference, negative = cooler) for each forecast day.
- Color coding uses a warm–cool scale centered on zero, making it easy to see which days each scenario diverges most from the baseline.
- Two tables are shown: **0–1 m depth** and **0–5 m depth (integrated)**.
- The color scale is shared across both depth tables so they are directly comparable.

#### Met & Flow Inputs

Diagnostic panel showing the model inputs for the selected initialization date:

- **Panel 1** — Farr Pump and Adams Tunnel deliveries (observed history + scenario forecasts)
- **Panel 2** — North Fork, East Inlet, and North Inlet flows (observed + CBRFC forecast)
- **Panels 3–5** — GEFS air temperature, solar radiation, and wind speed (observed + ensemble mean ± 1 std)

The dashed vertical line marks the boundary between observed data (left) and forecast inputs (right).

#### YTD Performance

Shows year-to-date **CRPS (Continuous Ranked Probability Score)** for the control scenario — a measure of ensemble forecast accuracy that rewards both sharpness and calibration. Lower CRPS indicates better forecast skill.

- **X-axis** — Forecast horizon day (Day 1 = next-day forecast, Day 7 = 7-day-ahead forecast)
- **Y-axis** — Mean CRPS (°C) averaged over all evaluated forecast–observation pairs at that horizon
- **Two bar groups per horizon** — blue = 0–1 m depth, green = 0–5 m depth (integrated)
- **n =** label on each bar — the number of forecast–observation pairs used to compute the mean; will grow as the season progresses

CRPS is computed retrospectively: for each past date with an archived GEFS file, the model is run using the **actual observed Farr Pump and Adams Tunnel operations** and verified against buoy temperature observations. Only dates where both a GEFS operational file and buoy observations are available contribute to the score.

---

## Key Terms

| Term | Definition |
|---|---|
| **SMR** | Shadow Mountain Reservoir |
| **Farr Pump** | Pump that moves water from the Colorado River into SMR |
| **Adams Tunnel (AT)** | Transmountain diversion that delivers water out of SMR to the Front Range |
| **GEFS** | Global Ensemble Forecast System — NOAA's meteorological ensemble used as model input |
| **CBRFC** | Colorado Basin River Forecast Center — issues operational streamflow forecasts used to estimate tributary inflows |
| **SMRC2** | CBRFC forecast point at Shadow Mountain Reservoir (Colorado River); provides total inflow forecast that is apportioned to EI, NI, and NF |
| **BAKC2** | CBRFC forecast point on the Colorado River above Granby; used in historical model development |
| **NF / EI / NI** | North Fork, East Inlet, North Inlet — tributary inflows to Grand Lake / SMR |
| **Persistence** | Baseline scenario: prior day's pump and Adams Tunnel values held constant for all 7 days |
| **CRPS** | Continuous Ranked Probability Score — measures ensemble forecast quality; accounts for both accuracy and spread. Lower is better. |
| **cfs** | Cubic feet per second — unit of flow |

---

## Questions or Feedback?

Use the **Contact / Suggest** button at the top right of the page to send feedback.

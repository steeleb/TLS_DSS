import pandas as pd
import numpy as np

# create a function to filter and prep the data for the forecast

def prep_features(data, one_date, regime = "control"):
    
    # create a date range of 7 days following
    date_range = pd.date_range(start=one_date, periods=7, freq='D')

    # filter the data (model_data)
    filtered_data = data[(data['date'] >= date_range[0]) & (data['date'] <= date_range[-1])].copy()

    # check to see that all the data is present (we need 7 rows of data)
    if filtered_data.shape[0] != 7:
        return

    # make the date the index
    filtered_data.set_index("date", inplace=True)

    # and now coerce mean_1m_temp_degC and mean_0_5m_temp_degC to NaN no matter the value
    filtered_data.loc[:, "mean_1m_temp_degC"] = np.nan
    filtered_data.loc[:, "mean_0_5m_temp_degC"] = np.nan

    # let's change the _m1 temp columns for date + 1 day and beyond to NaN
    filtered_data.loc[filtered_data.index > one_date, "mean_1m_temp_degC_m1"] = np.nan
    filtered_data.loc[filtered_data.index > one_date, "mean_0_5m_temp_degC_m1"] = np.nan

    # if the regime is "control", then export with forecast_date
    # if the regime is "altered", then export with additional amendments to pumping and add forecast_date
    if regime == "control":

        filtered_data["forecast_date"] = one_date
        return filtered_data
    
    elif regime == "altered":

        # create a new dataframe from filtered data
        filtered_pulsing_pump = filtered_data.copy()

        # and coerce any column starting with "pump" to NaN
        for col in filtered_pulsing_pump.columns:
            if col.startswith("pump"):
                filtered_pulsing_pump.loc[:, col] = np.nan

        # create a forecast date column
        filtered_pulsing_pump["forecast_date"] = one_date

        # return the filtered pulsing_pump dataframe
        return filtered_pulsing_pump
    
    # otherwise, return an error message
    else:
        raise ValueError(f"Unrecognized regime argument: {regime}. Expected 'control' or 'altered'.")


def static_regime(data, control, one_date, flow):
    
    # coerce one_date to a pandas datetime object, as well as the forecast date column!
    one_date = pd.to_datetime(one_date)

    # Convert forecast_date columns to datetime if needed
    control["forecast_date"] = pd.to_datetime(control["forecast_date"])
    data["forecast_date"] = pd.to_datetime(data["forecast_date"])

    # we need the control data for filling in observed data
    filtered_data = control.loc[control["forecast_date"] == one_date].copy()

    # and just filter the incoming data for the forecast date.
    filtered_static_pump = data.loc[data["forecast_date"] == one_date].copy()

    # m1 for the first day will be m1 from the control data
    filtered_static_pump.loc[filtered_static_pump.index == one_date, "pump_cfs_m1"] = filtered_data.loc[one_date, "pump_cfs_m1"]

    # all of the m1 will be 220 cfs after the first day
    mask = [isinstance(idx, pd.Timestamp) and idx > one_date for idx in filtered_static_pump.index]
    filtered_static_pump.loc[mask, "pump_cfs_m1"] = flow

    # m2 for the first day will be m2 from the control data
    filtered_static_pump.loc[filtered_static_pump.index == one_date, "pump_cfs_m2"] = filtered_data.loc[one_date, "pump_cfs_m2"]
    # m2 for the second day will be m2 from the control data
    filtered_static_pump.loc[filtered_static_pump.index == one_date + pd.Timedelta(days=1), "pump_cfs_m2"] = filtered_data.loc[one_date + pd.Timedelta(days=1), "pump_cfs_m2"]
    # m2 will be 220 cfs after the second day
    mask = [isinstance(idx, pd.Timestamp) and idx > one_date + pd.Timedelta(days=1) for idx in filtered_static_pump.index]
    filtered_static_pump.loc[mask, "pump_cfs_m2"] = flow

    # m3 for the first day will be m3 from the control data
    filtered_static_pump.loc[filtered_static_pump.index == one_date, "pump_cfs_m3"] = filtered_data.loc[one_date, "pump_cfs_m3"]
    # m3 for the second day will be m3 from the control data
    filtered_static_pump.loc[filtered_static_pump.index == one_date + pd.Timedelta(days=1), "pump_cfs_m3"] = filtered_data.loc[one_date + pd.Timedelta(days=1), "pump_cfs_m3"]
    # m3 for the third day will be m3 from the control data
    filtered_static_pump.loc[filtered_static_pump.index == one_date + pd.Timedelta(days=2), "pump_cfs_m3"] = filtered_data.loc[one_date + pd.Timedelta(days=2), "pump_cfs_m3"]
    # m3 will be 220 cfs after the third day
    mask = [isinstance(idx, pd.Timestamp) and idx > one_date + pd.Timedelta(days=2) for idx in filtered_static_pump.index]
    filtered_static_pump.loc[mask, "pump_cfs_m3"] = flow

    return filtered_static_pump

def pulsed_regime(data, control, one_date, weekday_flow, weekend_flow):
    
    # coerce one_date to a pandas datetime object, as well as the forecast date column!
    one_date = pd.to_datetime(one_date)

    # Convert forecast_date columns to datetime if needed
    control["forecast_date"] = pd.to_datetime(control["forecast_date"])
    data["forecast_date"] = pd.to_datetime(data["forecast_date"])

    # we need the control data for filling in observed data
    filtered_data = control.loc[control["forecast_date"] == one_date].copy()

    # and just filter the incoming data for the forecast date.
    filtered_pulsing_pump = data.loc[data["forecast_date"] == one_date].copy()
    
    # create a column for day of week using the index in the pump_pulsing dataframe, in shorthand mon, tue, wed, etc.
    filtered_pulsing_pump["day_of_week"] = filtered_pulsing_pump.index.day_name()

    # m1 for the first day will be m1 from the control data
    filtered_pulsing_pump.loc[filtered_pulsing_pump.index == one_date, "pump_cfs_m1"] = filtered_data.loc[one_date, "pump_cfs_m1"]
    # all of the m1 will be 220 cfs after the first day if a weekend, 440 cfs if a weekday
    if filtered_pulsing_pump.loc[filtered_pulsing_pump.index == one_date, "day_of_week"].values[0] in ["Saturday", "Sunday"]:
        # weekend
        filtered_pulsing_pump.loc[filtered_pulsing_pump.index > one_date, "pump_cfs_m1"] = weekend_flow
    else:
        # weekday
        filtered_pulsing_pump.loc[filtered_pulsing_pump.index > one_date, "pump_cfs_m1"] = weekday_flow
    
    # m2 for the first day will be m2 from the control data
    filtered_pulsing_pump.loc[filtered_pulsing_pump.index == one_date, "pump_cfs_m2"] = filtered_data.loc[one_date, "pump_cfs_m2"]
    # m2 for the second day will be m2 from the control data
    filtered_pulsing_pump.loc[filtered_pulsing_pump.index == one_date + pd.Timedelta(days=1), "pump_cfs_m2"] = filtered_data.loc[one_date + pd.Timedelta(days=1), "pump_cfs_m2"]
    # m2 will be 220 cfs after the second day if a weekend, 440 cfs if a weekday
    if filtered_pulsing_pump.loc[filtered_pulsing_pump.index > one_date + pd.Timedelta(days=1), "day_of_week"].values[0] in ["Saturday", "Sunday"]:
        # weekend
        filtered_pulsing_pump.loc[filtered_pulsing_pump.index > one_date + pd.Timedelta(days=1), "pump_cfs_m2"] = weekend_flow
    else:
        # weekday
        filtered_pulsing_pump.loc[filtered_pulsing_pump.index > one_date + pd.Timedelta(days=1), "pump_cfs_m2"] = weekday_flow

    # m3 for the first day will be m3 from the control data
    filtered_pulsing_pump.loc[filtered_pulsing_pump.index == one_date, "pump_cfs_m3"] = filtered_data.loc[one_date, "pump_cfs_m3"]
    # m3 for the second day will be m3 from the control data
    filtered_pulsing_pump.loc[filtered_pulsing_pump.index == one_date + pd.Timedelta(days=1), "pump_cfs_m3"] = filtered_data.loc[one_date + pd.Timedelta(days=1), "pump_cfs_m3"]
    # m3 for the third day will be m3 from the control data
    filtered_pulsing_pump.loc[filtered_pulsing_pump.index == one_date + pd.Timedelta(days=2), "pump_cfs_m3"] = filtered_data.loc[one_date + pd.Timedelta(days=2), "pump_cfs_m3"]
    # m3 will be 220 cfs after the third day if a weekend, 440 cfs if a weekday
    if filtered_pulsing_pump.loc[filtered_pulsing_pump.index > one_date + pd.Timedelta(days=2), "day_of_week"].values[0] in ["Saturday", "Sunday"]:
        # weekend
        filtered_pulsing_pump.loc[filtered_pulsing_pump.index > one_date + pd.Timedelta(days=2), "pump_cfs_m3"] = weekend_flow
    else:
        # weekday
        filtered_pulsing_pump.loc[filtered_pulsing_pump.index > one_date + pd.Timedelta(days=2), "pump_cfs_m3"] = weekday_flow  

    return filtered_pulsing_pump

def make_forecast(features, model, model_number, forecast_date, valid_date):
    # drop fore_date
    features = features.drop(columns = "forecast_date")
    features = np.array(features, dtype = np.float32)
    # check for NaN's
    if np.isnan(features).any():
        raise ValueError(f"NaNs found in model input for model {model_number} on {valid_date}")

    # get the model name from the models object
    preds = model.predict(features)
    temp_df = pd.DataFrame(preds, columns=['mean_1m_temp_degC', 'mean_0_5m_temp_degC'])
    for col in temp_df.columns:
        temp_df[col] = (temp_df[col])
    temp_df['model'] = model_number
    temp_df['valid_date'] = valid_date
    temp_df['forecast_date'] = forecast_date
    return temp_df

def rollout_forecast(data, fore_date, m1, m2, m3, m4):
    fore_date = pd.to_datetime(fore_date)
    data["forecast_date"] = pd.to_datetime(data["forecast_date"])
    filtered_data = data[data["forecast_date"] == fore_date].copy()

    all_model_outputs = []

    model_map = {"1": m1, "2": m2, "3": m3, "4": m4}
    forecasted_lookup = {model_num: {} for model_num in model_map}

    for model_num, model in model_map.items():
        for day_offset in range(7):
            val_date = fore_date + pd.Timedelta(days=day_offset)
            data_for_model = filtered_data.loc[filtered_data.index == val_date].copy()

            # Use the prior day's forecasted value
            if day_offset > 0:
                prior_day = val_date - pd.Timedelta(days=1)
                prior_vals = forecasted_lookup[model_num].get(prior_day)

                if prior_vals is not None:
                    for col in ["mean_1m_temp_degC", "mean_0_5m_temp_degC"]:
                        data_for_model[f"{col}_m1"] = prior_vals[col]

            # Only proceed if we have data for the current val_date
            if data_for_model.empty:
                continue

            forecast_df = make_forecast(data_for_model, model, model_num, fore_date, val_date)
            all_model_outputs.append(forecast_df)

            # Store this forecast for future lag features
            forecasted_lookup[model_num][val_date] = forecast_df.iloc[0]

    return pd.concat(all_model_outputs, ignore_index=True)


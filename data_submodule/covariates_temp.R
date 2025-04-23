covariates_temp <- list(
  
  ## climate data ----
  
  # for the purposes of this application, we'll pull in just the Shadow Mountain
  # Reservoir met data. 

  # list the parameters we're interested in to map over
  tar_target(
    name = met_parameters,
    command = c("Air_Temperature_Avg", 
                "Air_Temperature_Min",
                "Air_Temperature_Max", 
                "Wind_Speed_Avg",
                "Wind_Speed_Max",
                "Solar_Radiation_Total",
                "Precipitation_Difference_In_Accumulative_WB")
  ),
  
  # get the timeseries info to iterate over
  tar_target(
    name = met_ts_info,
    command = get_kisters_ts_info(
      station_no = "NW352",
      params = met_parameters,
      final = TRUE
    ),
    packages = c("tidyverse", "httr2", "rvest"),
    pattern = map(met_parameters)
  ),
  
  # download the data using the ts_id/timeseries info
  tar_target(
    name = met_raw,
    command = get_kisters_ts_data(
      station = "NW352",
      ts_id = met_ts_info$ts_id,
      param = met_ts_info$stationparameter_name,
      start_date = "2024-04-01",
      end_date = "2024-11-01" 
    ),
    pattern = map(met_ts_info),
    packages = c("tidyverse", "httr2", "rvest")
  ),
  
  # we need daily summaries of these for the model
  tar_target(
    name = met_daily,
    command = {
      # summarize by day
      SMR_met_daily <- met_raw %>%
        mutate(date = ymd(as.POSIXct(datetime, tz = "Etc/GMT+7")),
               value = as.numeric(value)) %>% 
        filter(!is.na(date)) %>% 
        pivot_wider(names_from = parameter,
                    values_from = value) %>% 
        # summarize and convert to metric units
        summarise(# deg F to deg C
          SMR_max_temp_degC = (max(Air_Temperature_Max, na.rm = T) - 32) * 5/9,
          SMR_min_temp_degC = (min(Air_Temperature_Min, na.rm = T) - 32) * 5/9,
          SMR_mean_temp_degC = (mean(Air_Temperature_Avg, na.rm = T) - 32) * 5/9, # not ideal to grab average of average, but it'll do
          # inches to mm
          SMR_tot_precip_mm = sum(Precipitation_Difference_In_Accumulative_WB, na.rm = T) * 2.54 * 100,
          # calories per cm2 to watts per m2
          SMR_tot_sol_rad_Wpm2 = sum(Solar_Radiation_Total, na.rm = T) * 11.63,
          # miles per hour to meters per second
          SMR_min_wind_mps = min(Wind_Speed_Avg, na.rm = T) / 2.237, # not ideal to do get min from average speed, but it's what we've got
          SMR_max_wind_mps = max(Wind_Speed_Max, na.rm = T) / 2.237,
          SMR_mean_wind_mps = mean(Wind_Speed_Avg, na.rm = T) / 2.237,
          .by = date) 
      # get summary of non-na data
      SMR_met_count <- met_raw %>% 
        mutate(date = ymd(as.POSIXct(datetime, tz = "Etc/GMT+7"))) %>% 
        group_by() %>% 
        summarise(n = n(),
                  .by = c(date, parameter)) %>% 
        pivot_wider(names_from = parameter,
                    values_from = n)
      # join together for target output
      left_join(SMR_met_daily, SMR_met_count)
    }
  ), 
  
  ## forecast data ----
  
  # we're going to deal with this later. This is a bit of a beesnest - I can't
  # just plug in the NOAA GEFS data because it needs to be debiased (aka, it might
  # have systematic issues, which is very likely because of the scale/resolution 
  # of GEFS 0.25deg modeled and this is a topographically-complex area which will
  # affect transferability.
    
  ## SMR temperature ----
  
  # download the data using the ts_id/timeseries info, separate for temperature
  # and depth of sensor
  tar_target(
    name = SMR_MID_temp,
    command = {
      SMR_MID_water_temp <- get_kisters_ts_data(
        station = "18525",
        ts_id = "28408010",
        param = "WT",
        start_date = "2024-04-01",
        end_date = "2024-11-01",
        datasource = 1) %>% 
        select(datetime, temp_degC = value) %>% 
        mutate(temp_degC = as.numeric(temp_degC)) %>% 
        filter(between(temp_degC, -5, 30))
      SMR_MID_sensor_depth <- get_kisters_ts_data(
        station = "18525",
        ts_id = "28400010",
        param = "Depth",
        start_date = "2024-04-01",
        end_date = "2024-11-01",
        datasource = 1) %>% 
        select(datetime, depth_m = value) %>% 
        mutate(depth_m = as.numeric(depth_m)) %>% 
        filter(depth_m <= 7.5) # QA measure
      full_join(SMR_MID_water_temp, 
                SMR_MID_sensor_depth)
    }, 
    packages = c("tidyverse", "httr2", "rvest")
  ),
  
  # aggregate to values for model (near surface (<= 1m) or integrated depth (0-5m))
  tar_target(
    name = SMR_daily,
    command = {
      SMR_daily_near_surface <- SMR_MID_temp %>% 
      filter(depth_m <= 1) %>% 
      mutate(date = ymd(format(as.POSIXct(datetime, tz = "Etc/GMT+5"), "%Y-%m-%d"))) %>% 
      summarize(mean_temp_ns = mean(temp_degC),
                n = n(),
                .by = date) %>% 
      filter(n >= 5) # make sure obs are complete (or nearly), measurement occurs 
    #every ~4h and there is generally only one measurement < 1m per measurement
      SMR_daily_integrated <- SMR_MID_temp %>% 
        filter(depth_m <= 5) %>% 
        mutate(date = ymd(format(as.POSIXct(datetime, tz = "Etc/GMT+5"), "%Y-%m-%d"))) %>% 
        summarize(mean_temp_int = mean(temp_degC),
                  .by = date) 
      left_join(SMR_daily_near_surface, SMR_daily_integrated)
    }
  ),

  # do a quick sanity check
  tar_target(
    name = SMR_daily_graph,
    command = SMR_daily %>% 
      pivot_longer(cols = c(mean_temp_ns, mean_temp_int), 
                   names_to = 'depth', values_to = 'value') %>% 
      mutate(depth = factor(depth, levels = c("mean_temp_ns", "mean_temp_int"))) %>% 
      ggplot(., aes(x = date, y = value, color = depth)) + 
      geom_point() +
      theme_bw() +
      scale_color_viridis_d(end = 0.5, name = NULL, labels = c("near surface depth (0-1m)", "integrated depth (0-5m)")) +
      theme(legend.position = "bottom") +
      labs(x = NULL, y = "mean daily water temperature (deg C)")
  )
  
)

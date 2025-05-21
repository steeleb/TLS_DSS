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
                "Relative_Humidity_Avg", # in place of precip, because the record is
                # incomplete
                "Solar_Radiation_Total")
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
  
  # do a cursory QAQC
  tar_target(
    name = met_QAQC,
    command = {
      met_raw %>% 
        mutate(datetime = ymd_hms(datetime, tz = "MST"),
               value = as.numeric(value)) %>% 
        filter(!is.na(value)) %>% 
        # both rain bits are incomplete AND Rain Total is all 0s
        filter(!(parameter %in% c("Rain_Total", "Precipitation_Difference_In_Accumulative_WB"))) %>% 
        # out of bounds
        mutate(value = case_when(grepl("Air", parameter) & (value < -50 | value > 100) ~ NA_real_,
                                 grepl("Humidity", parameter) & value < 0 ~ NA_real_,
                                 .default = value)) %>% 
        # wonky reporting
        pivot_wider(names_from = parameter,
                    values_from = value) %>% 
        # make sure that min/max/avg are sensical
        mutate(across(c(Air_Temperature_Avg, Air_Temperature_Max, Air_Temperature_Min),
                      ~ if_else(Air_Temperature_Avg > Air_Temperature_Max |
                                  Air_Temperature_Avg < Air_Temperature_Min,
                                NA_real_,
                                .))) %>% 
        pivot_longer(cols = !datetime,
                     names_to = "parameter",
                     values_to = "value")
    }
  ),
  
  # we need daily summaries of these for view
  tar_target(
    name = met_daily,
    command = {
      # summarize by day
      met_QAQC %>%
        mutate(date = as_date(datetime)) %>% 
        filter(!is.na(date)) %>% 
        pivot_wider(names_from = parameter,
                    values_from = value) %>% 
        # summarize and convert to metric units
        summarise(
          # deg F to deg C
          max_temp_degC = (max(Air_Temperature_Max, na.rm = T) - 32) * 5/9,
          min_temp_degC = (min(Air_Temperature_Min, na.rm = T) - 32) * 5/9,
          mean_temp_degC = (mean(Air_Temperature_Avg, na.rm = T) - 32) * 5/9, # not ideal to grab average of average, but it'll do
          # just summarize RH
          min_RH_perc = min(Relative_Humidity_Avg, na.rm = T),
          mean_RH_perc = mean(Relative_Humidity_Avg, na.rm = T),
          max_RH_perc = max(Relative_Humidity_Avg, na.rm = T),
          # calories per cm2 to watts per m2
          tot_sol_rad_Wpm2 = sum(Solar_Radiation_Total, na.rm = T) * 11.63,
          # miles per hour to meters per second
          min_wind_mps = min(Wind_Speed_Avg, na.rm = T) / 2.237, # not ideal to do get min from average speed, but it's what we've got
          max_wind_mps = max(Wind_Speed_Max, na.rm = T) / 2.237,
          mean_wind_mps = mean(Wind_Speed_Avg, na.rm = T) / 2.237,
          .by = date) 
    }
  ), 
  
  # save for use in Shiny
  tar_target(
    name = save_met_daily,
    command = write_csv(x = met_daily, file = "DSS_Shiny/www/daily_met.csv")
  ),
  
  
  # and a different summary for modeling
  tar_target(
    name = met_daily_for_model,
    command = {   
      map2(.x = list(c(22, 23, 00), #list of hours
                     c(01, 02, 03),
                     c(04, 05, 06),
                     c(07, 08, 09),
                     c(10, 11, 12),
                     c(13, 12, 15),
                     c(16, 17, 18),
                     c(19, 20, 21),
                     c(22, 23, 00)),
           .y = c("f000", #list of forecasts relative to UTC 06/MT 23
                  "f003",
                  "f006",
                  "f009",
                  "f012",
                  "f015",
                  "f018",
                  "f021",
                  "f024"),
           .f = ~ {
             met_QAQC %>% 
               filter(hour(datetime) %in% .x) %>% 
               # in cases of the control initialization, we need to maniputlate the date to match the following day
               mutate(date = case_when(.y == "f000" & hour(datetime) > 1 ~ as_date(datetime) + days(1),
                                       # and the opposite for the inclusion of time in the next day (00) that should be part of this one
                                       .y == "f024" & hour(datetime) < 1 ~ as_date(datetime) - days(1),
                                       .default = as_date(datetime))) %>% 
               summarize(value = mean(value),
                         .by = c(date, parameter)) %>% 
               filter(parameter %in% c("Air_Temperature_Avg", #t2m
                                       "Relative_Humidity_Avg", # rel humidity as stand-in for precip
                                       "Wind_Speed_Avg", #u10/v10 to wind conversion
                                       "Solar_Radiation_Total")) %>%  #swrf/lwrf
               pivot_wider(names_from = parameter,
                           values_from = value) %>% 
               rename(air_temp = Air_Temperature_Avg,
                      ave_wind = Wind_Speed_Avg,
                      rel_hum = Relative_Humidity_Avg,
                      solar_rad = Solar_Radiation_Total) %>% 
               mutate(fcast = .y)
           }
      ) %>% 
        bind_rows()
    }  
  ), 
  
  # save for use in Shiny
  tar_target(
    name = save_met_daily_model,
    command = write_csv(x = met_daily_for_model, file = "DSS_Shiny/www/daily_met_for_model.csv")
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
        mutate(temp_degC = as.numeric(temp_degC),
               datetime = as_datetime(datetime, tz = "Etc/GMT+7")) %>% 
        filter(between(temp_degC, -5, 30))
      SMR_MID_sensor_depth <- get_kisters_ts_data(
        station = "18525",
        ts_id = "28400010",
        param = "Depth",
        start_date = "2024-04-01",
        end_date = "2024-11-01",
        datasource = 1) %>% 
        select(datetime, depth_m = value) %>% 
        mutate(depth_m = as.numeric(depth_m),
               datetime = as_datetime(datetime, tz = "Etc/GMT+7")) %>% 
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
        mutate(date = as_date(datetime)) %>% 
        summarize(mean_temp_ns = mean(temp_degC),
                  n = n(),
                  .by = date) %>% 
        filter(n >= 5) # make sure obs are complete (or nearly), measurement occurs 
      #every ~4h and there is generally only one measurement < 1m per measurement
      SMR_daily_integrated <- SMR_MID_temp %>% 
        filter(depth_m <= 5) %>% 
        mutate(date = as_date(datetime)) %>% 
        summarize(mean_temp_int = mean(temp_degC),
                  .by = date) 
      left_join(SMR_daily_near_surface, SMR_daily_integrated) %>% 
        select(-n)
    }
  ),
  
  # save for use in Shiny
  tar_target(
    name = save_SMR_daily,
    command = write_csv(x = SMR_daily, file = "DSS_Shiny/www/daily_SMR_temp.csv")
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

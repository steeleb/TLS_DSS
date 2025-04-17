
input_list <- list(
  
  # Farr Pump data
  
  # get tsids for daily pump
  tar_target(
    name = e_granby_daily_pump_tsids,
    command = get_kisters_ts_info(station_no = "EX-0054",
                                  params = "Q_Pump",
                                  datasource = 1),
    packages = c("tidyverse", "httr2", "rvest"),
    cue = tar_cue("always")
  ),
  
  # grab data
  tar_target(
    name = e_granby_daily_pump_data,
    command = get_kisters_ts_data(station = "EX-0054",
                                  ts_id = e_granby_daily_pump_tsids$ts_id,
                                  param = e_granby_daily_pump_tsids$parametertype_name,
                                  start_date = "1952-12-18T00:00:00.000-07:00", # need to input day
                                  end_date = e_granby_daily_pump_tsids$to,
                                  datasource = 1)%>% 
      filter(!is.na(datetime))
  ), 
  
  # add data to file, update target
  tar_target(
    name = e_add_return_data,
    command = add_data_to_file(e_granby_pump_data)
  )
)


temperature = x_SM_MID_daily_temp,
climate = x_SMR_daily_climate_summary,
pump = x_prev_days_pump,
north_fork = x_NF_prev_days_inflow,
chipmunk = x_chipmunk_daily,
outlet = x_outlet_daily,
elevation = x_SMR_daily_elev

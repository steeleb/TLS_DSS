
input_list <- list(
  
  # Farr Pump data
  
, 
  
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

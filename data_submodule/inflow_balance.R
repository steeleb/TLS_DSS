inflow_water_balance <- list(
  
  # use {dataRetrieval} to get data for the Chipmunk Lane - this is the 
  # passageway between Grand and SM
  tar_target(
    name = chipmunk_raw,
    command = get_NWIS_data_by_site(site_number = "09014050", 
                                    start_date = "2024-01-01T00:00",
                                    end_date = "2024-12-31T00:00",
                                    tz = "MST"),
    packages = c("tidyverse", "dataRetrieval")
  ),
  
  # and pass the harmonize function to re-orient data
  tar_target(
    name = chipmunk,
    command = harmonize_NWIS_stream(e_chipmunk_raw),
    packages = "tidyverse"
  ),
  
  # get tsids for daily pump
  tar_target(
    name = ,
    command = get_kisters_ts_info(station_no = "EX-0054",
                                  params = "Q_Pump",
                                  datasource = 1),
    packages = c("tidyverse", "httr2", "rvest"),
    cue = tar_cue("always")
  ),
  
  # add data to file, update target
  tar_target(
    name = ,
    command = add_data_to_file(e_granby_pump_data)
  ),
  
  # grab data
  tar_target(
    name = ,
    command = get_kisters_ts_data(station = "EX-0054",
                                  ts_id = $ts_id,
                                  param = $parametertype_name,
                                  start_date = "2024-01-01",
                                  end_date = e_granby_daily_pump_tsids$to,
                                  datasource = 1)%>% 
      filter(!is.na(datetime))
  ), 
  
  
)
tar_source("data_submodule/src/")

inflow_water_balance <- list(
  
  # inflow for this system is defined by Grand Lake's North Inlet and East Inlet
  # and Shadow Mountain Reservoir's North Fork of the Colorado River.
  
  ## North Fork Colorado River above Shadow Mountain (Northern Water) ----
  
  # get the tsid for the Q data
  tar_target(
    name = northfork_tsids,
    command = get_kisters_ts_info(station_no = "M-0009",
                                  params = "Q"),
    packages = c("tidyverse", "httr2", "rvest"),
    cue = tar_cue("always")
  ),
  
  # grab the daily data from Kisters data service
  tar_target(
    name = northfork_daily,
    command = get_kisters_ts_data(station = "M-0009",
                                  ts_id = northfork_tsids$ts_id[2],
                                  param = northfork_tsids$ts_name[2],
                                  start_date = "2024-01-01",
                                  end_date = northfork_tsids$to[2]) %>% 
      filter(!is.na(datetime)),
    packages = c("tidyverse", "httr2", "rvest")
  ),
  
  ## Chipmunk Lane (USGS) ----
  
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
    command = harmonize_NWIS_stream(chipmunk_raw),
    packages = "tidyverse"
  )
)
#   
#   # get tsids for daily pump
#   tar_target(
#     name = ,
#     command = get_kisters_ts_info(station_no = "EX-0054",
#                                   params = "Q_Pump",
#                                   datasource = 1),
#     packages = c("tidyverse", "httr2", "rvest"),
#     cue = tar_cue("always")
#   ),
#   
#   # add data to file, update target
#   tar_target(
#     name = ,
#     command = add_data_to_file(e_granby_pump_data)
#   ),
#   
#   # grab data
#   tar_target(
#     name = ,
#     command = get_kisters_ts_data(station = "EX-0054",
#                                   ts_id = $ts_id,
#                                   param = $parametertype_name,
#                                   start_date = "2024-01-01",
#                                   end_date = e_granby_daily_pump_tsids$to,
#                                   datasource = 1)%>% 
#       filter(!is.na(datetime))
#   ), 
#   
#   
# )
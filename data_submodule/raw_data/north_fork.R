# Source functions for this {targets} list
tar_source("data_submodule/raw_data/src/")

north_fork <- list(
  tar_target(
    name = northfork_tsids,
    command = get_kisters_ts_info(station_no = "M-0009",
                                params = "Q"),
    packages = c("tidyverse", "httr2", "rvest"),
    cue = tar_cue("always")
  ),
  
  # grab the data from Kisters. For now, just grabbing the daily data, as the 
  # instantaneous data is too big for this function.
  tar_target(
    name = northfork_daily,
    command = get_kisters_ts_data(station = "M-0009",
                                  ts_id = northfork_tsids$ts_id[2],
                                  param = northfork_tsids$ts_name[2],
                                  start_date = "2026-05-15",
                                  end_date = northfork_tsids$to[2]) %>% 
      filter(!is.na(datetime)) %>% 
      mutate(date = ymd(as.POSIXct(datetime, tz = "Etc/GMT+7")),
             value = as.numeric(value)),
    packages = c("tidyverse", "httr2", "rvest")
  )
)
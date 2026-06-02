# Source functions for this {targets} list
tar_source("data_submodule/raw_data/src/")

east_inlet <- list(
  tar_target(
    name = grand_east_inlet_tsid,
    command = get_kisters_ts_info(station_no = "FS-0020",
                                final = TRUE,
                                params = "Q",
                                datasource = 1),
    packages = c("tidyverse", "httr2", "rvest"),
    cue = tar_cue("always")
  ),

  # there are two files here, we want the instantaneous to match with NI (the first one), so 
  # specifying in the function arguments
  tar_target(
    name = grand_east_inlet_daily,
    command = get_kisters_ts_data(station = grand_east_inlet_tsid$station_no[2],
                                  ts_id = grand_east_inlet_tsid$ts_id[2],
                                  param = grand_east_inlet_tsid$stationparameter_name[2],
                                  start_date = "2026-05-15",
                                  end_date = grand_east_inlet_tsid$to[2],
                                  datasource = 1) %>% 
      mutate(date = format(ymd_hms(datetime), "%Y-%m-%d"),
             q_cfs = as.numeric(value)) %>% 
      select(-c(datetime, value)),
    packages = c("httr2", "rvest", "tidyverse")
  )
)
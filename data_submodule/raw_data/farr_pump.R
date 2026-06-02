# Source functions for this {targets} list
tar_source("data_submodule/raw_data/src/")

farr_pump_tar <- list(
  tar_target(
    name = granby_daily_pump_tsids,
    command = get_kisters_ts_info(station_no = "EX-0054",
                                  params = "Q_Pump",
                                  datasource = 1),
    packages = c("tidyverse", "httr2", "rvest"),
    cue = tar_cue("always")
  ),
  
  tar_target(
    name = granby_daily_pump_data,
    command = get_kisters_ts_data(station = "EX-0054",
                                  ts_id = granby_daily_pump_tsids$ts_id,
                                  param = granby_daily_pump_tsids$parametertype_name,
                                  start_date = "2026-05-15",
                                  end_date = granby_daily_pump_tsids$to,
                                  datasource = 1) %>% 
      filter(!is.na(datetime)) %>% 
      mutate(date = ymd(as.POSIXct(datetime, tz = "Etc/GMT+7")),
             value = as.numeric(value)),
    packages = c("tidyverse", "httr2", "rvest"),
  ),

  tar_target(
    name = granby_daily_pump_data_csv,
    command = {
      path <- "data_submodule/raw_data/target_output/granby_daily_pump_data.csv"
      dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
      write_csv(granby_daily_pump_data, path)
      path
    },
    format = "file",
    packages = "readr"
  )
)

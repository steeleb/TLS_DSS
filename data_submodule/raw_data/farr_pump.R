# Source functions for this {targets} list
tar_source("data_submodule/raw_data/src/")

farr_pump_tar <- list(
  tar_target(
    name = granby_daily_pump_tsids,
    command = get_kisters_ts_info(station_no = "EX-0054",
                                  params = "Q_Pump",
                                  datasource = 1),
    packages = c("httr2", "rvest", "dplyr"),
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
    packages = c("httr2", "rvest", "dplyr", "purrr", "lubridate"),
  ),
  
  # ---- Sub-daily (hf) supplement from SC-0017 for dates missing from daily ----
  tar_target(
    name = granby_hf_pump_tsids,
    command = get_kisters_ts_info(station_no = "SC-0017",
                                  params = "Q-Pump_Total",
                                  datasource = 1,
                                  raw = TRUE),
    packages = c("httr2", "rvest", "dplyr"),
    cue = tar_cue("always")
  ),
  
  tar_target(
    name = granby_pump_supplement_start,
    command = {
      last_date <- max(granby_daily_pump_data$date[!is.na(granby_daily_pump_data$value)])
      format(last_date + days(1), "%Y-%m-%d")
    },
    packages = "lubridate"
  ),
  
  tar_target(
    name = granby_hf_pump_data,
    command = get_kisters_ts_data(station = "SC-0017",
                                  ts_id = granby_hf_pump_tsids$ts_id,
                                  param = granby_hf_pump_tsids$ts_name,
                                  start_date = granby_pump_supplement_start,
                                  end_date = granby_hf_pump_tsids$to,
                                  datasource = 1) %>%
      filter(!is.na(datetime)) %>%
      mutate(date = ymd(as.POSIXct(datetime, tz = "Etc/GMT+7")),
             value = as.numeric(value)),
    packages = c("httr2", "rvest", "dplyr", "purrr", "lubridate"),
  ),
  
  tar_target(
    name = granby_hf_pump_daily,
    command = granby_hf_pump_data %>%
      filter(date < Sys.Date()) %>%
      summarize(value = mean(value, na.rm = TRUE),
                .by = "date") %>%
      mutate(value = round(value, digits = 0),
             datetime = paste0(as.character(date), "T00:00:00.000-07:00")),
    packages = "dplyr"
  ),
  
  tar_target(
    name = granby_daily_pump_data_csv,
    command = {
      path <- "data_submodule/raw_data/target_output/granby_daily_pump_data.csv"
      dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
      bind_rows(granby_daily_pump_data %>% filter(!is.na(value)), 
                granby_hf_pump_daily) %>%
        write_csv(path)
      path
    },
    format = "file",
    packages = c("readr", "dplyr"),
    cue = tar_cue(file = FALSE)
  )
)
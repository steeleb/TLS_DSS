# Source functions for this {targets} list
tar_source("data_submodule/raw_data/src/")

north_inlet_tar <- list(
  tar_target(
    name = grand_north_inlet_tsid,
    command = get_kisters_ts_info(station_no = "FS-0046",
                                  final = TRUE,
                                  params = "Q",
                                  datasource = 1),
    packages = c("httr2", "rvest", "dplyr"),
    cue = tar_cue("always")
  ),
  
  tar_target(
    name = grand_north_inlet_daily,
    command = get_kisters_ts_data(station = grand_north_inlet_tsid$station_no[2],
                                  ts_id = grand_north_inlet_tsid$ts_id[2],
                                  param = grand_north_inlet_tsid$stationparameter_name[2],
                                  start_date = "2026-05-15",
                                  end_date = grand_north_inlet_tsid$to[2],
                                  datasource = 1) %>% 
      mutate(date = format(ymd_hms(datetime), "%Y-%m-%d"),
             q_cfs = as.numeric(value)) %>% 
      select(-c(datetime, value)),
    packages = c("httr2", "rvest", "dplyr", "purrr", "lubridate")
  ),

  tar_target(
    name = grand_north_inlet_daily_csv,
    command = {
      path <- "data_submodule/raw_data/target_output/grand_north_inlet_daily.csv"
      dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
      write_csv(grand_north_inlet_daily, path)
      path
    },
    format = "file",
    packages = "readr",
    cue = tar_cue(file = FALSE)
  )
)

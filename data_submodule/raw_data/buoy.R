# Source functions for this {targets} list
tar_source("data_submodule/raw_data/src/")

buoy_tar <- list(
  tar_target(
    name = SM_MID_buoy_tsid,
    command = get_kisters_ts_info(station = "FS-0081", 
                                  datasource = 1),
    packages = c("httr2", "rvest", "tidyverse"),
    cue = tar_cue("always") # want to make sure this always updates
  ),
  
  tar_target(
    name = SM_MID_buoy,
    command = get_kisters_ts_data(station = "FS-0081", 
                                  ts_id = SM_MID_buoy_tsid$ts_id, 
                                  param = SM_MID_buoy_tsid$stationparameter_name, 
                                  start_date = "2026-05-15", 
                                  end_date = SM_MID_buoy_tsid$to, 
                                  datasource = 1) %>% 
      mutate(parameter = SM_MID_buoy_tsid$stationparameter_name),
    pattern = map(SM_MID_buoy_tsid),
    packages = c("httr2", "rvest", "tidyverse")
  ),
  
  # clean data using out-of-range settings and any errant data 
  tar_target(
    name = SM_MID_L1,
    command = {
      # need to reformat to how this was when we created the cleaning function
      reformatted_buoy <- SM_MID_buoy %>% 
        mutate(value = as.numeric(value)) %>% 
        pivot_wider(names_from = parameter,
                    values_from = value) %>% 
        rename(do_mgl = DO,
               cond_uscm = EC,
               temp_C = WT,
               turb_NTU = WTb, 
               chla_RFU = Chlorophyll_A_RFU,
               bgalgae_RFU = BGAlgae_RFU,
               depth_m = Depth) %>% 
        mutate(dateTime = as_datetime(datetime, tz = "Etc/GMT+7"),
               location = "SM-MID") %>% 
        select(-datetime)
      clean_SM_MID(SM_MID_data = reformatted_buoy, 
                   yml_path = "data_submodule/raw_data/oob_cfg.yml")
    },
    packages = c("data.table", "tidyverse", "yaml")
  ),

  tar_target(
    name = SM_MID_L1_csv,
    command = {
      path <- "data_submodule/raw_data/target_output/SM_MID_L1.csv"
      dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
      write_csv(SM_MID_L1, path)
      path
    },
    format = "file",
    packages = "readr"
  )
)

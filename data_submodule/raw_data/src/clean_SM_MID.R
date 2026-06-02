#' QAQC of Shadow Mountain Reservoir buoy data at the mid location
#' 
#' @description
#' This function uses findings from the QAQC file `programs/sensor-workspace/SM-MID_highlievel_QAQC.Rmd`
#' to create a single function to remove and or recode obviously errant data within
#' the SM-MID raw file from Northern Water See the file
#' `programs/sensor-workspace/SM-MID_highlevel_QAQC.html` for rendered file with
#' figures.
#' 
#' @param SM_MID_data dataframe; data from Shadow Mounatin Reservoir MID Buoy,
#' which comes directly from NW.
#' @param yml_path filepath; filepath to the out-of-range config yaml file for SMR
#' 
#' @returns dataframe with basic QAQC for obviously errant data (level 1/L1) 
#' completed
#' 
clean_SM_MID <- function(SM_MID_data, yml_path){
  
  # load the out-of-range config for Shadow Mountain MID buoy
  oob_cfg <- read_yaml(yml_path)
  
  # load the parameter list for Shadow Mountain MID buoy
  param_list <- c("do_mgl",
                  "cond_uscm",
                  "temp_C",
                  "turb_NTU",
                  "pH",
                  "bgalgae_RFU",
                  "chla_RFU")
  
  
  # recode out-of-range data and create L1 dataset ------------------------------
  
  # apply `recode_oob()` (stored in buoy_oob_functions.R) to recode out-of-range
  # values to NA
  SMM_L1_vert <- pmap(.l = list(data = list(SM_MID_data),
                                param = param_list, 
                                res = list("SM_MID"),
                                limits = list(oob_cfg)), 
                      .f = recode_oob) %>% 
    bind_rows() 
  
  # apply `drop_depth_oob()` (stored in buoy_oob_functions.R) to drop any 
  # measurements made in sediment (beyond max depth of reservoir)
  SMM_L1_vert <- drop_depth_oob(data = SMM_L1_vert, 
                                res = "SM_MID",
                                limits = oob_cfg)
  
  SMM_L1 <- SMM_L1_vert %>% 
    pivot_wider(names_from = "parameter",
                values_from = "value") 
  
  # deal with any other problematic data ---------------------------
  # these are outliers from the QAQC .Rmd and or data that needed to be flagged
  # or recoded
  
  ## add flag columns ----
  SMM_L1 <- SMM_L1 %>% 
    add_column(flag_gen = "",
               flag_do = "",
               flag_cond = "",
               flag_temp = "",
               flag_turb = "",
               flag_pH = "",
               flag_bga = "",
               flag_chla = "")
  
  ## 2014 ----
  SMM_L1 <- SMM_L1 %>% 
    mutate(do_mgl = if_else(dateTime < ymd("2014-06-30") &
                              year(dateTime) == 2014,
                            NA_real_,
                            do_mgl),
           across(all_of(param_list),
                  ~ if_else(dateTime >= ymd("2014-10-01") &
                              year(dateTime) == 2014,
                            NA_real_,
                            .)))
  
  ## 2015 ----
  SMM_L1 <- SMM_L1 %>% 
    mutate(across(all_of(param_list),
                  ~ if_else(dateTime < ymd("2015-06-20") &
                              year(dateTime) == 2015,
                            NA_real_,
                            .)),
           flag_pH = if_else(year(dateTime) == 2015,
                             "calibration artifacts?",
                             flag_pH))
  
  ## 2016 ----
  SMM_L1 <- SMM_L1 %>% 
    mutate(across(all_of(param_list),
                  ~ if_else(dateTime >= ymd("2016-10-04") &
                              year(dateTime) == 2016,
                            NA_real_,
                            .)),
           flag_turb = if_else(year(dateTime) == 2016, 
                               "calibration artifacts?",
                               flag_turb))
  
  
  ## 2017 ----
  SMM_L1 <- SMM_L1 %>% 
    mutate(across(all_of(param_list),
                  ~ if_else(between(dateTime, 
                                    ymd("2017-06-05"),
                                    ymd("2017-06-12")),
                            NA_real_,
                            .)),
           across(all_of(param_list),
                  ~ if_else(between(dateTime, 
                                    ymd_hm("2017-06-19 00:00", tz = "Etc/GMT+7"),
                                    ymd_hm("2017-06-19 12:00", tz = "Etc/GMT+7")),
                            NA_real_,
                            .)), 
           across(all_of(param_list),
                  ~ if_else(year(dateTime) == 2017 &
                              dateTime >= ymd("2017-10-01"),
                            NA_real_,
                            .)))
  
  ## interpolate depth for 2018 and 2019 ----
  # deal with no depth in chla parameters
  interpolate_depth_by_year <- function(year) {
    df <- SMM_L1 %>% 
      filter(year(dateTime) == year) 
    df_complete <- df %>% 
      filter(!is.na(depth_m))
    interpolation =  approxfun(x = df_complete$dateTime, 
                               y = df_complete$depth_m, 
                               method = "linear")
    df$depth_m_i = interpolation(df$dateTime)
    df
  }
  
  SMM_L1_18_19 <- map(2018:2019, interpolate_depth_by_year) %>% 
    bind_rows() %>% 
    mutate(flag_depth = if_else(is.na(depth_m),
                                "interpolated",
                                NA_character_),
           depth_m = if_else(is.na(depth_m),
                             depth_m_i,
                             depth_m)) %>% 
    select(-depth_m_i)
  
  SMM_L1_not18_19 <- SMM_L1 %>% 
    filter(year(dateTime) %notin% 2018:2019)
  
  SMM_L1 <- full_join(SMM_L1_18_19, SMM_L1_not18_19)
  
  ## 2018 ----
  SMM_L1 <- SMM_L1 %>% 
    mutate(turb_NTU = if_else(year(dateTime) == 2018 & turb_NTU > 10,
                              NA_real_,
                              turb_NTU),
           flag_turb = if_else(year(dateTime) == 2018 &
                                 dateTime >= ymd("2018-07-14"),
                               "calibration artifacts?",
                               flag_turb))
  
  ## 2019 ----
  SMM_L1 <- SMM_L1 %>% 
    mutate(across(all_of(param_list),
                  ~ if_else(dateTime < ymd("2019-07-09") &
                              year(dateTime) == 2019,
                            NA_real_,
                            .)),
           do_mgl = if_else(dateTime > ymd("2019-09-25") & 
                              year(dateTime) == 2019 &
                              do_mgl < 6,
                            NA_real_, 
                            do_mgl),
           across(c(flag_turb, flag_chla, flag_bga),
                  ~ if_else(year(dateTime) == 2019,
                            "calibration artifacts?",
                            .)))
  
  ## 2020 ----
  SMM_L1 <- SMM_L1 %>% 
    mutate(across(c(flag_bga, flag_chla),
                  ~ if_else(year(dateTime) == 2020,
                            "calibration artifacts?",
                            .)))
  
  ## 2021 ----
  SMM_L1 <- SMM_L1 %>% 
    mutate(across(all_of(param_list),
                  ~ if_else(dateTime < ymd_hm("2021-05-25 18:00", tz = "Etc/GMT+7") &
                              year(dateTime) == 2021,
                            NA_real_,
                            .)))
  
  ## 2022 ----
  # no further QAQC necessary
  
  ## 2023 ----
  # no further QAQC necessary
  
  ## 2024 ----
  # no further QAQC necessary
  
  ## 2025 ----
  # no further QAQC necessary
  
  # return level 1 horizontal data ------------------------------------------
  SMM_L1
}

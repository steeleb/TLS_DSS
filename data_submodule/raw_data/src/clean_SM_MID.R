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
  
  # return level 1 horizontal data ------------------------------------------
  SMM_L1
}

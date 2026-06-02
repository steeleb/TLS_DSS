#' @title Harmonize NWIS stream data
#' 
#' @description
#' Quick function to re-orient data from horizontal with terrible column
#' names to vertical with harmonized names and flags
#' 
#' @param NWIS_stream_data dataframe; data obtained using the 
#' `get_NWIS_data_by_site()` function (d_buoy_data_harmonization/src/)
#' 
#' @returns vertically-oriented dataframe with harmonized names
#' 
harmonize_NWIS_stream <- function(NWIS_stream_data) {
  
  ## reorg data -----
  # get values as a vertical dataset
  NWIS_values <- NWIS_stream_data %>% 
    select(dateTime, ends_with("_Inst")) 
  
  # get parameter names
  params <- names(NWIS_values) %>% 
    # just grab names of parameters
    .[2:length(.)]
  
  params_short = str_sub(params, end = -6)
  
  # pivot to vertical
  NWIS_values_vert <- NWIS_values %>% 
    rename_with(~ str_sub(., end = -6),
                ends_with("_Inst")) %>% 
    pivot_longer(cols = all_of(params_short),
                 names_to = "parameter",
                 values_to = "value") 
  
  # get flags using a similar method
  NWIS_flags <- NWIS_stream_data %>% 
    select(dateTime, ends_with("_cd"), -agency_cd, -tz_cd)
  param_flags <- names(NWIS_flags) %>% 
    .[2:length(.)]
  
  flags_short <- str_sub(param_flags, end = -9)
  
  NWIS_flags_vert <- NWIS_flags %>% 
    rename_with(~ str_sub(., end = -9),
                ends_with("_cd")) %>% 
    pivot_longer(cols = all_of(flags_short),
                 names_to = "parameter",
                 values_to = "code") 
  
  # rename parameters so everything plays well together
  NWIS_out <- full_join(NWIS_values_vert, NWIS_flags_vert) %>% 
    mutate(parameter = case_when(parameter == "Wtemp" ~ "temp_C",
                                 parameter == "DO" ~ "do_mgl",
                                 parameter == "SpecCond" ~ "specCond_uscm",
                                 parameter == "Turb" ~ "turb_NTU",
                                 parameter == "Flow" ~ "flow_cfs",
                                 parameter == "GH" ~ "gauge_ht_ft",
                                 TRUE ~ parameter)) %>% 
    filter(!is.na(value))
  
  # most of the NWIS data are fine as-is, and preliminary data are usually just
  # the previous year. based on a quick vis, I'm advocating that we use these
  # as-is without further QAQC. 
  
  ## return the harmonized data ----
  NWIS_out
}
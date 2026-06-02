# Out-of-range functions used in buoy cleaning

#' @title Recode out-of-bounds data by parameter using the reservoir configuration yaml
#' 
#' @description
#' This function recodes any data per parameter that are outside of the normal
#' limits defined in the configuration yaml.
#' 
#' @param data dataframe; horizontal dataframe with columns of 'dateTime' and 
#' 'value', each parameter is in a separate columns
#' @param param character string; parameter to pass the value limits to for 
#' recoding
#' @param res character string; reservoir name where parameter was measured
#' @param limits list; yaml list of out-of-range setttings
#' 
#' @return dataframe of filtered data, where out-of-range values have been 
#' recoded
#' 
recode_oob <- function(data, param, res, limits) {
  # get limits from the config file
  limit_min = limits[[param]][[res]]$limit_min
  limit_max = limits[[param]][[res]]$limit_max
  # store the parameter as a symbol for selection
  p <- sym(param)
  # create a dataframe with a single column for the parameter of interest
  df <- data %>% 
    select(all_of(p)) %>% 
    mutate(oob = if_else(between({{ p }}, limit_min, limit_max), 
                         {{ p }},
                         NA_real_)) 
  # place the recoded data back into the column of origin
  data[param] <- df$oob
  # return data frame of datetime, depth, and parameter with recoded values dropped
  data %>% 
    select(dateTime, 
           depth_m, 
           value = all_of(param)) %>% # truly don't understand, but gotta wrap param
    # to keep dplyr happy
    mutate(parameter = param) %>% 
    # there are some oddballs in here that create duplicate rows that create issues
    # later. All the duplicates contain a non-NA value and an NA value.
    filter(!is.na(value))
}


#' @title Recode out-of-bounds depth data using the reservoir configuration yaml
#' 
#' @description
#' This function removes any data measured beyond the normal range of depths
#' defined in the configuration yaml.
#' 
#' @param data dataframe; horizontal dataframe with columns of 'dateTime' and 
#' 'value', each parameter is in a separate columns
#' @param res character string; reservoir name where data originated
#' @param limits list; yaml list of out-of-range setttings
#' 
#' @return dataframe where any data values recorded beyond realistic depth 
#' have been dropped from the record
#' 
drop_depth_oob <- function(data, res, limits) {
  # get max res depth from config file
  max_depth <- limits[["depth_m"]][[res]]$max
  # drop any rows where measured depth is greater than max reservoir depth
  data %>% 
    filter(depth_m < max_depth | is.na(depth_m))
}
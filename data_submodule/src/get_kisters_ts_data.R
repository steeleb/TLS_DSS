#' Get Time Series Data from Kisters Data Service
#'
#' This function retrieves time series data from the Kisters data service for a 
#' specified station, time series ID, parameter, and date range.
#'
#' @param station Character. The name or ID of the station.
#' @param ts_id Numeric or character. The ID of the time series.
#' @param param Character. The parameter to retrieve.
#' @param start_date Date as a text string in the format YYYY-MM-DD. The start 
#' date for the data retrieval.
#' @param end_date Date as a text string in the format YYYY-MM-DD. The end date 
#' for the data retrieval.
#' @param datasource Character. Default is 0 (more visible data in the KISTERS 
#' data service), 1 is used for a few data sources (buoy data, pump data, etc)
#' 
#' @return A data frame containing the retrieved time series data.
#'
get_kisters_ts_data <- function(station, ts_id, param, start_date, end_date, 
                                datasource = "0"){
  # point to http
  http <- paste0("https://data.northernwater.org/KiWIS/KiWIS?service=kisters&type=queryServices&request=getTimeseriesValues&datasource=",
    datasource, "&format=html")
  # make https request, and format request
  ts_data_req <- request(http) %>% 
    req_url_query("ts_id" = ts_id,
                  "from" = start_date,
                  "to" = end_date)
  ts_data_resp <- ts_data_req %>% req_perform() %>% resp_body_html()
  ts_data_table <- ts_data_resp %>% 
    html_element("body") %>% 
    html_element("table") %>% 
    html_table(header = F, na.strings = "")
  
  # there are a few rows of data at the top we don't care about
  ts_data_table <- ts_data_table[5:nrow(ts_data_table),]
  # and then we'll apply names to the columns
  names(ts_data_table) <- c("datetime", "value")
  # and add the parameter name
  ts_data_table %>% 
    mutate(parameter = param) 
  
}
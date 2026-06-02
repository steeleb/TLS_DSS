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
get_kisters_ts_data <- function(station, 
                                ts_id, 
                                param, 
                                start_date = "1970-01-01", 
                                end_date = as.character(Sys.Date()), 
                                datasource = "0"){
  # point to http
  http <- paste0("https://data.northernwater.org/KiWIS/KiWIS?service=kisters&type=queryServices&request=getTimeseriesValues&datasource=",
                 datasource, "&format=html")
  # make https request, and format request
  # wrap in a try-catch in case this fails because it's too much data
  ts_data_table <- tryCatch({ 
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
    return(ts_data_table)
  },
  error = function(e) {
    message("Error with full request, retrying in smaller chunks...")
    
    # parse inputs as POSIXct
    start_date <- ymd_hms(start_date, tz = "Etc/GMT+7")
    end_date   <- ymd_hms(end_date, tz = "Etc/GMT+7")
    chunk <- "1 year"
    
    # build chunked intervals
    chunk_starts <- seq(start_date, end_date, by = chunk)
    chunk_ends   <- c((chunk_starts[-1] - minutes(1)), end_date) # prevent overlap
    
    # map over chunks and bind results
    all_chunks <- map2(.x = chunk_starts, .y = chunk_ends, ~{
      start <- format(.x, "%Y-%m-%dT%H:%M")
      end <- format(.y, "%Y-%m-%dT%H:%M")
      ts_data_req <- request(http) %>% 
        req_url_query("ts_id" = ts_id,
                      "from" = start,
                      "to" = end)
      ts_data_resp <- ts_data_req %>% 
        req_perform() %>% 
        resp_body_html()
      ts_data_table <- ts_data_resp %>% 
        html_element("body") %>% 
        html_element("table") %>% 
        html_table(header = F, na.strings = "")
      # there are a few rows of data at the top we don't care about
      ts_data_table <- ts_data_table[5:nrow(ts_data_table),]
      # and then we'll apply names to the columns
      names(ts_data_table) <- c("datetime", "value")
      return(ts_data_table)
    }) %>% 
      bind_rows()
    
    return(all_chunks)
  } 
  )
  
  # and add the parameter name
  ts_data_table %>% 
    mutate(parameter = param) 
  
}
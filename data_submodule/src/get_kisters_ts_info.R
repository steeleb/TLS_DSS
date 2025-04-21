#' Get Time Series Information for a NW Station from Kisters Data Service
#'
#' This function retrieves time series information from the Kisters data service 
#' for a specified station and parameters.
#'
#' @param station_no Character. The number or ID of the station.
#' @param params Character vector. The parameters to retrieve.
#' @param datasource Character. Default is 0 (more visible data in the KISTERS 
#' data service), 1 is used for a few data sources (buoy data, pump data, etc)
#' @param final Logical. Default is false. Whether the listed parameters contain 
#' multiple versions and the function should only retrieve the 'final' version. 
#' This is not applicable to all stations.
#' @param approved Logical. Default is false. Whether the listed parameters contain 
#' multiple versions and the function should only retrieve the 'approved' version. 
#' This is not applicable to all stations.
#' @param raw Logical. Default is false. Whether the listed parameters contain 
#' multiple versions and the function should only retrieve the 'raw' version. 
#' This is not applicable to all stations.
#' 
#' @return A data frame containing the retrieved time series information to run 
#' the `get_kisters_ts_data()` function.
#' 
#' 
get_kisters_ts_info <- function(station_no, 
                                params, 
                                datasource = "0", 
                                final = FALSE, 
                                approved = FALSE,
                                raw = FALSE){
  
  # make https request, and format request
  http <- paste0("https://data.northernwater.org/KiWIS/KiWIS?service=kisters&type=queryServices&request=getTimeseriesList&datasource=",
                 datasource,
                 "&format=html&station_no=", 
                 station_no, 
                 "&returnfields=station_name,station_no,ts_id,ts_name,parametertype_name,stationparameter_name,coverage")
  ts_id_req <- request(http)
  ts_id_resp <- ts_id_req %>% req_perform() %>% resp_body_html()
  ts_id_table <- ts_id_resp %>% 
    html_element("body") %>% 
    html_element("table") %>% 
    html_table(header = T)
  
  # filter for Final or Approved data, if specified in the arguments info
  if (final) {
    ts_id_table <- ts_id_table %>% 
      filter(grepl("Final", ts_name))
  } else if (approved) {
    ts_id_table <- ts_id_table %>% 
      filter(grepl("Approved", ts_name))
  } else if (raw) {
    ts_id_table <- ts_id_table %>% 
      filter(grepl("Raw", ts_name))
  }
  
  # filter for parameter names of interest
  ts_id_table %>% 
    filter(stationparameter_name %in% params)
  
}

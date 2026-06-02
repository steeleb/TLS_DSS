#' @title Get NWIS data by site number
#' 
#' @description Wrapper for {dataRetrieval} to grab USGS data by site number and 
#' rename some columns where dataRetrieval doesn't have pcode names available
#' 
#' @param site_number character string; NWIS site identifier
#' @param start_date character string; datetime string with T separator in format
#' YYYY-MM-DDTHH:MM indicating the start of the desired data retrieval
#' @param end_date character string;  datetime string with T separator in format
#' YYYY-MM-DDTHH:MM indicating the end of the desired data retrieval
#' @param tz character string; Olson timezone character string of start_date and 
#' end_date
#' 
#' @return dataframe with reformatted column names for additional parameters
#' 
get_NWIS_data_by_site <- function(site_number, start_date, end_date, tz) {
  
  # get data using dataRetrieval built-in function
  raw_data <- readNWISdata(sites = site_number,
                           service = "iv",
                           startDate = start_date,
                           endDate = end_date,
                           tz = tz)
  # rename columns using dataRetrieval and additional pcode values
  renamed_data <- renameNWISColumns(rawData = raw_data, 
                                    # add in additional values not in dataRetrieval
                                    p32315 = "chla_rfu", 
                                    p32321 = "phyco_rfu", 
                                    p72148 = "depth_m",
                                    p62361 = "chl_total_ugl")
  # return reformatted data
  renamed_data
}

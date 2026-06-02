# Source functions for this {targets} list
tar_source("data_submodule/raw_data/src/")

tunnel_delivery <- list(
    tar_target( 
        name = adams_tunnel_data,
        command = get_kisters_ts_data(station = "EX-0047",
                                    ts_id = "32892010",
                                    param = "Q",
                                    start_date = "2026-05-15",
                                    end_date = Sys.Date(),
                                    datasource = 1)%>%
        filter(!is.na(datetime)) %>%
        mutate(date = ymd(as.POSIXct(datetime, tz = "Etc/GMT+7")),
                value = as.numeric(value)) %>%
        select(date, value),
        packages = c("tidyverse", "httr2", "rvest")
    )
)
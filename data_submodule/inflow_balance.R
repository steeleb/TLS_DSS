tar_source("data_submodule/src/")

inflow_water_balance <- list(
  
  # inflow for this system is defined by Grand Lake's North Inlet and East Inlet
  # and Shadow Mountain Reservoir's North Fork of the Colorado River.
  
  ## North Fork Colorado River above Shadow Mountain (Northern Water) ----
  
  # get the tsid for the Q data - this isn't super necessary for this workflow,
  # but so you can see where this information comes from... 
  tar_target(
    name = northfork_tsids,
    command = get_kisters_ts_info(station_no = "M-0009",
                                  params = "Q"),
    packages = c("tidyverse", "httr2", "rvest"),
    cue = tar_cue("always")
  ),
  
  # grab the daily data from Kisters data service, there are 2 ts_id's here, one
  # is for the instantaneous data, the other is the daily average, we want the 
  # daily average.
  tar_target(
    name = northfork_daily,
    command = get_kisters_ts_data(station = "M-0009",
                                  ts_id = northfork_tsids$ts_id[2],
                                  param = northfork_tsids$ts_name[2],
                                  # we can use the from/to dates in the tsid dataset, 
                                  # but for now, we just care about 2024 data.
                                  start_date = "2024-04-01",
                                  end_date = "2024-11-01") %>% 
      filter(!is.na(datetime)),
    packages = c("tidyverse", "httr2", "rvest")
  ),
  
  tar_target(
    name = northfork_graph,
    command = ggplot(northfork_daily, aes(x = ymd(format(as.POSIXct(datetime), "%Y-%m-%d")),
                                          y = as.numeric(value))) +
      geom_rect(inherit.aes = FALSE,
                aes(xmin = ymd("2024-07-01"), xmax = ymd("2024-09-11"), ymin = -Inf, ymax = Inf),
                fill = "lightblue") +
      geom_line() +
      labs(x = NULL, y = "Q (cfs)",
           title = "Colorado River (North Fork) to Shadow Mountain Reservoir") +
      theme_bw() +
      theme(axis.title.y = element_text(face = "bold", size = 14),
            axis.text = element_text(size = 12)) +
      scale_x_date(date_breaks = "1 month") 
  ),
  
  ## North Inlet (NW) ----
  
  # get the tsid for the Q data 
  tar_target(
    name = northinlet_tsids,
    command = get_kisters_ts_info(station_no = "FS-0046",
                                  params = "Q"),
    packages = c("tidyverse", "httr2", "rvest"),
    cue = tar_cue("always")
  ),
  
  # grab the daily data from Kisters data service, there are 2 ts_id's here, one
  # is for the instantaneous data, the other is the daily average, we want the 
  # daily average.
  tar_target(
    name = northinlet_daily,
    command = get_kisters_ts_data(station = "FS-0046",
                                  ts_id = northinlet_tsids$ts_id[2],
                                  param = northinlet_tsids$ts_name[2],
                                  # we can use the from/to dates in the tsid dataset, 
                                  # but for now, we just care about 2024 data.
                                  start_date = "2024-04-01",
                                  end_date = "2024-11-01") %>% 
      filter(!is.na(datetime)),
    packages = c("tidyverse", "httr2", "rvest")
  ),
  
  tar_target(
    name = northinlet_graph,
    command = ggplot(northinlet_daily, aes(x = ymd(format(as.POSIXct(datetime), "%Y-%m-%d")),
                                           y = as.numeric(value))) +
      geom_rect(inherit.aes = FALSE,
                aes(xmin = ymd("2024-07-01"), xmax = ymd("2024-09-11"), ymin = -Inf, ymax = Inf),
                fill = "lightblue") +
      geom_line() +
      labs(x = NULL, y = "Q (cfs)",
           title = "North Inlet to Grand Lake") +
      theme_bw() +
      theme(axis.title.y = element_text(face = "bold", size = 14),
            axis.text = element_text(size = 12)) +
      scale_x_date(date_breaks = "1 month") 
  ),
  
  
  ## East Inlet (NW) ----
  
  # get the tsid for the Q data 
  tar_target(
    name = eastinlet_tsids,
    command = get_kisters_ts_info(station_no = "FS-0020",
                                  params = "Q"),
    packages = c("tidyverse", "httr2", "rvest"),
    cue = tar_cue("always")
  ),
  
  # grab the daily data from Kisters data service, there are 2 ts_id's here, one
  # is for the instantaneous data, the other is the daily average, we want the 
  # daily average.
  tar_target(
    name = eastinlet_daily,
    command = get_kisters_ts_data(station = "FS-0020",
                                  ts_id = eastinlet_tsids$ts_id[2],
                                  param = eastinlet_tsids$ts_name[2],
                                  # we can use the from/to dates in the tsid dataset, 
                                  # but for now, we just care about 2024 data.
                                  start_date = "2024-04-01",
                                  end_date = "2024-11-01") %>% 
      filter(!is.na(datetime)),
    packages = c("tidyverse", "httr2", "rvest")
  ),
  
  tar_target(
    name = eastinlet_graph,
    command = ggplot(eastinlet_daily, aes(x = ymd(format(as.POSIXct(datetime), "%Y-%m-%d")),
                                          y = as.numeric(value))) +
      geom_rect(inherit.aes = FALSE,
                aes(xmin = ymd("2024-07-01"), xmax = ymd("2024-09-11"), ymin = -Inf, ymax = Inf),
                fill = "lightblue") +
      geom_line() +
      labs(x = NULL, y = "Q (cfs)",
           title = "East Inlet to Grand Lake") +
      theme_bw() +
      theme(axis.title.y = element_text(face = "bold", size = 14),
            axis.text = element_text(size = 12)) +
      scale_x_date(date_breaks = "1 month") 
  ),
  
  ## Chipmunk Lane (USGS) ----
  
  # use {dataRetrieval} to get data for the Chipmunk Lane - this is the 
  # passageway between Grand and SM
  tar_target(
    name = chipmunk_raw,
    command = get_NWIS_data_by_site(site_number = "09014050", 
                                    start_date = "2024-04-01T00:00",
                                    end_date = "2024-11-01T00:00",
                                    tz = "MST"),
    packages = c("tidyverse", "dataRetrieval")
  ),
  
  # and pass the harmonize function to re-orient data
  tar_target(
    name = chipmunk_data_daily,
    command = harmonize_NWIS_stream(chipmunk_raw) %>% 
      filter(parameter == "flow_cfs") %>% 
      mutate(date = ymd(format(as.POSIXct(dateTime), "%Y-%m-%d"))) %>% 
      summarize(value = mean(value), 
                .by = date),
    packages = "tidyverse"
  ),
  
  tar_target(
    name = chipmunk_graph,
    command = ggplot(chipmunk_data_daily, aes(x = date,
                                              y = as.numeric(value))) +
      geom_rect(inherit.aes = FALSE,
                aes(xmin = ymd("2024-07-01"), xmax = ymd("2024-09-11"), ymin = -Inf, ymax = Inf),
                fill = "lightblue") +
      geom_line() +
      labs(x = NULL, y = "Q (cfs)", 
           title = "Chipmunk Lane Flow",
           subtitle = "negative flow is natural flow (GL -> SMR)") +
      theme_bw() +
      theme(axis.title.y = element_text(face = "bold", size = 14),
            axis.text = element_text(size = 12)) +
      scale_x_date(date_breaks = "1 month") 
  ),
  
  ## Pump operations (NW) ----
  
  # get tsids for daily pump
  tar_target(
    name = daily_pump_tsids,
    command = get_kisters_ts_info(station_no = "EX-0054",
                                  params = "Q_Pump",
                                  datasource = 1),
    packages = c("tidyverse", "httr2", "rvest"),
    cue = tar_cue("always")
  ),
  
  # grab data
  tar_target(
    name = daily_pump_data,
    command = get_kisters_ts_data(station = "EX-0054",
                                  ts_id = daily_pump_tsids$ts_id,
                                  param = daily_pump_tsids$parametertype_name,
                                  start_date = "2024-04-01", 
                                  end_date = "2024-11-01",
                                  datasource = 1)%>% 
      filter(!is.na(datetime)),
    packages = c("tidyverse", "httr2", "rvest")
  ),
  
  tar_target(
    name = daily_pump_graph,
    command = ggplot(daily_pump_data, aes(x = ymd(format(as.POSIXct(datetime), "%Y-%m-%d")),
                                          y = as.numeric(value))) +
      geom_rect(inherit.aes = FALSE,
                aes(xmin = ymd("2024-07-01"), xmax = ymd("2024-09-11"), ymin = -Inf, ymax = Inf),
                fill = "lightblue") +
      geom_line() +
      labs(x = NULL, y = "Q (cfs)",
           title = "Farr Pump Operations") +
      theme_bw() +
      theme(axis.title.y = element_text(face = "bold", size = 14),
            axis.text = element_text(size = 12)) +
      scale_x_date(date_breaks = "1 month") 
  ),
  
  ## Adams Tunnel Delivery (NW) ----
  # I'm not sure if this is the correct site, might be 13 miles down in Estes.
  
  # grab data
  tar_target(
    name = daily_adams_data,
    command = get_kisters_ts_data(station = "EX-0047",
                                  ts_id = "32892010",
                                  param = "Q",
                                  start_date = "2024-04-01", 
                                  end_date = "2024-11-01",
                                  datasource = 1)%>% 
      filter(!is.na(datetime)),
    packages = c("tidyverse", "httr2", "rvest")
  ),
  
  tar_target(
    name = daily_adams_graph,
    command = ggplot(daily_adams_data, aes(x = ymd(format(as.POSIXct(datetime), "%Y-%m-%d")),
                                           y = as.numeric(value))) +
      geom_rect(inherit.aes = FALSE,
                aes(xmin = ymd("2024-07-01"), xmax = ymd("2024-09-11"), ymin = -Inf, ymax = Inf),
                fill = "lightblue") +
      geom_line() +
      labs(x = NULL, y = "Q (cfs)",
           title = "Adams Tunnel Flow") +
      theme_bw() +
      theme(axis.title.y = element_text(face = "bold", size = 14),
            axis.text = element_text(size = 12)) +
      scale_x_date(date_breaks = "1 month") 
  ), 
  
  ## Colorado River outlet from SMR ----
  tar_target(
    name = raw_CR_SMR_outlet,
    command = get_NWIS_data_by_site(site_number = "09015000", 
                                    start_date = "2024-04-01T00:00",
                                    end_date = "2024-11-01T00:00",
                                    tz = "MST"),
    packages = c("tidyverse", "dataRetrieval")
  ), 
  
  tar_target(
    name = CR_SMR_out_daily,
    command = harmonize_NWIS_stream(raw_CR_SMR_outlet) %>% 
      filter(parameter == "flow_cfs") %>% 
      mutate(date = ymd(format(as.POSIXct(dateTime), "%Y-%m-%d"))) %>% 
      summarize(value = mean(value), 
                .by = date),
    packages = "tidyverse"
  ),
  
  tar_target(
    name = daily_CR_out_graph,
    command = ggplot(CR_SMR_out_daily, aes(x = date,
                                           y = as.numeric(value))) +
      geom_rect(inherit.aes = FALSE,
                aes(xmin = ymd("2024-07-01"), xmax = ymd("2024-09-11"), ymin = -Inf, ymax = Inf),
                fill = "lightblue") +
      geom_line() +
      labs(x = NULL, y = "Q (cfs)",
           title = "Flow out SMR via Colorado River") +
      theme_bw() +
      theme(axis.title.y = element_text(face = "bold", size = 14),
            axis.text = element_text(size = 12)) +
      scale_x_date(date_breaks = "1 month"),
    packages = "tidyverse"),
  
  ## make some sense of this ----
  
  # plot all together
  tar_target(
    name = stacked_plot,
    command = plot_grid(northinlet_graph,
                        eastinlet_graph, 
                        northfork_graph,
                        chipmunk_graph,
                        daily_pump_graph,
                        daily_adams_graph,
                        daily_CR_out_graph,
                        ncol = 1),
    packages = c("cowplot", "tidyverse")
  ),
  
  # sum ins and outs
  tar_target(
    name = TLS_balance,
    command = {
      # inflow should be north inlet, east inlet, north fork, pump
      inflow <- reduce(.x = list(northinlet_daily, 
                                 eastinlet_daily,
                                 northfork_daily,
                                 daily_pump_data),
                       .f = full_join) %>% 
        mutate(date = ymd(format(as.POSIXct(datetime), "%Y-%m-%d"))) %>% 
        summarize(inflow = sum(as.numeric(na.omit(value))),
                  .by = date)
      # outflow should be adams and CR
      outflow <- reduce(.x = list(CR_SMR_out_daily,
                                  daily_adams_data %>% 
                                    mutate(date = ymd(format(as.POSIXct(datetime), "%Y-%m-%d")),
                                           value = as.numeric(value))),
                        .f = full_join) %>% 
        summarize(outflow = sum(as.numeric(na.omit(value))),
                  .by = date)
      # create balance and rolling average
      full_join(inflow, outflow) %>% 
        mutate(balance_flow = inflow - outflow, 
               three_day_ave = rollmean(balance_flow, align = "center", k = 3, fill = NA),
               seven_day_ave = rollmean(balance_flow, align = "center", k = 7, fill = NA))
    },
    packages = c("zoo", "tidyverse")
  ),
  
  tar_target(
    name = plot_balance,
    command = {
      TLS_long <- TLS_balance %>%
        pivot_longer(cols = c(three_day_ave, seven_day_ave),
                     names_to = "n_day",
                     values_to = "ave_value")
      ggplot(TLS_long, aes(x = date, y = balance_flow)) +
        geom_point() +
        geom_abline(slope = 0, intercept = 0, linewidth = 1) +
        geom_line(data = TLS_long, aes(y = ave_value, color = n_day)) +
        theme_bw() +
        labs(x = NULL,
          y = "net flow (average cfs per day)",
          color = "rolling average") +
        theme(axis.title = element_text(face = "bold", size = 12),
          legend.position = c(0.85, 0.5),  # Inset position
          legend.background = element_rect(fill = alpha("white", 0.7))) +
        scale_color_manual(values = c("three_day_ave" = "blue", "seven_day_ave" = "orange"),
          labels = c("3-day average", "7-day average"))
    }
  )
  
)

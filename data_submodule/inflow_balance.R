tar_source("data_submodule/src/")

inflow_water_balance <- list(
  
  # inflow for this system is defined by Grand Lake's North Inlet and East Inlet
  # and Shadow Mountain Reservoir's North Fork of the Colorado River.
  
  ## North Fork Colorado River above Shadow Mountain (Northern Water) ----
  
  # grab the daily data from Kisters data service, ts_id and param names have been
  # identified in the NASA-NW repository workflow
  tar_target(
    name = northfork_daily,
    command = get_kisters_ts_data(station = "M-0009",
                                  ts_id = "28741010",
                                  param = "20_Obs_1Day_Mean_Final",
                                  # we can use the from/to dates in the tsid dataset,
                                  # but for now, we just care about 2024 data.
                                  start_date = "2024-04-01",
                                  end_date = "2024-11-01") %>% 
      filter(!is.na(datetime)) %>% 
      mutate(date = ymd(as.POSIXct(datetime, tz = "Etc/GMT+7")),
             value = as.numeric(value)) %>% 
      select(date, value),
    packages = c("tidyverse", "httr2", "rvest")
  ),
  
  tar_target(
    name = northfork_graph,
    command = ggplot(northfork_daily, aes(x = date,
                                          y = value)) +
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
  
  # grab the daily data from Kisters data service
  tar_target(
    name = northinlet_daily,
    command = get_kisters_ts_data(station = "FS-0046",
                                  ts_id = "28759010",
                                  param = "20_Obs_1Day_Mean_Final",
                                  # we can use the from/to dates in the tsid dataset, 
                                  # but for now, we just care about 2024 data.
                                  start_date = "2024-04-01",
                                  end_date = "2024-11-01") %>% 
      filter(!is.na(datetime)) %>% 
      mutate(date = ymd(as.POSIXct(datetime, tz = "Etc/GMT+7")),
             value = as.numeric(value)) %>% 
      select(date, value),
    packages = c("tidyverse", "httr2", "rvest")
  ),
  
  tar_target(
    name = northinlet_graph,
    command = ggplot(northinlet_daily, aes(x = date,
                                           y = value)) +
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
  
  # grab the daily data from Kisters data service
  tar_target(
    name = eastinlet_daily,
    command = get_kisters_ts_data(station = "FS-0020",
                                  ts_id = "28721010",
                                  param = "20_Obs_1Day_Mean_Final",
                                  # we can use the from/to dates in the tsid dataset, 
                                  # but for now, we just care about 2024 data.
                                  start_date = "2024-04-01",
                                  end_date = "2024-11-01") %>% 
      filter(!is.na(datetime)) %>% 
      mutate(date = ymd(as.POSIXct(datetime, tz = "Etc/GMT+7")),
             value = as.numeric(value)) %>% 
      select(date, value),
    packages = c("tidyverse", "httr2", "rvest")
  ),
  
  tar_target(
    name = eastinlet_graph,
    command = ggplot(eastinlet_daily, aes(x = date,
                                          y = value)) +
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
      mutate(date = as_date(dateTime)) %>% 
      summarize(chipmunk_cfs = mean(value, rm.na = T),
                               .by = date)
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
           title = "Chipmunk Lane Flow: negative flow is natural flow (GL -> SMR)") +
      theme_bw() +
      theme(axis.title.y = element_text(face = "bold", size = 14),
            axis.text = element_text(size = 12)) +
      scale_x_date(date_breaks = "1 month") 
  ),
  
  ## Pump operations (NW) ----
  # grab data
  tar_target(
    name = daily_pump_data,
    command = get_kisters_ts_data(station = "EX-0054",
                                  ts_id = "28609010",
                                  param = "01_Obs_1Day_Mean",
                                  start_date = "2024-04-01", 
                                  end_date = "2024-11-01",
                                  datasource = 1)%>% 
      filter(!is.na(datetime)) %>% 
      mutate(date = ymd(as.POSIXct(datetime, tz = "Etc/GMT+7")),
             value = as.numeric(value)) %>% 
      select(date, value),
    packages = c("tidyverse", "httr2", "rvest")
  ),
  
  tar_target(
    name = daily_pump_graph,
    command = ggplot(daily_pump_data, aes(x = date,
                                          y = value)) +
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
  
  # THIS IS THE TS THAT BECCA PROVIDED, BUT I DON'T THINK THIS IS THE ONE WE WANT.
  # tar_target(
  #   name = daily_adams_data,
  #   command = get_kisters_ts_data(station = "EX-0182",
  #                                 ts_id = "33644010",
  #                                 param = "Q",
  #                                 start_date = "2024-04-01",
  #                                 end_date = "2024-11-01",
  #                                 datasource = 1)%>%
  #     filter(!is.na(datetime)) %>%
  #     mutate(date = ymd(as.POSIXct(datetime, tz = "Etc/GMT+7")),
  #            value = as.numeric(value)) %>%
  #     select(date, value),
  #   packages = c("tidyverse", "httr2", "rvest")
  # ),
  
  tar_target(
    name = daily_adams_data,
    command = get_kisters_ts_data(station = "EX-0047",
                                  ts_id = "32892010",
                                  param = "Q",
                                  start_date = "2024-04-01",
                                  end_date = "2024-11-01",
                                  datasource = 1)%>%
      filter(!is.na(datetime)) %>%
      mutate(date = ymd(as.POSIXct(datetime, tz = "Etc/GMT+7")),
             value = as.numeric(value)) %>%
      select(date, value),
    packages = c("tidyverse", "httr2", "rvest")
  ),
  
  tar_target(
    name = daily_adams_graph,
    command = ggplot(daily_adams_data, aes(x = date,
                                           y = value)) +
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
      mutate(date = ymd(as.POSIXct(dateTime, tz = "Etc/GMT+7"))) %>% 
      summarize(value = mean(value), 
                .by = date) %>% 
      filter(!is.na(date))
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
      scale_x_date(date_breaks = "1 month")
  ),
  
  ## TLS elevation ----
  
  tar_target(
    name = SMR_elevation,
    command = get_kisters_ts_data(station = "SC-0033",
                                  ts_id = "33746010",
                                  param = "20_Obs_BOD_Final",
                                  start_date = "2024-04-01", 
                                  end_date = "2024-11-01",
                                  datasource = 1)%>% 
      filter(!is.na(datetime)) %>% 
      mutate(date = ymd(as.POSIXct(datetime, tz = "Etc/GMT+7")),
             value = as.numeric(value)) %>% 
      select(date, 
             SMR_elev_ft = value),
    packages = c("tidyverse", "httr2", "rvest")
  ),
  
  tar_target(
    name = GL_elevation,
    command = get_kisters_ts_data(station = "SC-0018",
                                  ts_id = "33747010",
                                  param = "20_Obs_BOD_Final",
                                  start_date = "2024-04-01", 
                                  end_date = "2024-11-01",
                                  datasource = 1)%>% 
      filter(!is.na(datetime)) %>% 
      mutate(date = ymd(as.POSIXct(datetime, tz = "Etc/GMT+7")),
             value = as.numeric(value)) %>% 
      select(date, 
             GL_elev_ft = value),
    packages = c("tidyverse", "httr2", "rvest")
  ),
  
  ## make some sense of this visually ----
  
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
  
  tar_target(
    name = save_stacked_flow,
    command = ggsave(plot = stacked_plot, filename = "DSS_Shiny/www/stacked_flow.jpg",
                     dpi = 300, width = 10, height = 10)
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
        summarize(inflow = sum(na.omit(value)),
                  .by = date)
      # outflow should be adams and CR
      outflow <- reduce(.x = list(CR_SMR_out_daily,
                                  daily_adams_data),
                        .f = full_join) %>% 
        summarize(outflow = sum(na.omit(value)),
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
    name = elevation_graph,
    command = {
      smr_gl <- full_join(SMR_elevation, GL_elevation) %>% 
        pivot_longer(cols = c("SMR_elev_ft", "GL_elev_ft"),
                     names_to = "reservoir",
                     values_to = "elevation")
      ggplot(smr_gl, aes(x = date, y = elevation, color = reservoir)) +
        geom_point() +
        theme_bw() +
        labs(x = NULL,
             y = "waterbody elevation (ft)") +
        theme(axis.title = element_text(face = "bold", size = 12),
              legend.position = c(0.85, 0.2),  # Inset position
              legend.background = element_rect(fill = alpha("white", 0.7))) +
        scale_color_manual(values = c("SMR_elev_ft" = "blue", "GL_elev_ft" = "orange"),
                           labels = c("Shadow Mountain Reservoir", "Grand Lake"))
    }
  ),
  
  tar_target(
    name = plot_balance,
    command = {
      TLS_long <- TLS_balance %>%
        pivot_longer(cols = c(three_day_ave, seven_day_ave),
                     names_to = "n_day",
                     values_to = "ave_value")
      plot <- ggplot(TLS_long, aes(x = date, y = balance_flow)) +
        geom_point() +
        geom_abline(slope = 0, intercept = 0, linewidth = 1) +
        geom_line(data = TLS_long, aes(y = ave_value, color = n_day)) +
        theme_bw() +
        labs(x = NULL,
             y = "net flow (average cfs per day)",
             color = "rolling average") +
        theme(axis.title = element_text(face = "bold", size = 12),
              legend.position = c(0.85, 0.2),  # Inset position
              legend.background = element_rect(fill = alpha("white", 0.7))) +
        scale_color_manual(values = c("three_day_ave" = "grey", "seven_day_ave" = "grey10"),
                           labels = c("3-day average", "7-day average"))
      plot_grid(elevation_graph, plot, ncol = 1)
    },
    packages = c("tidyverse", "cowplot")
  ),
  
  tar_target(
    name = save_water_balance_fig,
    command = ggsave(plot = plot_balance, filename = "DSS_Shiny/www/water_balance.jpg",
                     dpi = 300, width = 10, height = 6)
  ),
  
  
  tar_target(
    name = total_natural_inflow,
    command = {
      inflow <- reduce(.x = list(northinlet_daily, 
                                 eastinlet_daily,
                                 northfork_daily),
                       .f = full_join) %>% 
        summarize(natural_inflow = sum(na.omit(value)),
                  .by = date)
      nat_flow <- ggplot(inflow, aes(x = date, y = natural_inflow)) +
        geom_point() +
        gghighlight(natural_inflow > 220) +
        theme_bw() +
        labs(x = NULL, y = "natural inflow\n(average CFS)", 
             title = "Total Natural Inflow") +
        theme(axis.title = element_text(face = "bold", size = 14))
      plot_grid(daily_adams_graph,
                daily_pump_graph, 
                nat_flow, 
                daily_CR_out_graph,
                ncol = 1)
    },
    packages = c("tidyverse", "cowplot", "gghighlight")
  ),
  
  tar_target(
    name = water_balance_data,
    command = {
      data <- reduce(.x = list(northfork_daily %>% 
                                 rename(northfork_cfs = value),
                               northinlet_daily %>% 
                                 rename(northinlet_cfs = value),
                               eastinlet_daily %>% 
                                 rename(eastinlet_cfs = value),
                               chipmunk_data_daily %>% 
                                 rename(chipmunk_cfs = value),
                               daily_pump_data %>% 
                                 rename(pump_cfs = value),
                               CR_SMR_out_daily %>% 
                                 rename(CR_out_cfs = value),
                               daily_adams_data %>% 
                                 rename(adams_cfs = value),
                               GL_elevation,
                               SMR_elevation),
                     .f = full_join) %>% 
        mutate(dow = wday(date, label = T)) %>% 
        relocate(date, dow)
    }
  ),
  
  tar_target(
    name = save_water_balance_data,
    command = write_csv(water_balance_data, 
                        "DSS_Shiny/www/water_balance.csv")
  )
  
)

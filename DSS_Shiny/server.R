# TLS-DSS: Server Logic
source("global.R")

server <- function(input, output, session) {
  
  # DATA SUBMODULE ----
  
  # Reactive value to store the current data in the navigation pane
  current_data <- reactive({
    req(input$dataFile)
    read_data_file(input$dataFile)
  })
  
  # Dynamic content based on selected display option
  output$dynamicContent <- renderUI({
    # Render dynamic UI for data table or figure based on selected option
    navset_card_tab(
      nav_panel(
        title = "Data Table",
        div(
          style = "height: 100%; overflow: hidden;",
          DT::dataTableOutput("dataTable")
        )      
      ),
      nav_panel(
        title = "Summary",
        verbatimTextOutput("dataSummary")
      )
    )
  })
  
  ## table content ----
  # Display data table
  output$dataTable <- renderDataTable({
    req(current_data())
    datatable(
      current_data() %>% 
        mutate(across(where(is.numeric), ~round(., digits = 2))), 
      options = list(
        pageLength = 10,
        scrollY = "calc(100vh - 420px)",  # adjust based on navbar/header heights
        scrollCollapse = TRUE
      ),
      rownames = FALSE
    )
  })
  
  # Display data summary
  output$dataSummary <- renderPrint({
    req(current_data())
    
    # Check if data is available
    if (is.null(current_data())) {
      cat("Error loading data.")
      return(NULL)
    }
    
    # Print basic information
    cat("Rows:", nrow(current_data()), "\n")
    cat("Columns:", ncol(current_data()), "\n\n")
    
    # Print column names and types
    cat("Column Information:\n")
    col_info <- sapply(current_data(), class)
    for (i in seq_along(col_info)) {
      cat(names(col_info)[i], ": ", paste(col_info[[i]], collapse = ", "), "\n")
    }
    
    # Print summary
    cat("\nSummary Statistics:\n")
    print(summary(current_data()))
  })
  
  # DIALOG SUBMODULE ----
  
  ## Get unique dates for forecasts ----
  
  # Pre-process the forecast dates when the app starts
  temp_data <- read_csv("www/daily_SMR_temp.csv") %>% 
    mutate(date = ymd(date))
  water_bal <- read_csv("www/water_balance.csv") %>% 
    mutate(date = ymd(date))
  met <- read_csv("www/daily_met.csv") %>% 
    mutate(date = ymd(date))
  
  all_data <- reduce(.x = list(temp_data, water_bal, met),
                     .f = full_join)
  
  forecast_start <- min(ymd(temp_data$date)) + days(6)
  forecast_dates <- unique(temp_data$date) %>% 
    ymd(.) %>%
    .[. > forecast_start] %>% 
    format(., "%A %B %d, %Y")
  
  # Update the selectInput once at the start
  updateSelectInput(session, "selectedDate", choices = forecast_dates)
  
  ## Create data tables ----
  filtered_forecast_data <- reactive({
    req(input$selectedDate)
    
    forecast_date <- as_date(parse_date_time(input$selectedDate, "%A %B %d, %Y"))
    
    # get prev 30 days (not including 'forecast day', aka the day we want 
    # to predict)
    prev_data <- all_data %>%
      filter(date < forecast_date & date > forecast_date - days(30)) %>% 
      mutate(across(where(is.numeric), ~round(., digits = 2)))
    
    met_fore <- met %>% 
      filter(between(date, forecast_date, forecast_date + days(6))) %>% 
      mutate(across(where(is.numeric), ~round(., digits = 2)))
    
    list(prev_data = prev_data, met_fore = met_fore)
  })
  
  # add prev and forecast tables to output
  output$prevDataTable <- renderDataTable({
    req(filtered_forecast_data())
    datatable(filtered_forecast_data()$prev_data, 
              options = list(pageLength = 7))
  })
  
  output$forecastMetTable <- renderDataTable({
    req(filtered_forecast_data())
    datatable(filtered_forecast_data()$met_fore, 
              options = list(pageLength = 7))
  })
  
  ## Create figures ----
  output$prevTempFigure <- renderPlot({
    req(filtered_forecast_data())
    temp <- filtered_forecast_data()$prev_data %>% 
      select(date, mean_temp_ns, mean_temp_int) %>% 
      pivot_longer(cols = c(mean_temp_ns, mean_temp_int),
                   names_to = "parameter",
                   values_to = "value") %>% 
      mutate(parameter = factor(parameter, 
                                levels = c("mean_temp_ns", "mean_temp_int"),
                                labels = c("Mean Near-Surface Temperature (deg C)",
                                           "Mean Integrated Temperature (deg C)")))
    ggplot(temp, aes(x = date, y = value, color = parameter)) +
      geom_point() +
      geom_line() +
      scale_y_continuous(limits = c(10, 20)) +
      theme_bw() +
      labs(x = NULL, y = "daily water temperature") +
      ROSS_theme +
      theme(legend.position = "bottom") +
      scale_color_manual(values = ROSS_lt_pal)
    
  }, res = 100)
  
  output$prevFlowFigure <- renderPlot({
    req(filtered_forecast_data())
    flow <- filtered_forecast_data()$prev_data %>% 
      select(date, northfork_cfs:SMR_elev_ft) %>% 
      pivot_longer(cols = c(northfork_cfs:SMR_elev_ft),
                   names_to = "parameter",
                   values_to = "value") %>% 
      mutate(parameter = factor(parameter,
                                levels = c("northinlet_cfs",
                                           "eastinlet_cfs",
                                           "northfork_cfs",
                                           "pump_cfs",
                                           "adams_cfs",
                                           "CR_out_cfs",
                                           "chipmunk_cfs",
                                           "SMR_elev_ft",
                                           "GL_elev_ft"),
                                labels = c("North Inlet to GL (ave cfs)",
                                           "East Inlet to GL (ave cfs)",
                                           "North Fork into SMR (ave cfs)",
                                           "Farr Pump Operation (ave cfs)",
                                           "Adams Tunnel (ave cfs)",
                                           "CO River Outlet from SMR (ave cfs)",
                                           "Chipmunk Lane Interflow (ave cfs)",
                                           "SMR Elevation (ft)",
                                           "GL Elevation (ft)")))
    ggplot(flow, aes(x = date, y = value)) +
      geom_point() +
      geom_line() +
      labs(x = NULL, y = NULL) +
      facet_grid(parameter ~ ., scales = "free_y", labeller = label_wrap_gen(10)) +
      theme_bw() +
      ROSS_theme
  }, res = 100, height = 1200)
  
  output$prevFlowAggregated <- renderPlot({
    req(filtered_forecast_data())
    flow_agg <- filtered_forecast_data()$prev_data %>% 
      select(date, northfork_cfs:adams_cfs) %>% 
      pivot_longer(cols = c(northfork_cfs:adams_cfs),
                   names_to = "parameter",
                   values_to = "value") %>% 
      filter(parameter != "chipmunk_cfs") %>% 
      mutate(type = case_when(parameter %in% c("northinlet_cfs",
                                               "eastinlet_cfs",
                                               "northfork_cfs") ~ "natural inflow",
                              parameter == "adams_cfs" ~ "Adams Tunnel outflow",
                              parameter == "CR_out_cfs" ~ "CO River outflow",
                              parameter == "pump_cfs" ~ "pump operations (inflow)"),
             type = factor(type,
                           levels = c("natural inflow",
                                      "pump operations (inflow)",
                                      "Adams Tunnel outflow",
                                      "CO River outflow"))) %>% 
      summarise(total_cfs = sum(value),
                .by = c("date", "type"))
    ggplot(flow_agg, aes(x = date, y = total_cfs)) +
      geom_point() +
      geom_line() +
      labs(y = "total average flow (cfs)", x = NULL) +
      facet_grid(type ~ ., scales = "free_y", 
                 labeller = label_wrap_gen(10)) +
      theme_bw() +
      scale_x_date(breaks = seq(min(flow_agg$date), max(flow_agg$date), by = "7 days"),
                   labels = function(x) if_else(x %in% seq(min(flow_agg$date), max(flow_agg$date), by = "7 days"),
                                                format(x, "%a, %b %d"),
                                                "")) +
      ROSS_theme
  }, res = 100)
  
  output$prevMetFigure <- renderPlot({
    req(filtered_forecast_data())
    met <- filtered_forecast_data()$prev_data %>% 
      select(date, max_temp_degC:mean_wind_mps) %>% 
      pivot_longer(cols = !date,
                   names_to = "parameter",
                   values_to = "value") %>% 
      mutate(unit = case_when(grepl("degC", parameter) ~ "Air Temperature (deg C)",
                              grepl("perc", parameter) ~ "Percent Relative Humidity",
                              grepl("Wpm2", parameter) ~ "Total Solar Radiation (W/m^2)",
                              grepl("mps", parameter) ~ "Wind (m/s)",
                              .default = NA_character_),
             label = case_when(grepl("min", parameter) ~ "daily minimum",
                               grepl("max", parameter) ~ "daily maximum",
                               grepl("mean", parameter) ~ "daily average",
                               .default = "daily total"))
    ggplot(met, aes(x = date, y = value, color = label)) +
      geom_point() +
      geom_line() +
      labs(x = NULL, y = NULL) +
      facet_grid(unit ~ ., scales = "free_y", labeller = label_wrap_gen(10)) +
      theme_bw() +
      ROSS_theme +
      scale_color_manual(values = ROSS_lt_pal)
  }, res = 100)
  
  # FORECAST PANEL ----
  
  output$pumping_summary <- renderUI({
    # require summary function dataset
    optimal_model <- "static" # replace with optimal model name
    near_surface_days <- 0  # Replace with your computed value
    integrated_days <- 0    # Replace with your computed value
    
    HTML(paste0(
      "Optimal pumping regime: <strong>", optimal_model, "</strong><br>",
      "near surface summary: ", near_surface_days, "/7 days <em>below</em> threshold<br>",
      "integrated summary: ", integrated_days, "/7 days <em>above</em> threshold"
    ))
  })
  
  output$fore_airtemp_20240715 <- renderPlot({
    met %>% 
      filter(between(date, ymd("2024-07-04"), ymd("2024-07-21")))%>% 
      select(date, mean_temp_degC, max_temp_degC) %>% 
      pivot_longer(cols = mean_temp_degC:max_temp_degC,
                   names_to = "air_temp_agg", 
                   values_to = "value") %>% 
      mutate(air_temp_agg = factor(air_temp_agg, 
                                   levels = c("max_temp_degC", "mean_temp_degC"),
                                   labels = c("max", "mean"))) %>% 
      ggplot(., aes(x = date, y = value, color = air_temp_agg)) + 
      geom_rect(aes(xmin = as.Date("2024-07-15"), xmax = as.Date("2024-07-21"), 
                    ymin = -Inf, ymax = Inf),
                fill = "grey90", alpha = 0.5, inherit.aes = FALSE) +
      geom_line() + 
      labs(x = NULL, y = "air temperature\n(deg C)", color = "aggregation\ntype") +
      scale_color_tableau() +
      theme_bw()
  }, res = 100)
  
  output$fore_ns_20240715 <- renderPlot({
    # Get previous data
    previous_10_days <- temp_data %>% 
      filter(between(date, ymd("2024-07-04"), ymd("2024-07-14")))
    # Get data from output
    control <- read_csv("www/forecast/forecasted_temp_control_collated.csv") %>% 
      mutate(regime = "control")
    static <- read_csv("www/forecast/forecasted_temp_static_collated.csv") %>% 
      mutate(regime = "static")
    pulsing <- read_csv("www/forecast/forecasted_temp_pulsing_collated.csv") %>% 
      mutate(regime = "pulsing")
    
    forecast <- reduce(list(control, static, pulsing),
                       full_join)
    
    forecast %>% 
      summarize(mean_1m = mean(mean_1m_temp_degC), 
                .by = c(valid_date, regime)) %>% 
      ggplot(., aes(x = valid_date, y = mean_1m, color = regime)) + 
      geom_rect(aes(xmin = as.Date("2024-07-15"), xmax = as.Date("2024-07-21"), 
                    ymin = -Inf, ymax = Inf),
                fill = "grey90", alpha = 0.5, inherit.aes = FALSE) +
      geom_line() + 
      geom_abline(slope = 0, intercept = 15, linetype = 2) +
      annotate("text", x = as.Date("2024-07-14"), y = 15.3, 
               label = "Algal Threshold (goal < 15°C, summer to fall)", hjust = 0, size = 4) +
      labs(x = NULL, y = "average near-suface (0-1m)\ntemperature, (deg C)") +
      scale_color_tableau() +
      geom_line(data = previous_10_days, inherit.aes = F, aes(x = date, y = mean_temp_ns)) +
      theme_bw()
  }, res = 100)
  
  output$fore_int_20240715 <- renderPlot({
    
    # Get previous data
    previous_10_days <- temp_data %>% 
      filter(between(date, ymd("2024-07-04"), ymd("2024-07-14")))
    # Get data from output
    control <- read_csv("www/forecast/forecasted_temp_control_collated.csv") %>% 
      mutate(regime = "control")
    static <- read_csv("www/forecast/forecasted_temp_static_collated.csv") %>% 
      mutate(regime = "static")
    pulsing <- read_csv("www/forecast/forecasted_temp_pulsing_collated.csv") %>% 
      mutate(regime = "pulsing")
    
    forecast <- reduce(list(control, static, pulsing),
                       full_join)
    
    forecast %>% 
      summarize(mean_int = mean(mean_0_5m_temp_degC), 
                .by = c(valid_date, regime)) %>% 
      ggplot(., aes(x = valid_date, y = mean_int, color = regime)) + 
      geom_rect(aes(xmin = as.Date("2024-07-15"), xmax = as.Date("2024-07-21"), 
                    ymin = -Inf, ymax = Inf),
                fill = "grey90", alpha = 0.5, inherit.aes = FALSE) +
      geom_line()+ 
      labs(x = NULL, y = "average integrated (0-5m)\ntemperature, (deg C)") +
      scale_color_tableau() +
      geom_abline(slope = 0, intercept = 14, linetype = 2) +
      annotate("text", x = as.Date("2024-07-05"), y = 13.7, 
               label = "Diatom Threshold (goal > 14°C, spring/early summer)", hjust = 0, size = 4) +
      geom_line(data = previous_10_days, inherit.aes = F, aes(x = date, y = mean_temp_int)) +
      theme_bw()
  }, res = 100)
  
  output$fore_ns_actual_20240715 <- renderPlot({
    # Get previous data
    previous_10_days_plus <- temp_data %>% 
      filter(between(date, ymd("2024-07-04"), ymd("2024-07-21")))
    # Get data from output
    control <- read_csv("www/forecast/forecasted_temp_control_collated.csv") %>% 
      mutate(regime = "control")
    static <- read_csv("www/forecast/forecasted_temp_static_collated.csv") %>% 
      mutate(regime = "static")
    pulsing <- read_csv("www/forecast/forecasted_temp_pulsing_collated.csv") %>% 
      mutate(regime = "pulsing")
    
    forecast <- reduce(list(control, static, pulsing),
                       full_join)
    
    forecast %>% 
      summarize(mean_1m = mean(mean_1m_temp_degC), 
                .by = c(valid_date, regime)) %>% 
      ggplot(., aes(x = valid_date, y = mean_1m, color = regime)) + 
      geom_rect(aes(xmin = as.Date("2024-07-15"), xmax = as.Date("2024-07-21"), 
                    ymin = -Inf, ymax = Inf),
                fill = "grey90", alpha = 0.5, inherit.aes = FALSE) +
      geom_line() + 
      labs(x = NULL, y = "average near-suface (0-1m)\ntemperature, (deg C)") +
      scale_color_tableau() +
      geom_abline(slope = 0, intercept = 15, linetype = 2) +
      annotate("text", x = as.Date("2024-07-14"), y = 15.2, 
               label = "Algal Threshold (goal < 15°C, summer to fall)", hjust = 0, size = 4) +
      geom_line(data = previous_10_days_plus, inherit.aes = F, aes(x = date, y = mean_temp_ns)) +
      theme_bw()
  }, res = 100)
  
  output$fore_int_actual_20240715 <- renderPlot({
    
    # Get previous data
    previous_10_days_plus <- temp_data %>% 
      filter(between(date, ymd("2024-07-04"), ymd("2024-07-21")))
    # Get data from output
    control <- read_csv("www/forecast/forecasted_temp_control_collated.csv") %>% 
      mutate(regime = "control")
    static <- read_csv("www/forecast/forecasted_temp_static_collated.csv") %>% 
      mutate(regime = "static")
    pulsing <- read_csv("www/forecast/forecasted_temp_pulsing_collated.csv") %>% 
      mutate(regime = "pulsing")
    
    forecast <- reduce(list(control, static, pulsing),
                       full_join)
    
    forecast %>% 
      summarize(mean_int = mean(mean_0_5m_temp_degC), 
                .by = c(valid_date, regime)) %>% 
      ggplot(., aes(x = valid_date, y = mean_int, color = regime)) + 
      geom_rect(aes(xmin = as.Date("2024-07-15"), xmax = as.Date("2024-07-21"), 
                    ymin = -Inf, ymax = Inf),
                fill = "grey90", alpha = 0.5, inherit.aes = FALSE) +
      geom_line()+ 
      labs(x = NULL, y = "average integrated (0-5m)\ntemperature, (deg C)") +
      scale_color_tableau() +
      geom_abline(slope = 0, intercept = 14, linetype = 2) +
      annotate("text", x = as.Date("2024-07-05"), y = 13.8, 
               label = "Diatom Threshold (goal > 14°C, spring/early summer)", hjust = 0, size = 4) +
      geom_line(data = previous_10_days_plus, inherit.aes = F, aes(x = date, y = mean_temp_int)) +
      theme_bw()
  }, res = 100)
  
}

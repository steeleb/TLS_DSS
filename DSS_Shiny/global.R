# TLS-DSS: Three Lakes System - Decision Support System
# Global settings and functions

# Load required libraries
library(shiny)
library(bslib)
library(DT)
library(tidyverse)
library(ggthemes)

# GLOBAL VARIABLES ----

# Define paths to figures
figure_paths <- list(
  water_balance = "www/water_balance.jpg",
  stacked_flow = "www/stacked_flow.jpg"
)

# define pretty names for files
file_label_lookup <- list(
  "daily_met.csv" = "Daily Meteorology",
  "water_balance.csv" = "Inflow/Outflow",
  "daily_SMR_temp.csv" = "Daily SMR temperature"
)

# theme for figures
ROSS_theme <- theme_bw() + #or theme_few()
  theme(plot.title = element_text(hjust = 0.5, face = 'bold'),
        plot.subtitle = element_text(hjust = 0.5)) 

# ROSS-branded color palette
ROSS_lt_pal <- c("#002EA3", "#E70870", "#256BF5", 
                 "#745CFB", "#1E4D2B", "#56104E")

# GLOBAL FUNCTIONS ----

list_data_files <- function() {
  data_path <- "www"
  
  files <- list.files(
    path = data_path,
    pattern = "\\.csv",
    full.names = FALSE
  )
  
  # Filter only files that are in the lookup table
  valid_files <- files[files %in% names(file_label_lookup)]
  
  # Set names using the lookup table
  named_files <- setNames(valid_files, file_label_lookup[valid_files])
  
  return(named_files)
}

# Function to read data file
read_data_file <- function(filename) {
  # Full path to the file
  file_path <- file.path("www", filename)
  
  # Read file based on extension using switch
  data <- tryCatch({
    read_csv(file_path)
  }, error = function(e) {
    message(paste("Error reading file:", filename, "-", e$message))
    NULL
  })
  
  return(data)
}

determine_optimal_forecast <- function(forecast_data, date_of_forecast) {
  # get today's forecast across the datasets, which are stored as a list, so we'll map it...
  todays_forecast <- map(.x = forecast_data, 
                         .f = ~ .x %>% 
                           filter(forecast_date == date_of_forecast) %>% 
                           summarize(ens_mean_1m_temp_degC = mean(mean_1m_temp_degC),
                                     ens_mean_0_5m_temp_degC = mean(mean_0_5m_temp_degC),
                                     .by = c("valid_date", "forecast_date", "regime")))
  # make a summary6 of the days where the threshold is met
  threshold_summary <- map(.x = todays_forecast,
                           .f = ~ {
                             # we need a function to summarize our dataset for the
                             # days that meet the threshold, but this needs to handle
                             # instances of zero rows...
                             count_or_zero <- function(df, filter_expr) {
                               filtered <- df %>% filter({{ filter_expr }})
                               if (nrow(filtered) == 0) {
                                 # return a tibble with n = 0
                                 vals <- tibble(n = 0)
                                 vals$regime <- df$regime[1]
                                 vals$forecast_date <- df$forecast_date[1]
                                 vals$min_temp <- min(df$ens_mean_1m_temp_degC)
                                 vals$max_temp <- max(df$ens_mean_0_5m_temp_degC)
                                 return(vals)
                               } else {
                                 summary <- filtered %>%
                                   summarize(n = n(), 
                                             # we also need the tie-breaker values
                                             # we want to choose the LOWEST value for 
                                             # the surface
                                             min_temp = min(ens_mean_1m_temp_degC),
                                             # and the highest temperature for the 
                                             # integrated depth
                                             max_temp = max(ens_mean_0_5m_temp_degC),
                                             .by = c("forecast_date", "regime"))
                                 return(summary)
                               }
                             }
                             # apply that function for both depths and thresholds
                             ns_summary <- count_or_zero(df = .x, 
                                                         filter_exp = ens_mean_1m_temp_degC <= 15) %>% 
                               mutate(summary = "ns")
                             
                             int_summary <- count_or_zero(df = .x, 
                                                          filter_exp = ens_mean_0_5m_temp_degC >= 14) %>% 
                               mutate(summary = "int")
                             # return a combined result of the summaries
                             bind_rows(ns_summary, int_summary)
                           }) %>% 
    bind_rows() %>% 
    # create a min/max column, since ns will always be minimized and int will always
    # be maximized
    mutate(min_max_temp = if_else(summary == "ns", min_temp, max_temp)) %>% 
    select(-c(min_temp, max_temp))
  
  # okay, now we need to determine the optimal regime given the summary data
  optimal <- {
    
    # optimal will be where the pumping regime results in the most number
    # of days conforming to thresholds. however, this might result in a tie,
    # in which case we need to determine how to make that decision.
    
    # first step: determine focus depth by date:
    if (date_of_forecast < ymd("2024-07-01")) {
      focus <- "int"
    } else {
      focus <- "ns"
    }
    
    # filter for the focus depth
    threshold_filter <- threshold_summary %>% 
      filter(summary == focus)
    
    # determine the max, filter for the maximum
    max_days <- max(threshold_filter$n)
    threshold_regime <- threshold_filter %>% 
      filter(n == max_days)
    
    # if the number of rows is == 1, our regime is the one stated in the 
    # threshold regime dataframe
    if (nrow(threshold_regime) == 1) {
      optim <- threshold_regime %>%
        filter(regime == unique(threshold_regime$regime)) %>% 
        mutate(tie = FALSE)
    } else {
      # if there is a tie in n days, we need to optimize based on forecast, where early 
      # season uses integrated temperature maximization and late season uses 
      # near surface temperature minimization
      if (focus == "int") {
        optim <- threshold_regime %>% 
          # remove control from consideration
          filter(!regime %in% "control") %>%
          # maximize by sorting in descending order
          summarize(average_temp = mean(min_max_temp),
                    .by = regime) %>%
          arrange(desc(average_temp)) %>% 
          slice(1) %>% 
          mutate(tie = TRUE)
      } else {
        optim <- threshold_summary %>% 
          filter(summary == "ns") %>% 
          # remove control from consideration
          filter(!regime %in% "control") %>% 
          summarize(average_temp = mean(min_max_temp),
                    .by = regime) %>%
          arrange(average_temp) %>% 
          slice(1) %>% 
          mutate(tie = TRUE)
      }
      # return the optimal regime!
      optim
    }
  }
  
  # return the threshold summary where the regime is optimal, pivoting for 
  # n days info for ui
  ui_optimal <- threshold_summary %>% 
    filter(regime == optimal$regime) %>% 
    mutate(tie = unique(optimal$tie))
  
  # do some magic to make it read nicely for ui integration
  ui_optimal %>% 
    select(-min_max_temp) %>% 
    pivot_wider(names_from = summary,
                names_glue = "n_{summary}",
                values_from = n) 
}

plot_forecast_airtemp <- function(met_data, start_date) {
  
  # calculate end of-forecast-date
  end_date <- start_date + days(6)
  # calculate starting date (10 days prior)
  ten_day_prior_date <- start_date - days(10)
  
  # make figure
  met_data %>%
    filter(between(date, ten_day_prior_date, end_date)) %>%
    select(date, mean_temp_degC, max_temp_degC) %>%
    pivot_longer(cols = mean_temp_degC:max_temp_degC,
                 names_to = "air_temp_agg",
                 values_to = "value") %>%
    mutate(air_temp_agg = factor(air_temp_agg,
                                 levels = c("max_temp_degC", "mean_temp_degC"),
                                 labels = c("max", "mean"))) %>%
    ggplot(., aes(x = date, y = value, color = air_temp_agg)) +
    geom_rect(aes(xmin = start_date, xmax = end_date,
                  ymin = -Inf, ymax = Inf),
              fill = "grey90", alpha = 0.5, inherit.aes = FALSE) +
    geom_line() +
    labs(x = NULL, y = "air temperature\n(deg C)", color = "aggregation\ntype") +
    scale_color_tableau() +
    scale_x_date(date_breaks = "1 day", 
                 date_labels = "%B %d", 
                 date_minor_breaks = "1 day") +
    theme_bw() + 
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
}

plot_pump_forecast <- function(obs_pump, date_of_forecast) {
  prev_act <- obs_pump %>% 
    filter(between(date, date_of_forecast - days(10), date_of_forecast + days(6))) %>% 
    select(date, dow, act_pump_cfs = pump_cfs) %>% 
    mutate(observed = if_else(date < date_of_forecast, act_pump_cfs, NA_real_),
           control = if_else(date >= date_of_forecast, act_pump_cfs, NA_real_),
           zero = if_else(date >= date_of_forecast, 0, NA_real_),
           static = if_else(date >= date_of_forecast, 220, NA_real_),
           pulsed = case_when(date >= date_of_forecast & dow %in% c("Sat", "Sun") ~ 220,
                              date >= date_of_forecast & !dow %in% c("Sat", "Sun") ~ 440,
                              .default = NA_real_)) %>% 
    select(-act_pump_cfs) %>% 
    pivot_longer(cols = observed:pulsed,
                 names_to = "regime",
                 values_to = "cfs") %>% 
    mutate(regime = factor(regime, levels = c("control", "pulsed", "static", "zero", "observed")))
  
  ggplot(prev_act, aes(x = date, y = cfs, fill = regime)) +
    geom_rect(aes(xmin = date_of_forecast, xmax = date_of_forecast + days(6),
                  ymin = -Inf, ymax = Inf),
              fill = "grey90", alpha = 0.5, inherit.aes = FALSE) +
    geom_col(position = position_dodge(preserve = "single")) +
    labs(x = NULL, y = "average daily pump operation\n(cfs)") +
    scale_fill_tableau() +
    scale_x_date(date_breaks = "1 day", 
                 date_labels = "%B %d", 
                 date_minor_breaks = "1 day") +
    theme_bw() + 
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
}

plot_forecast_ns <- function(obs_temp_data, forecast_data, date_of_forecast) {
  # Get previous data
  previous_10_days <- obs_temp_data %>%
    filter(between(date, date_of_forecast - days(10), date_of_forecast - days(1)))
  
  # make plot
  forecast_data %>%
    map(.x = ., 
        .f = ~ .x %>% 
          filter(forecast_date == date_of_forecast)) %>% 
    bind_rows() %>% 
    summarize(mean_1m = mean(mean_1m_temp_degC),
              .by = c(valid_date, regime)) %>%
    ggplot(., aes(x = valid_date, y = mean_1m, color = regime)) +
    geom_rect(aes(xmin = date_of_forecast, xmax = date_of_forecast + days(6),
                  ymin = -Inf, ymax = Inf),
              fill = "grey90", alpha = 0.5, inherit.aes = FALSE) +
    geom_line() +
    geom_abline(slope = 0, intercept = 15, linetype = 2) +
    annotate("text", x = date_of_forecast - days(1), y = 14.8,
             label = "Algal Threshold (goal < 15°C, summer to fall)", hjust = 0, size = 4) +
    labs(x = NULL, y = "average near-suface (0-1m)\ntemperature, (deg C)") +
    scale_color_tableau() +
    scale_x_date(date_breaks = "1 day", date_labels = "%B %d", date_minor_breaks = "1 day") +
    geom_line(data = previous_10_days, inherit.aes = F, aes(x = date, y = mean_temp_ns)) +
    theme_bw() + 
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
  
}

plot_forecast_int <- function(obs_temp_data, forecast_data, date_of_forecast) {
  # Get previous data
  previous_10_days <- obs_temp_data %>%
    filter(between(date, date_of_forecast - days(10), date_of_forecast - days(1)))
  
  # make plot
  forecast_data %>%
    map(.x = ., 
        .f = ~ .x %>% 
          filter(forecast_date == date_of_forecast)) %>% 
    bind_rows() %>% 
    summarize(mean_int = mean(mean_0_5m_temp_degC),
              .by = c(valid_date, regime)) %>%
    ggplot(., aes(x = valid_date, y = mean_int, color = regime)) +
    geom_rect(aes(xmin = date_of_forecast, xmax = date_of_forecast + days(6),
                  ymin = -Inf, ymax = Inf),
              fill = "grey90", alpha = 0.5, inherit.aes = FALSE) +
    geom_line()+
    geom_abline(slope = 0, intercept = 14, linetype = 2) +
    annotate("text", x = date_of_forecast - days(1), y = 14.3,
             label = "Diatom Threshold (goal > 14°C, spring to early summer)", hjust = 0, size = 4) +
    labs(x = NULL, y = "average integrated (0-5m)\ntemperature, (deg C)") +
    scale_color_tableau() +
    scale_x_date(date_breaks = "1 day", date_labels = "%B %d", date_minor_breaks = "1 day") +
    geom_line(data = previous_10_days, inherit.aes = F, aes(x = date, y = mean_temp_int)) +
    theme_bw() + 
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
}

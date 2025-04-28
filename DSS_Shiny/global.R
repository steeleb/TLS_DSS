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


# Check if figures exist (using lapply for efficiency)
figure_exists <- sapply(figure_paths, file.exists)


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
  
  if (!dir.exists(data_path)) {
    return(character(0))
  }
  
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
  
  # Extract file extension
  file_ext <- tolower(tools::file_ext(filename))
  
  # Read file based on extension using switch
  data <- tryCatch({
    switch(file_ext,
           csv = read_csv(file_path),
           stop("Unsupported file format"))
  }, error = function(e) {
    message(paste("Error reading file:", filename, "-", e$message))
    NULL
  })
  
  return(data)
}



# TLS-DSS: Three Lakes System - Decision Support System
# Global settings and functions

# Load required libraries
library(shiny)
library(bslib)
library(DT)
library(tidyverse)

# GLOBAL FUNCTIONS ----

## list_data_files ----
# Function to list data files in the data_submodule directory
list_data_files <- function() {
  # Path to data directory (assuming it's at the same level as the app directory)
  data_path <- "www"
  
  # Check if directory exists
  if (!dir.exists(data_path)) {
    return(character(0))
  }
  
  # List all files with common data extensions
  files <- list.files(
    path = data_path,
    pattern = "\\.csv",
    full.names = FALSE
  )
  
  return(files)
}

## read_data_file ----
# Function to read data file
read_data_file <- function(filename) {
  # Full path to the file
  file_path <- file.path("../data_submodule/out/", filename)
  
  # Extract file extension
  file_ext <- tolower(tools::file_ext(filename))
  
  # Read file based on extension
  data <- tryCatch({
    if (file_ext == "csv") {
      read_csv(file_path) 
    } else {
      stop("Unsupported file format")
    }
  }, error = function(e) {
    NULL
  })
  
  return(data)
}

## Check for figures ----

# Check if figures exist in the output folder
water_balance_fig <- "www/water_balance.jpg"
stacked_flow_fig <- "www/stacked_flow.jpg"

has_water_balance <- file.exists(water_balance_fig)
has_stacked_flow <- file.exists(stacked_flow_fig)


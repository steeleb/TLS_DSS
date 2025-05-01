# Created by use_targets().

# Load packages required to define the pipeline:
library(targets)
library(tarchetypes) 

# Set global {targets} options:
tar_option_set(
  packages = c("tidyverse"),
  controller = crew::crew_controller_local(workers = 6, seconds_idle = 60)
)

# Source the upstream {target} groups
tar_source(files = c(
  "data_submodule/inflow_balance.R",  
  "data_submodule/covariates_temp.R"
))

# Full {targets} list (from above files)
c(inflow_water_balance,
  covariates_temp)
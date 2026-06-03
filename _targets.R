# Created by use_targets().

# Load packages required to define the pipeline:
library(targets)
library(tarchetypes) 

# Set global {targets} options:
tar_option_set(
  controller = crew::crew_controller_local(workers = 6, seconds_idle = 60)
)

# Source the upstream {target} groups
tar_source(files = c(
  "data_submodule/raw_data/buoy.R",  
  "data_submodule/raw_data/chipmunk.R",  
  "data_submodule/raw_data/east_inlet.R",  
  "data_submodule/raw_data/farr_pump.R",  
  "data_submodule/raw_data/north_fork.R",
  "data_submodule/raw_data/north_inlet.R",  
  "data_submodule/raw_data/tunnel_delivery.R"
))

# Full {targets} list (from above files)
c(buoy_tar,
  chipmunk_tar,
  east_inlet_tar,
  farr_pump_tar,
  north_fork_tar,
  north_inlet_tar,
  tunnel_delivery_tar)
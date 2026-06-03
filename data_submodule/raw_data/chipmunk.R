# Source functions for this {targets} list
tar_source("data_submodule/raw_data/src/")

chipmunk_tar <- list(
  
  tar_target(
    name = chipmunk_raw,
    command = get_NWIS_data_by_site(site_number = "09014050", 
                                    start_date = "2026-05-15T00:00",
                                    end_date = Sys.Date(),
                                    tz = "MST"),
    packages = c("dataRetrieval")
  ),
  
  # and pass the harmonize function to re-orient data
  tar_target(
    name = chipmunk,
    command = harmonize_NWIS_stream(chipmunk_raw),
    packages = c("dplyr", "stringr", "tidyr")
  ),

  tar_target(
    name = chipmunk_csv,
    command = {
      path <- "data_submodule/raw_data/target_output/chipmunk.csv"
      dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
      write_csv(chipmunk, path)
      path
    },
    format = "file",
    packages = "readr"
  )
)
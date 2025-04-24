# TSS-DSS: Main application file

# Source the global, UI, and server files
source("DSS_Shiny/global.R")
source("DSS_Shiny/ui.R")
source("DSS_Shiny/server.R")

# Run the application
shinyApp(ui = ui, server = server)

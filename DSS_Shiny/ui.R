# TLS-DSS: UI Definition

source("global.R")

# Define the UI
ui <- page_navbar(
  title = "TLS-DSS: Three Lakes System - Decision Support System",
  
  # Home tab ----
  nav_panel(
    title = "Home",
    card(
      card_header("TLS-DSS"),
      p("Welcome to the Three Lakes System - Decision Support System"),
      p("This application is under development.")
    )
  ),
  
  # Underlying Data tab ----
  nav_panel(
    title = "Underlying Data",
    card(
      card_header("Data Explorer"),
      fillable = TRUE,
      layout_sidebar(
        sidebar = sidebar(
          fillable = TRUE,
          width = 300,
          selectInput("displayOption", "Display Option:", 
                      choices = c("Show DataTable", "Show Water Balance Figure", "Show Stacked Flow Figure"),
                      selected = "Show Stacked Flow Figure"),
          
          # Only show data file selector when DataTable is selected
          conditionalPanel(
            condition = "input.displayOption == 'Show DataTable'",
            selectInput("dataFile", "Select Data File:", choices = list_data_files())
          )
        ),
        # Main content based on selected option
        div(
          class = "h-100 w-100",  # Make the div use 100% height and width
          uiOutput("dynamicContent", class = "h-100")
        )
      )
    )
  )
)

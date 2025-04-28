# TLS-DSS: UI Definition
source("global.R")

# Define the UI
ui <- page_navbar(
  title = "TLS-DSS: Three Lakes System Decision Support System",
  
  # Home tab ----
  nav_panel(
    title = "Home",
    card(
      card_header("TLS-DSS"),
      p("Welcome to the Three Lakes System Decision Support System"),
      p("This application is meant to provide decision-making context from a
        responsive data-informed model to estimate the impacts of varying
        pump operational regimes on the water temperature at Shadow Mountain
        Reservoir."),
      p("This application is under development and currently is being tested on
        data from the year 2024."),
      p("Use the navigation bar to access submodules (top right burger button 
        or along the top of the screen, depending on how large your screen is).")
    )
  ),
  
  # Data Submodule tab ----
  nav_panel(
    title = "Underlying Data",
    card(
      card_header("Data Explorer"),
      fillable = TRUE,
      layout_sidebar(
        sidebar = sidebar(
          fillable = TRUE,
          width = 300,
          selectInput("dataFile", "Select Data Table to Display:", 
                                  choices = list_data_files())
        ),
          
        # Main content based on selected option
        div(
          class = "h-100 w-100",  # Use full width/height
          uiOutput("dynamicContent", class = "h-100")
        )
      )
    )
  ),
  
  # Dialog Submodule ----
  nav_panel(
    title = "Dialog Submodule",
    card(
      layout_sidebar(
        sidebar = sidebar(
          width = 300,
          selectInput("selectedDate", "Select a Forecast Date:", choices = NULL)
        ),
        navset_card_tab(  # Use this to switch between tabs
          nav_panel(
            title = "Previous 7 Days Water Temperature",
            card(
              plotOutput("prevTempFigure", height = "400px")
            )
          ),
          nav_panel(
            title = "Previous 7 Days Flow",
            card(
              plotOutput("prevFlowFigure", height = "1200px")
            )
          ),
          nav_panel(
            title = "Previous 7 Days Flow, Aggregated Inflow/Outflow/Balance",
            card(
              plotOutput("prevFlowAggregated", height = "900px")
            )
          ),
          nav_panel(
            title = "Previous 7 Days Met",
            card(
              plotOutput("prevMetFigure", height = "900px")
            )
          ),
          nav_panel(
            title = "Data Tables",
            div(  # wrap the content directly here
              card(
                card_header("Observed Data (Previous 7 Days)"),
                dataTableOutput("prevDataTable")
              ),
              card(
                card_header("Forecasted Weather (Next 7 Days)"),
                dataTableOutput("forecastDataTable")
              )
            )
          )
        )
      )
    )
  )
)

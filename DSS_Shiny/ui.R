# TLS-DSS: UI Definition
source("global.R")

# Define the UI
ui <- page_navbar(
  fillable = TRUE,
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
      p(HTML("This app works best when used <strong><em>full-screen</em></strong>. Graphics will not
             render properly if used in minimized screen or on a mobile device.")),
      p("This application is under development and currently is being tested on
        data from the year 2024."),
    )
  ),
  
  # Data Submodule tab ----
  nav_panel(
    title = "Underlying Data",
    card(
      card_header("Data Explorer"),
      fillable = TRUE,
      layout_sidebar(
        border = FALSE,
        sidebar = sidebar(
          fillable = TRUE,
          width = 300,
          selectInput("dataFile", "Select Data Table to Display:", 
                      choices = list_data_files())
        ),
        
        # Main content based on selected option
        div(
          fillable = TRUE,
          uiOutput("dynamicContent", class = "h-100")
        )
      )
    )
  ),
  
  # Dialog Submodule ----
  nav_panel(
    title = "Previoius 30 Day Trends",
    card(
      layout_sidebar(
        sidebar = sidebar(
          width = 300,
          selectInput("selectedDate", "Select a Forecast Date:", choices = NULL)
        ),
        navset_card_tab(  # Use this to switch between tabs
          nav_panel(
            title = "Previous 30 Days Water Temperature",
            card(
              plotOutput("prevTempFigure", height = "400px")
            )
          ),
          nav_panel(
            title = "Previous 30 Days Flow",
            card(
              plotOutput("prevFlowFigure", height = "1200px")
            )
          ),
          nav_panel(
            title = "Previous 30 Days Flow, Aggregated Inflow/Outflow/Balance",
            card(
              plotOutput("prevFlowAggregated", height = "900px")
            )
          ),
          nav_panel(
            title = "Previous 30 Days Met",
            card(
              plotOutput("prevMetFigure", height = "900px")
            )
          ),
          nav_panel(
            title = "Data Tables",
            div(  # wrap the content directly here
              card(
                card_header("Observed Data (Previous 30 Days)"),
                dataTableOutput("prevDataTable")
              )
              # ,
              # card(
              #   card_header("Forecasted Weather (Next 7 Days)"),
              #   dataTableOutput("forecastDataTable")
              # )
            )
          )
        )
      )
    )
  ), 
  
  # Forecast Panel ----
  nav_panel(
    title = "Forecast Panel",
    layout_sidebar(
      sidebar = sidebar(
        width = "20%",
        dateInput(
          inputId = "forecast_date",
          label = "Select forecast start date:",
          value = as.Date("2024-07-15"),
          min = as.Date("2024-07-01"),
          max = as.Date("2024-08-31")
        ),
        uiOutput("pumping_summary")  # optionally in sidebar
      ),
      
      ## create a side panel for date selection and the uiOutput("pupming_summary")
      div(
        style = "min-height: 600px; height: 100%;",
        card(
          navset_card_tab(
            nav_panel(
              uiOutput("forecast_title"),
              plotOutput("fore_airtemp", height = "300px"),
              plotOutput("fore_ns", height = "300px"),
              plotOutput("fore_int", height = "300px"),
              p(class = "text-muted", textOutput("forecast_metadata"))
            )
            # ,
            # nav_panel(
            #   title = "Observed temperatures",
            #   plotOutput("fore_ns_actual", height = "300px"),
            #   plotOutput("fore_int_actual", height = "300px")
            # )
            
            ## add summary of model runs to this point in time.
          )
        )
      )
    ) 
  )
  ## add feature importance information/interpretation in additional hamburger
)

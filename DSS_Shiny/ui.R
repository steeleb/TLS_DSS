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
      p(),
      p("The 'Underlying Data' tab is the submodule that displays data used to 
        inform subsequent models and figures. The user may query daily meterologogy, 
        reservoir temperature, and inflow/outflow data."),
      p("The 'Previous 30 Day Trends' tab presents daily time series figures of 
        parameter subsets for the preceding 30 days, the end date of which users 
        can change with the dropdown menu to the left."),
      p("The 'Forecast Panel' tab displays the previous 10 days and a 7-day 
        forecast of water temperature under three pumping scenarios: the control
        (actual 2024 pump operation), static (a constant 220 cfs flow), and 
        pulsing (220 cfs flow on weekends, 440 cfs on weekdays)."),
      p("Forecasts are generated for the day selected on the left hand side of the
        screen. Below that selection is text that will indicate the optimal pumping
        regime based on the expert system, a brief explanation of how that regime
        was chosen as optimal, and an indication of how many days the forecasts
        met the goal threshold temperature for each depth horizon.")
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
    title = "Previous 30 Day Trends",
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
          value = ymd("2024-07-15"),
          min = ymd("2024-06-13"),
          max = ymd("2024-10-09")
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
              plotOutput("pump_ops_bars", height = "300px"),
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

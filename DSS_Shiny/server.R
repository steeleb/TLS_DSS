# TLS-DSS: Server Logic

source("global.R")

server <- function(input, output, session) {
  
  # Reactive value to store the current data
  current_data <- reactive({
    req(input$dataFile)
    read_data_file(input$dataFile)
  })
  
  
  # Dynamic content based on selected display option
  output$dynamicContent <- renderUI({
    if (input$displayOption == "Show DataTable") {
      navset_card_tab(
        nav_panel(
          title = "Data Table",
          DT::dataTableOutput("dataTable")
        ),
        nav_panel(
          title = "Summary",
          verbatimTextOutput("dataSummary")
        )
      )
    } else if (input$displayOption == "Show Water Balance Figure") {
      if (has_water_balance) {
        card(
          height = 700,
          full_screen = TRUE,
          card_header("Three Lakes System Water Balance"),
          card_body(
            fill = FALSE, gap = 0,
            p(class = "text-muted", "Shadow Mountain Reservoir and Grand Lake 
              surface water height and water balance (average daily inflow - 
              average dailyoutflow) in the Three Lakes System.")
          ),
          card_body(
            imageOutput("waterbalancefigure"),
            class = "p-0"
          )
        )
      } else {
        card(
          card_header("Three Lakes System Water Balance"),
          div(
            style = "padding: 20px; text-align: center;",
            h4("Water Balance figure not found"),
            p("The file 'data_submodule/out/water_balance.jpg' does not exist.")
          )
        )
      }
    } else if (input$displayOption == "Show Stacked Flow Figure") {
      if (has_stacked_flow) {
        card(
          height = 700,
          full_screen = TRUE,
          card_header("Three Lakes System Stacked Flow"),
          card_body(
            fill = FALSE, gap = 0,
            p(class = "text-muted", "Average flow per day across the Three Lakes 
              System.")
          ),
          card_body(
            imageOutput("stackedflowfigure"),
            class = "p-0"
          )
        )
      } else {
        card(
          card_header("Three Lakes System Stacked Flow"),
          div(
            style = "padding: 20px; text-align: center;",
            h4("Stacked Flow figure not found"),
            p("The file 'data_submodule/out/stacked_flow.jpg' does not exist.")
          )
        )
      }
    }
  })
  
  # Render the figure images
  output$waterbalancefigure <- renderImage({
    list(src = water_balance_fig,
         contentType = "image/jpeg",
         width = "80%",
         alt = "Water Balance Figure")
  }, deleteFile = FALSE)
  
  output$stackedflowfigure <- renderImage({
    list(src = stacked_flow_fig,
         contentType = "image/jpeg",
         width = "80%",
         alt = "Stacked Flow Figure")
  }, deleteFile = FALSE)
  
  # Display data table
  output$dataTable <- DT::renderDataTable({
    req(current_data())
    DT::datatable(
      current_data(), 
      options = list(
        pageLength = 10,
        scrollX = TRUE,
        scrollY = "400px"
      ),
      rownames = FALSE
    )
  })
  
  # Display data summary
  output$dataSummary <- renderPrint({
    req(current_data())
    
    # Check if data is available
    if (is.null(current_data())) {
      cat("Error loading data.")
      return(NULL)
    }
    
    # Print basic information
    cat("Rows:", nrow(current_data()), "\n")
    cat("Columns:", ncol(current_data()), "\n\n")
    
    # Print column names and types
    cat("Column Information:\n")
    col_info <- sapply(current_data(), class)
    for (i in seq_along(col_info)) {
      cat(names(col_info)[i], ": ", paste(col_info[[i]], collapse = ", "), "\n")
    }
    
    # Print summary if not too large
    if (ncol(current_data()) <= 10) {
      cat("\nSummary Statistics:\n")
      print(summary(current_data()))
    }
  })
  
}

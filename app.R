# Load required libraries
library(shiny)
library(ggplot2)
library(dplyr)
library(lubridate)
library(DT)

# Define UI
ui <- fluidPage(
  titlePanel("Mountain Project Tick Pyramid"),
  
  sidebarLayout(
    sidebarPanel(
      fileInput("file", "Upload your ticks data (CSV format)",
                accept = c(".csv")),
      tags$hr(),
      checkboxInput("redpoints_only", "Filter to 'sends'", TRUE),
      selectInput("date_min", "Select beginning of date range", choices = NULL),
      selectInput("date_max", "Select end of date range", choices = NULL),
      tags$hr(),
      h5("Instructions: Upload a CSV file containing your climbing data with at
         least 'Date', 'Lead Style', and 'Rating Code' columns.")
    ),
    
    mainPanel(
      tabsetPanel(
        tabPanel("Data Table", DTOutput("table")),
        tabPanel("Route Pyramid", plotOutput("gradePlot")),
        tabPanel("Max Grade Over Time", plotOutput("timePlot"))
      )
    )
  )
)

# Define server logic
server <- function(input, output, session) {
  
  # Reactive expression to read the uploaded file
  data <- reactive({
    req(input$file)
    raw <- read.csv(input$file$datapath, check.names=FALSE)
    clean <- raw %>%
      mutate(YDS=cut(
        `Rating Code`,
        breaks=c(0, 1700, 1900, 2200, 2500, 2800, 3100, 3400, 4500, 4800,
                 5100, 5400, 6500, 6800, 7100, 7400, 8500, 8800, 9100,
                 9400, 10400),
        labels=c("5.easy", "5.7", "5.8", "5.9", "5.10a", "5.10b", "5.10c", "5.10d",
                 "5.11a", "5.11b", "5.11c", "5.11d", "5.12a", "5.12b",
                 "5.12c", "5.12d", "5.13a", "5.13b", "5.13c", "5.13d"))) %>%
      mutate(Redpoint=case_when(
        `Lead Style` %in% c("Redpoint", "Pinkpoint", "Onsight", "Flash") ~ "Y",
        TRUE ~ "N")) %>%
      mutate(Date=ymd(Date))
    clean
  })
  
  # Update dropdown options for plotting
  observe({
    df <- data()
    date_range <- pretty(range(df$Date), n=18)
    z <- length(date_range)
    updateSelectInput(session, "date_min", choices=date_range, selected=date_range[1])
    updateSelectInput(session, "date_max", choices=date_range, selected=date_range[z])
  })
  
  # Render data table
  output$table <- renderDT({
    req(data())
    df <- data() %>%
      select(Date, Route, YDS, `Route Type`, `Lead Style`, Redpoint)
    datatable(df)
  })
  
  # Render grade distribution plot
  output$gradePlot <- renderPlot({
    req(data())
    if (input$redpoints_only){
      df <- filter(data(), Redpoint=="Y")
    } else {
      df <- data()
    }
    df <- df %>%
      filter(!is.na(YDS)) %>%
      filter(between(Date, ymd(input$date_min), ymd(input$date_max))) %>%
      group_by(YDS) %>%
      summarise(count=n())
    pyramid.df <- bind_rows(
      mutate(df, count=count, dummy="A"),
      mutate(df, count=-count, dummy="B"))
    count_range <- range(pyramid.df$count)
    count_range_seq <- pretty(count_range, n=5)
    ggplot(pyramid.df, aes(x=count, y=YDS, group=dummy)) +
      geom_col(fill="lightblue", color="darkblue") +
      labs(title="Route-Climbing Pyramid", x="Routes", y="Grade") +
      scale_x_continuous(breaks=count_range_seq, labels=abs(count_range_seq)) +
      theme_minimal()
  })
  
  # Render climbing frequency over time plot
  output$timePlot <- renderPlot({
    req(data())
    df <- data()
    df$date <- as.Date(df$date)  # Convert to Date format
    df_summary <- df %>%
      group_by(date) %>%
      summarize
  })
}

shinyApp(ui = ui, server = server)
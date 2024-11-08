# Load required libraries
library(shiny)
library(ggplot2)
library(plotly)
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
      textInput("user_url", label="Or, copy/paste your Profile URL", value="",
                placeholder="https://www.mountainproject.com/user/USERNUM/USER-NAME"),
      tags$hr(),
      checkboxInput("redpoints_only", "Filter to 'Redpoints Only'", TRUE),
      h6("'Redpoints' include only the following: Flash, Onsight,
         Redpoint, Pinkpoint"),
      selectInput("date_min", "Select beginning of date range", choices = NULL),
      selectInput("date_max", "Select end of date range", choices = NULL),
      tags$hr(),
      h5("Instructions: Upload a CSV file containing your ticks data (exported
         from MountainProject.com), or paste the URL of your Mountain Project
         profile page (the page that displays your profile picture).")
    ),
    
    mainPanel(
      tabsetPanel(
        tabPanel("Data Table", DTOutput("table")),
        tabPanel("Route Pyramid", plotlyOutput("gradePlot")),
        tabPanel("Max Grade Over Time", plotlyOutput("timePlot"))
      )
    )
  )
)

# Define server logic
server <- function(input, output, session) {
  
  # Reactive expression to read the uploaded file
  data <- reactive({
    if (input$user_url != ""){
      req(input$user_url)
      url <- gsub("\\/$", "", input$user_url)
      raw <- read.csv(paste0(url, "/tick-export"), check.names=FALSE)
    } else {
      req(input$file)
      raw <- read.csv(input$file$datapath, check.names=FALSE)
    }
    clean <- raw %>%
      mutate(YDS=cut(
        `Rating Code`,
        breaks=c(0, 1700, 1900, 2200, 2500, 2800, 3100, 3400, 4500, 4800,
                 5100, 5400, 6500, 6800, 7100, 7400, 8500, 8800, 9100,
                 9400, 10400),
        labels=c("5.easy", "5.7", "5.8", "5.9", "5.10a", "5.10b", "5.10c", "5.10d",
                 "5.11a", "5.11b", "5.11c", "5.11d", "5.12a", "5.12b",
                 "5.12c", "5.12d", "5.13a", "5.13b", "5.13c", "5.13d"),
        ordered_result=TRUE)) %>%
      filter(!is.na(YDS)) %>%
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
  output$gradePlot <- renderPlotly({
    req(data())
    if (input$redpoints_only){
      df <- filter(data(), Redpoint=="Y")
    } else {
      df <- data()
    }
    df <- df %>%
      filter(between(Date, ymd(input$date_min), ymd(input$date_max))) %>%
      group_by(YDS) %>%
      summarise(Count=n())
    pyramid.df <- bind_rows(
      mutate(df, Count=Count, dummy="A"),
      mutate(df, Count=-Count, dummy="B"))
    count_range <- range(pyramid.df$Count)
    count_range_seq <- pretty(count_range, n=5)
    p <- ggplot(pyramid.df, aes(x=Count, y=YDS, group=dummy)) +
      geom_col(fill="lightblue", color="darkblue") +
      labs(title="Route-Climbing Pyramid", x="Routes", y="Grade") +
      scale_x_continuous(breaks=count_range_seq, labels=abs(count_range_seq)) +
      theme_minimal()
    ggplotly(p, tooltip=c("y", "x"))
  })
  
  # Render climbing frequency over time plot
  output$timePlot <- renderPlotly({
    req(data())
    if (input$redpoints_only){
      df <- filter(data(), Redpoint=="Y")
    } else {
      df <- data()
    }
    cummax.df <- df %>%
      group_by(Date) %>%
      summarise(day_max=max(`Rating Code`)) %>%
      arrange(Date) %>%
      mutate(max_code=cummax(day_max)) %>%
      mutate(YDS=cut(
        max_code,
        breaks=c(0, 1700, 1900, 2200, 2500, 2800, 3100, 3400, 4500, 4800,
                 5100, 5400, 6500, 6800, 7100, 7400, 8500, 8800, 9100,
                 9400, 10400),
        labels=c("5.easy", "5.7", "5.8", "5.9", "5.10a", "5.10b", "5.10c", "5.10d",
                 "5.11a", "5.11b", "5.11c", "5.11d", "5.12a", "5.12b",
                 "5.12c", "5.12d", "5.13a", "5.13b", "5.13c", "5.13d"),
        ordered_result=TRUE)) %>%
      mutate(grade_rank=dense_rank(YDS))
    p <- ggplot(cummax.df, aes(x=Date, y=grade_rank, label=YDS)) +
      geom_step(color="darkblue", direction="vh") +
      labs(title="Max Grade Over Time", x="Date", y="Grade") +
      scale_y_continuous(
        breaks=cummax.df$grade_rank,
        labels=cummax.df$YDS) +
      theme_minimal()
    ggplotly(p, tooltip=c("x", "label"))
  })
}

shinyApp(ui = ui, server = server)
# Load required libraries
library(shiny)
library(ggplot2)
library(plotly)
library(dplyr)
library(lubridate)
library(DT)

# Define UI
ui <- fluidPage(
  titlePanel("Tick Pyramid Tool 🏔️ 📈"),
  
  sidebarLayout(
    sidebarPanel(
      fileInput("file", "Upload your tick data (CSV format)",
                accept = c(".csv")),
      textInput("user_url", label="Or, copy/paste your profile URL", value="",
                placeholder="https://www.mountainproject.com/user/USERNUM/USER-NAME"),
      h5("Instructions: Upload a CSV file containing your ticks data (exported
         from MountainProject.com), or paste the URL of your Mountain Project
         profile page (the page that displays your profile picture)."),
      tags$hr(),
      h5("Note: The 'Redpoint' category includes onsights and flashes."),
      checkboxInput("unique", "Filter to unique routes only", value=TRUE),
      selectInput("type", "Filter route type", choices=c("", "Sport", "Trad", "TR"),
                  selected=""),
      selectInput("date_min", "Select beginning of date range", choices=NULL),
      selectInput("date_max", "Select end of date range", choices=NULL),
      tags$hr(),
      h6("DISCLAIMER: This tool is not affiliated with Mountain Project or OnX
         and is for individual climber use only.")
    ),
    
    mainPanel(
      tabsetPanel(
        tabPanel("Data Table", DTOutput("table")),
        tabPanel("Route Pyramid", plotlyOutput("gradePlot")),
        tabPanel("My Progression", plotlyOutput("timePlot"))
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
      url <- gsub("\\/ticks$", "", url)
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
      mutate(Redpoint=factor(case_when(
        `Lead Style` %in% c("Redpoint", "Pinkpoint", "Onsight", "Flash") ~ "Y",
        TRUE ~ "N"))) %>%
      mutate(Date=ymd(Date))
    if (input$type != ""){
      clean <- clean %>%
        filter(grepl(input$type, `Route Type`))
    }
    if (input$unique){
      clean <- clean %>%
        group_by(URL, Route, `Route Type`, `Rating Code`, YDS, Location) %>%
        arrange(desc(Redpoint), desc(Date), .by_group=TRUE) %>%
        summarise(
          Date=first(Date),
          `Lead Style`=first(`Lead Style`),
          Redpoint=first(Redpoint)) %>%
        ungroup()
    }
    arrange(clean, desc(Date))
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
      filter(between(Date, ymd(input$date_min), ymd(input$date_max))) %>%
      select(Date, Route, YDS, `Route Type`, Location, `Lead Style`, Redpoint)
    datatable(df, filter="top", options=list(
      dom="ltp",
      pageLength=20,
      lengthMenu=c(20, 50, 100)),
      rownames=FALSE)
  })
  
  # Render grade distribution plot
  output$gradePlot <- renderPlotly({
    req(data())
    df <- data()
    pyramid.df <- df %>%
      filter(between(Date, ymd(input$date_min), ymd(input$date_max))) %>%
      group_by(YDS, Redpoint) %>%
      summarise(Count=n()) %>%
      mutate(xcount=case_when(
        Redpoint=="Y" ~ Count,
        Redpoint=="N" ~ -Count))
    count_range <- range(pyramid.df$Count)
    count_range_seq <- c(-pretty(count_range, n=5), pretty(count_range, n=5))
    p <- ggplot(pyramid.df, aes(x=xcount, y=YDS, group=Redpoint, label=Count)) +
      geom_col(aes(fill=Redpoint, color=Redpoint)) +
      scale_fill_manual(values=c("lightblue", "pink")) +
      scale_color_manual(values=c("darkblue", "darkred")) +
      labs(title="Route Climbing Pyramid", x="Routes", y="Grade") +
      scale_x_continuous(limits=c(-max(pyramid.df$Count), max(pyramid.df$Count)),
                         breaks=count_range_seq, labels=abs(count_range_seq)) +
      theme_minimal()
    ggplotly(p, tooltip=c("group", "y", "label")) %>%
      layout(
        legend=list(
          itemclick=FALSE,
          itemdoubleclick=FALSE,
          groupclick=FALSE),
        xaxis=list(fixedrange=TRUE),
        yaxis=list(fixedrange=TRUE)) %>%
      config(displayModeBar=FALSE)
  })
  
  # Render climbing frequency over time plot
  output$timePlot <- renderPlotly({
    req(data())
    df <- data() %>%
      mutate(grade_rank=dense_rank(YDS))
    cummax.df <- df %>%
      filter(Redpoint == "N") %>%
      group_by(Date) %>%
      summarise(day_max=max(`Rating Code`), max_rank=max(grade_rank)) %>%
      arrange(Date) %>%
      mutate(max_code=cummax(day_max), grade_rank=cummax(max_rank)) %>%
      mutate(Redpoint="N")
    cummax.df.redpoint <- df %>%
      filter(Redpoint == "Y") %>%
      group_by(Date) %>%
      summarise(day_max=max(`Rating Code`), max_rank=max(grade_rank)) %>%
      arrange(Date) %>%
      mutate(max_code=cummax(day_max), grade_rank=cummax(max_rank)) %>%
      mutate(Redpoint="Y")
    cummax.df.all <- bind_rows(
      cummax.df,
      cummax.df.redpoint) %>%
      mutate(YDS=cut(
        max_code,
        breaks=c(0, 1700, 1900, 2200, 2500, 2800, 3100, 3400, 4500, 4800,
                 5100, 5400, 6500, 6800, 7100, 7400, 8500, 8800, 9100,
                 9400, 10400),
        labels=c("5.easy", "5.7", "5.8", "5.9", "5.10a", "5.10b", "5.10c", "5.10d",
                 "5.11a", "5.11b", "5.11c", "5.11d", "5.12a", "5.12b",
                 "5.12c", "5.12d", "5.13a", "5.13b", "5.13c", "5.13d"),
        ordered_result=TRUE))
    p <- ggplot(cummax.df.all, aes(x=Date, y=grade_rank, group=Redpoint, label=YDS)) +
      geom_step(aes(color=Redpoint), direction="vh") +
      scale_color_manual(values=c("darkblue", "darkred")) +
      labs(title="Max Grades Over Time", x="Date", y="Grade") +
      scale_y_continuous(
        breaks=df$grade_rank,
        labels=df$YDS) +
      theme_minimal()
    ggplotly(p, tooltip=c("group", "label", "x")) %>%
      layout(
        legend=list(
          itemclick=FALSE,
          itemdoubleclick=FALSE,
          groupclick=FALSE),
        xaxis=list(fixedrange=TRUE),
        yaxis=list(fixedrange=TRUE)) %>%
      config(displayModeBar=FALSE)
  })
}

shinyApp(ui = ui, server = server)
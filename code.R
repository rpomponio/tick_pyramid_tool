library(dplyr)
library(lubridate)
library(plotly)
library(rvest)

# read csv of route ticks
ticks <- read.csv("ticks.csv")
ticks$Date <- ymd(ticks$Date)

# create standardized grade labels
ticks <- ticks %>%
  mutate(Grade.YDS=cut(
    Rating.Code,
    c(0, 1700, 1900, 2200, 2500, 2800, 3100, 3400, 3700, 4800, 5100, 5400, 5500,
      6800, 7100, 7400, 7500),
    c("5.easy", "5.7", "5.8", "5.9", "5.10a", "5.10b", "5.10c", "5.10d",
      "5.11a", "5.11b", "5.11c", "5.11d", "5.12a", "5.12b", "5.12c", "5.12d")))

# filter by discipline, style, redpoint, and date climbed
ticks.filtered <- ticks %>%
  filter(Route.Type=="Sport") %>%
  filter(Style=="Lead") %>%
  filter(Lead.Style %in% c("Onsight", "Redpoint", "Flash")) %>%
  filter(Date >= ymd("2021-01-01"))
  
# reduce to unique routes
routes.unique <- ticks.filtered %>%
  group_by(URL) %>%
  summarise(
    Date=min(Date),
    Route=first(Route),
    Pitches=max(Pitches),
    Location=first(Location),
    Avg.Stars=first(Avg.Stars),
    Style=first(Style),
    Length=min(Length),
    Grade.YDS=first(Grade.YDS))

# for any routes where only one pitch was climbed, filter out multi-pitch routes
routes.unique$Mutli <- 1 * as.numeric(routes.unique$Pitches > 1)
for (i in 1:nrow(routes.unique)){
  if (routes.unique$Mutli[i]==0){
    url <- routes.unique$URL[i]
    html <- read_html(url)
    tbls <- html %>% html_nodes("table") %>% html_table()
    desc <- unlist(tbls[[2]][1, 2])
    multi <- grepl("pitches", desc)
    routes.unique$Mutli[i] <- 1 * as.numeric(multi)
  }
}

# tally counts for each grade, excluding multi-pitch sport climbs
routes.unique <- filter(routes.unique, Mutli==0)
routes.counts <- rev(table(routes.unique$Grade.YDS))

# Funnel Chart (Plotly terminology))  
fig <- plot_ly() %>%
  add_trace(
    type="funnel",
    name="",
    y=names(routes.counts),
    x=routes.counts,
    hovertemplate="You've sent %{x} routes at %{y}.") %>%
  layout(
    title=list(text="<br>Sport Climbing <span style='color:red'>Redpoint</span> Pyramid"),
    yaxis=list(categoryarray=names(routes.counts)))
fig














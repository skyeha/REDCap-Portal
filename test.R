library(shiny)

# Define UI for application that plots random distributions
ui <- pageWithSidebar(

  # Application title
  headerPanel("It's Alive!"),

  # Sidebar with a slider input for number of observations
  sidebarPanel(
    sliderInput("bins",
                  "Number of bins:",
                  min = 1,
                  max = 50,
                  value = 30)
  ),

  # Show a plot of the generated distribution
  mainPanel(
    plotOutput("distPlot", height=250)
  )
)

server <- function(input, output) {
    output$distPlot <- renderPlot({
    x    <- faithful[, 2]  # Old Faithful Geyser data
    bins <- seq(min(x), max(x), length.out = input$bins + 1)

    # draw the histogram with the specified number of bins
    hist(x, breaks = bins, col = 'darkgray', border = 'white')
  })
}

shinyApp(ui = ui, server = server)
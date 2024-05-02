library(shiny)

# Define server logic
server <- function(input, output) {
  
  # Example: Create a reactive expression to generate a plot based on user input
  output$plot <- renderPlot({
    # Generate a scatter plot using the input values
    plot(input$x, input$y, main = "Scatter Plot", xlab = "X", ylab = "Y")
  })
  
}

# Run the application
shinyApp(ui, server)

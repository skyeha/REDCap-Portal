install.packages(shiny)


ui <- fluidPage(
    includeMarkdown("test.Rmd")
)

ui
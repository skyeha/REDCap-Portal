library(shiny)


ui <- fluidPage(
    fluidRow(
          actionButton(inputId='toRegistry',
            label="Back to registry",
            icon = icon("th"),
            onclick= "window.history.back()")
        ),
    includeMarkdown("test.Rmd")
)

ui
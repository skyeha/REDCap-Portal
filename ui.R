library(shiny)
library(shinydashboard)
library(stringr)



shinyUI(
    dashboardPage(
        dashboardHeader(title="Clinical Dashboard"),
        dashboardSidebar(
            sliderInput("bins", "Number of bins:", min= 1, max=50, value=30)
        ),
        dashboardBody(
            plotOutput("distPlot", height=250)
        )
    )
)
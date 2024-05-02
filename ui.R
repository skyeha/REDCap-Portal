library(shiny)
library(shinydashboard)


# Define UI for application
ui <- dashboardPage(
  skin = "purple",
  # Application title
  dashboardHeader(title = "Clinical Dashboard"),
  
  # Sidebar with a menu
  dashboardSidebar(
    
    # Sidebar menu
    sidebarMenu(
      
      # Sidebar menu item for a dashboard page
      menuItem("Welcome", tabName = "welcome", icon = icon("home")),
      menuItem("Map & Suburb Info", tabName = "map_suburb_info", icon = icon("dashboard")),
      menuItem("Kaplan-Meier Plot", tabName = "km_plot", icon = icon("th"))
      
    )
    
  ),
  
  # Body content
  dashboardBody(
    tags$head(tags$style(HTML("
    /* CSS styles to apply globally*/
    p {
      margin-bottom: 5px;
    }"))), 
    # Main dashboard tab content
    tabItems(
      
      # Dashboard tab
      tabItem(
        tabName = "welcome",
        fluidRow(tags$div(tags$strong("Welcome!"), style = "font-size:22px")),
        
        # Example: Create a box with some content
        box(
          title = "My Dashboard",
          "This is the content of my dashboard."
        )
        
      )
      
      # Add more tabItems for additional dashboard pages
      
    )
    
  )
  
)

# Return the UI object
ui

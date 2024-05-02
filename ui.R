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
        fluidRow(HTML(r"(
          <p style="font-size:16px">This is a Clinical Dashboard that offers multiple interactive visualisations </p>
          <p style="font-size:16px;">By inputing a standard RedCap project's API, this dashboard automatically generate mutiple visualization to provide user a better understanding of the studied disease.</p>
          <p style="font-size:16px;">Currently, it allows user to view disease distribution by suburb through a interactive map that supports Melbourne and entire Victora region. 
          It also provides a Kaplan-Meier Plot that compare the effects of most commonly used two medicine on patient's death rate.</p>
          <p style="font-size:16px;">You can preview its effect by selecting three defaultly provided database. You can find the original RedCap through link below.
          Notice that all of these database use stimulated data generated from <a href="https://github.com/synthetichealth/synthea" target="_blank">Synthea<sup>TM</sup></a>, a synthetic patient generator that models the medical history of synthetic patients, for testing purpose.</p>
          <br></br>
        )")),
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

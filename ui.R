library(shiny)
library(shinydashboard)


# Define UI for application
ui <- dashboardPage(
  skin = "purple"
  # Application title
  dashboardHeader(title = "Clinical Dashboard"),
  
  # Sidebar with a menu
  dashboardSidebar(
    
    # Sidebar menu
    sidebarMenu(
      
      # Sidebar menu item for a dashboard page
      menuItem("Dashboard", tabName = "dashboard", icon = icon("dashboard"))
      
      # Add more menu items if needed
      # menuItem("Page 2", tabName = "page2", icon = icon("file")),
      # menuItem("Page 3", tabName = "page3", icon = icon("info"))
      
    )
    
  ),
  
  # Body content
  dashboardBody(
    
    # Main dashboard tab content
    tabItems(
      
      # Dashboard tab
      tabItem(
        tabName = "dashboard",
        
        # Dashboard content goes here
        
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

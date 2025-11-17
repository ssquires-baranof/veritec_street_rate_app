library(shinyjs)
library(dplyr)
library(shinyWidgets)
library(bs4Dash)
library(reactable)
library(fresh)
library(highcharter)

library(shinyauthr)
library(DT)

options(spinner.color="#13213D", spinner.color.background="#efefef", spinner.size=2)
options(digits=10)




theme <- create_theme(
  
  bs4dash_status(
    primary = "#efefef",
    secondary = "#13213D",
    warning = "#efefef"
  ),
  
  bs4dash_sidebar_light (
    hover_bg = "#efefef",
    hover_color = "#13213D"
  ),
  
  bs4dash_sidebar_dark(
    hover_bg = "#13213D",
    hover_color = "#efefef"
  ))



shinyUI(dashboardPage(
  
  freshTheme = theme,
  fullscreen = TRUE,
  help = FALSE,
  title = "Street Rate Puller",
  header = dashboardHeader(
    skin='dark',
    controlbarIcon = icon("wand-sparkles", lib= "font-awesome"),
    title =  dashboardBrand(
      title = "_",
      color = "primary",
      image = "https://www.baranofholdings.com/images/logo.png",
      
    ),
    useShinyjs(),
    #use_login(),
    rightUi = tags$li(class = "dropdown", shinyauthr::logoutUI(id = "logout"))
  ),
  
  sidebar = dashboardSidebar(
    skin = "light",
    elevation = 3,
    sidebarMenu(
      sidebarHeader("Veritec"),
      menuItem(
        "Status",
        tabName = "status",
        icon = icon("mountain", lib= "font-awesome")
      ),
      menuItem(
        "New Request",
        tabName = "inputs",
        icon = icon("mountain-city", lib= "font-awesome")
      )
      
    )
  ),
  controlbar =  dashboardControlbar(
    id = "controlbar",
    collapsed = T,
    fileInput("store_list_upload", "Choose Store List", accept = c(".csv")),
    selectizeInput(
      inputId = "store_list",
      label = "Stores to Include",
      choices = c("Extra Space", "Public Storage",	"CubeSmart", "U-Haul"),
      selected = NULL,
      multiple = TRUE,
      width = "100%",
      options = list(
        'plugins' = list('remove_button'),
        'create' = TRUE,
        'persist' = TRUE
      )
    ),
    selectizeInput(
      inputId = "exclude_list",
      label = "Stores to Exclude",
      choices = c("Sparefoot", "Extra Space", "Public Storage",	"CubeSmart", "U-Haul"),
      selected = NULL,
      multiple = TRUE,
      width = "100%",
      options = list(
        'plugins' = list('remove_button'),
        'create' = TRUE,
        'persist' = TRUE
      )
    ),
    numericInput( 
      "radius", 
      "Radius (Miles)", 
      value = 5, 
      min = 1, 
      max = 50 
    ),
    dateInput("start_date", "Start Date:", value = Sys.Date()-months(1)),
    actionButton(inputId = "comp_request", label = "Submit Comp Request")
  ),
  body = dashboardBody(
    shinyauthr::loginUI("login"),
    tags$head(
      tags$link(rel = "stylesheet", type = "text/css", href = "styles.css"),
      tags$script(
        "$(document).on('shiny:inputchanged', function(event) {
          if (event.name != 'changed') {
            Shiny.setInputValue('changed', event.name);
          }
        });"
      )#,
      #includeHTML(("google-analytics.html"))
    ),
    tags$style(type = "text/css", 
               ".content-wrapper { background-color: #ffffff !important;}
               .sidebar, .sidebar-light .brand-link, .navbar-white {background-color: #efefef !important;}
               .sidebar-light .brand-link .bg-primary{border-bottom: none!important;}
               div.small-box.bg-primary, .bg-primary {margin: 0; border: none}
               .card {background-color: #efefef !important; border: 2px, solid, #075481; box-shadow: none !important; border-radius: 6px}
               .card-header{border-radius: 0px; background-color: #075481; color: #ffffff;}
               .card-title {font-family:'freight-sans-pro', font-weight: 600; sans-serif; letter-spacing:.1em; font-size:.9rem!important;}
               .brand-image {border-radius: 0 !important;box-shadow: none !important;}
               .control-sidebar-slide-open .control-sidebar, .control-sidebar-slide-open .control-sidebar::before 
               {padding: 10px !important;background-color: #efefef !important;} 
              .ReactTable {background-color: #13213D !important;}
              .bg-primary .nav-link {color: #fff;  font-family: 'freight-sans-pro', sans-serif; font-weight: 600; margin: 10px}
              .bg-primary .nav-link.active, .bg-primary .nav-link:hover, .bg-primary .nav-link:focus {background-color: #ffffff !important; color: #13213D !important; transition: 0.5s ease;}
              .bg-primary, .bg-primary a {color: #fff !important}
              "
    ),
    #useShinyjs(),
    
    
    tabItems(
      tabItem(
        tabName = "status",
        fluidRow(
          column(12, 
                 
                 tabBox(
                   width = 12, collapsible = FALSE,
                   maximizable=FALSE,
                   background = "primary",
                   tabPanel(title = "Request Queue"),
                   tabPanel(title = "Completed Requests")
                   #tabPanel(
                   # title = "Sales Chart"
                   #)
                 )
          )
        )
      ),
      tabItem(
        tabName = "inputs",
        fluidRow(
          column(12, 
                 
                 tabBox(
                   width = 12, collapsible = FALSE,
                   maximizable=FALSE,
                   background = "primary",
                   tabPanel(title = "Store List", 
                            reactableOutput("store_list"))
                 )
          )
        )
      )
      
      
      
      
      
      
    ) #items
  ) #body
) #page
) # ui
#
# This is the server logic of a Shiny web application. You can run the
# application by clicking 'Run App' above.
#
# Find out more about building applications with Shiny here:
#
#    https://shiny.posit.co/
#

library(shiny)
library(duckdb)
library(reticulate)
library(sodium)
library(tibble)
con <- dbConnect(duckdb())
dbGetQuery(con, 'INSTALL delta; LOAD delta; INSTALL aws;INSTALL httpfs;')

dbGetQuery(con, 'CREATE SECRET (
        TYPE s3,
        PROVIDER credential_chain
    );')

virtualenv_create("virtualenvs")

py_install("deltalake", envname = "vtsr_app_env")
py_install("pyarrow", envname = "vtsr_app_env")
py_install("pandas", envname = "vtsr_app_env")
py_install("asyncio", envname = "vtsr_app_env")
py_install("playwright", envname = "vtsr_app_env")
py_install("boto3", envname = "vtsr_app_env")
py_install("tenacity", envname = "vtsr_app_env")
use_virtualenv("vtsr_app_env")
source_python("veritec_street_rate.py")
dl <- import("deltalake")

system("playwright install")



user_tbl <- tibble(
  user_name = c("u", "andrew", "shane", "allison", "eric", "hank", "blake", "lauren"),
  password  = c(password_store("baranof1!"), password_store("baranof1!"),
                password_store("27"), password_store("baranof1!"), 
                password_store("baranof1!"), password_store("baranof1!"),
                password_store("baranof1!"),
                password_store("baranof1!")),
  group = c("g", "baranof","baranof", "trunk", "baranof", "baranof", "trunk", "baranof")
) 

# Define server logic required to draw a histogram
function(input, output, session) {
  
  logout_init <- shinyauthr::logoutServer(
    id = "logout",
    active = reactive(credentials()$user_auth)
  )
  
  credentials <- shinyauthr::loginServer(
    id = "login",
    data = user_tbl,
    user_col = user_name,
    pwd_col = password,
    sodium_hashed = TRUE,
    log_out =  reactive(logout_init())
    
  )
  
  
  #### FULL APP WRAPPED IN THIS  
  observeEvent(
    credentials()$user_auth, {
      
      req(credentials()$user_auth)
      showNotification(paste("Hi! ", credentials()$info$user_name, "! You Are Logged In."), duration = 5)
      
    })
  
  
  #### FULL APP WRAPPED IN THIS  ^^^
  observeEvent(logout_init(), {
    showNotification(paste("Bye! You Are Now Logging Out."), duration = 5)
    Sys.sleep(1.5)
    session$reload()
    
  })
  
  rv <- reactiveValues(
    
    store_list = NULL,
    include = NULL,
    exclude = NULL,
    start_date = NULL,
    lat = NULL,
    lon = NULL,
    rad = NULL,
    statuses = NULL
    
  )


  observeEvent(
    list(input$store_list_upload,
         credentials()$user_auth)
    
    ,{
    if (!is.null(input$store_list_upload)) {
      # Process the uploaded file, e.g., read it
      rv$store_list <- read.csv(input$store_list_upload$datapath)
      
      output$store_list <- renderReactable({
        sticky_style <- list(backgroundColor = "#f7f7f7")
        
        reactable(rv$store_list
                  )
        
      })
    }
  })
  
  observeEvent(
    list(
      input$comp_request
    ),{
      req(rv$store_list)
      req(input$radius)
      
      showModal(
        modalDialog(
          title = "Confim?",
          paste("Requesting ", nrow(rv$store_list), " stores. ", round(as.numeric(Sys.Date() - input$start_date) / 30.25, 2),
                " months of history"),
          footer = tagList(
            modalButton("Cancel"), # A button to dismiss the modal
            actionButton("finalizeStreetRateRequest", "OK") # The "OK" button
          )
        )
      )
      
      
      
      
    }
  )
  

  
  observeEvent(
    input$finalizeStreetRateRequest,
    {

      req(rv$store_list)
      req(input$radius)
      removeModal()
      #rv$lat <- as.character(rv$store_list[i, "Latitude"])
      #rv$lon <- as.character(rv$store_list[i, "Longitude"])
      rv$exclude <- as.list(input$exclude_list)
      rv$include <- as.list(input$store_list)
      print("include")
      print(rv$include)
      rv$start_date <- as.character(input$start_date)
      rv$rad <- as.character(input$radius)
      
      if(length(rv$include) == 0){
        rv$statuses <- veritec_all_street_rate_runner(rv$exclude, rv$store_list, rv$rad, rv$start_date)
      } else {
        rv$statuses <- veritec_street_rate_runner(rv$include, rv$exclude, rv$store_list, rv$rad, rv$start_date)
      }
        
    }
  )
  
  observeEvent(rv$statuses, {
    showNotification(paste0(rv$statuses[1], " ", rv$statuses[2]), type = "message", duration = 5)
  })
  
  

}

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
library(paws.application.integration)
library(clock)

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
py_install("numpy", envname = "vtsr_app_env")
py_install("deltalake", envname = "vtsr_app_env")
use_virtualenv("vtsr_app_env")
source_python("veritec_street_rate.py")
dl <- import("deltalake")

system("playwright install")
system("playwright install-deps")



user_tbl <- tibble(
  user_name = c("u", "andrew", "shane", "allison", "eric", "hank", "blake", "lauren"),
  password  = c(password_store("baranof1!"), password_store("baranof1!"),
                password_store("27"), password_store("baranof1!"), 
                password_store("baranof1!"), password_store("baranof1!"),
                password_store("baranof1!"),
                password_store("baranof1!")),
  group = c("g", "baranof","baranof", "trunk", "baranof", "baranof", "trunk", "baranof")
) 

get_request_status <- function() {
  
  df <- dbGetQuery(con, "SELECT * FROM delta_scan('s3://baranof-veritec/street-rate/bronze/requests')") 
  
  return(df)
}

svc <- paws.application.integration::sqs()

queue_url <- "https://sqs.us-east-1.amazonaws.com/247376099496/baranof-street-rate.fifo"

sqs_process <- function() {
  
  response <- svc$receive_message(
    QueueUrl = queue_url,
    MaxNumberOfMessages = 10, # Fetch one message at a time
    WaitTimeSeconds = 10 # Use long polling for up to 10 seconds
  )
  
  sqs_count <- length(response$Messages)
  
  
  
  if (!is.null(response$Messages) && sqs_count > 0) {
    
    most_recent_sqs <- response$Messages[[sqs_count]]
    message_body <- most_recent_sqs$Body
    receipt_handle <- most_recent_sqs$ReceiptHandle
    time <- jsonlite::fromJSON(message_body)$time
    
    print(paste("Received message:", message_body))
    
    # Optionally, delete the message from the queue after processing
    svc$delete_message(
      QueueUrl = queue_url,
      ReceiptHandle = receipt_handle
    )
    print("Message deleted from queue.")
    
    time_sqs <- fromJSON(message_body)$time
    
    current_time <- date_now("UTC")
    
    sqs_time_diff <- as.numeric(difftime(ymd_hms(current_time),ymd_hms(time_sqs), units = "hours"))
    
    runnit <- if(sqs_time_diff<=.5) {TRUE} else {FALSE}
    
    return(runnit)
    
  } else {
    print("No messages received.")
    return(FALSE)
  }
}

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
    statuses = NULL,
    request_hist = NULL,
    runnit = FALSE
    
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
      credentials()$user_auth
      removeModal()
      #rv$lat <- as.character(rv$store_list[i, "Latitude"])
      #rv$lon <- as.character(rv$store_list[i, "Longitude"])
      rv$exclude <- as.list(input$exclude_list)
      rv$include <- as.list(input$store_list)
      print("include")
      print(rv$include)
      rv$start_date <- as.character(input$start_date)
      rv$rad <- as.character(input$radius)
      
      
      rv$statuses <- tryCatch({
          veritec_street_rate_runner(rv$include, rv$exclude, rv$store_list, 
                                     rv$rad, rv$start_date, input$chunk_size, input$frequency, "adhoc")
        }, 
        error = function(e) {
          message("An error occurred: ", e$message)
          message("An error occurred: ", reticulate::py_last_error())
          
        }
        )
        
    }
  )
  
  observeEvent(rv$statuses, {
    showNotification(paste0(rv$statuses[1], " ", rv$statuses[2]), type = "message", duration = 5)
  })
  
  observeEvent(
    list(
      credentials()$user_auth),
    {
      req(credentials()$user_auth)
  rv$request_hist <- get_request_status()
  
  output$requests <- renderDT({
    datatable(rv$request_hist, options = list(scrollX = TRUE))
  })
    })
  
  observeEvent(
    list(input$get_requests,
         credentials()$user_auth),
               {
                 req(credentials()$user_auth)
                 rv$request_hist <- get_request_status()
                 replaceData(dataTableProxy("requests"), rv$request_hist, resetPaging = FALSE)
               })
  
  
  ###
  ###. BARANOF AUTO RUN
  ###
  ## every ten minutes
  poll_interval <- 600000
  
  observe({
    invalidateLater(poll_interval, session)
    
    rv$runnit <- sqs_process()
    
    if(rv$runnit == T) {
      
      current_date = ymd(now(tz = 'UTC') |> as_date())
      
      
      last_upload_date <- as_date(dbGetQuery(con, 
                                              "SELECT upload_date FROM 
                                        delta_scan('s3://baranof-veritec/baranof-street-rate/bronze/history_day')
                                        order by upload_date desc limit 1")$upload_date)
      
      days_since_upload <- as.numeric(current_date - last_upload_date, units = 'days')
      
      baranof_store_list <-  dbGetQuery(con, "SELECT latitude Latitude, longitude Longitude FROM 
                                        delta_scan('s3://baranof-landing/gold/assets')") 
      
      if(days_since_upload > 0) {
        rv$statuses <- tryCatch({
          veritec_street_rate_runner(baranof_store_list, list("Sparefoot"), list(), "5", 
                                     last_upload_date, 10000, "Daily", 
                                     "baranof")
        }, 
        error = function(e) {
          message("An error occurred: ", e$message)
          message("An error occurred: ", reticulate::py_last_error())
          
        }
        )
        
      }
      
    }
    
    
  })
  
  

}

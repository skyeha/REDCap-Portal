library(mongolite)
library(forcats)
library(tidyr)
library(dplyr)
library(leaflet)
library(maps)
library(sf)
library(ggplot2)
library(shiny)
library(shinydashboard)
library(survival)
library(survminer)
library(ggfortify)
library(plotly)
library(ggsurvfit)
library(stringr)

mongo_connection <- function(collection) {
  mongolite::mongo(
    collection = collection,
    # the url consist with username password host_ip port and db_name
    url = "mongodb://AdminCD:iwannasleep@115.146.84.81:27017/Redcap?authSource=admin"
  )
}

# Example to fetch data
fetch_data <- function(collection) {
  conn <- mongo_connection(collection)
  data <- conn$find('{}')
  return(data)
}

heart_disease_data <- fetch_data("heartdisease")
diabetes_data<- fetch_data("diabetes")
non_standard_data <- fetch_data("non_standard")
#setup requirements for geomap
melbourne_suburbs_name <- c(
  "Carlton", "Carlton North", "Docklands", "East Melbourne",
  "Flemington", "Kensington", "Melbourne", "North Melbourne",
  "Parkville", "Port Melbourne", "Southbank", "South Wharf",
  "South Yarra", "West Melbourne", "Albert Park", "Balaclava",
  "Elwood", "Middle Park", "Ripponlea", "St Kilda", "St Kilda East",
  "St Kilda West", "South Melbourne", "Abbotsford", "Alphington",
  "Burnley", "Clifton Hill", "Collingwood", "Cremorne", "Fairfield",
  "Fitzroy", "Fitzroy North", "Princes Hill", "Richmond"
)
melbourne_suburbs <- st_read("data/sf/vic_localities.shp")

melbourne_suburbs <- melbourne_suburbs[melbourne_suburbs$LOC_NAME
                                       %in% melbourne_suburbs_name, ] #enable this line to view only melbourne county

#function to tidyup csv and return 3 dataframes for visualization: geomap_data, km_data, and info_data
get_tidy_dataframe <- function(data) {
  
  #split the dataframe into a list of dataframes based on the values in 'redcap_repeat_instrument'
  df_list <- split(data, data$redcap_repeat_instrument)
  
  df_patient <- df_list[[1]]
  df_condition <- df_list[["conditions"]]
  df_medication <- df_list[["medications"]]
  
  #choose a condition (the most popular one)
  observe_condition <- names(table(df_condition$description_condition))[which.max(table(df_condition$description_condition))]
  
  #check whether patient is a survivor
  df_patient$survivor <- ifelse(df_patient$deathdate_patient == "", 0, 1) 
  
  #shorten the name for ethnicity
  df_patient <- df_patient %>%
    mutate(ethnicity_patient = case_when(
      ethnicity_patient == "Aboriginal and Torres Strait Islander" ~ "Aboriginal",
      TRUE ~ ethnicity_patient
    ))
  
  #get basic info TBC
  total_patient <- nrow(df_patient)
  total_medication_record <- nrow(df_medication)
  
  #2. filter out the required column for geo map
  # Intended structure of geo_data
  match_data <- data.frame(
    Id = character(),
    RACE = character(),
    GENDER = character(),
    ETHNICITY = character(),
    INCOME = numeric(),
    HEALTHCARE_EXPENSES = numeric(),
    HEALTHCARE_COVERAGE = numeric(),
    Suburb = character(),
    VALUE = numeric(),
    stringsAsFactors = FALSE
  )
  
  column_mapping <- c(
    id_patient = "Id",
    race_patient = "RACE",
    gender_patient = "GENDER",
    ethnicity_patient = "ETHNICITY",
    income_patient = "INCOME",
    healthcare_expenses_patient = "HEALTHCARE_EXPENSES",
    healthcare_coverage_patient = "HEALTHCARE_COVERAGE",
    county_patient = "Suburb",
    survivor = "VALUE"
  )
  
  geo_data <- df_patient %>%
    select(any_of(names(column_mapping))) %>%
    rename_all(~ column_mapping[.]) %>%
    mutate(INCOME = as.numeric(INCOME),
           HEALTHCARE_EXPENSES = as.numeric(HEALTHCARE_EXPENSES),
           HEALTHCARE_COVERAGE = as.numeric(HEALTHCARE_COVERAGE))
  
  # Add missing columns with all NA values
  missing_columns <- setdiff(names(match_data), names(geo_data))
  for (col in missing_columns) {
    geo_data[[col]] <- NA
  }
  
  
  #3. filter out the required column for Kaplan Meier
  km_data_patient <- df_patient %>%
    select(Id = id_patient, end_date = deathdate_patient, Status = survivor)
  
  km_data_condition <- df_condition %>%
    select(Id = id_patient, condition = description_condition, start_date = start_condition)
  
  km_data_medication <- df_medication %>%
    select(Id = id_patient, group = description_medication)
  
  km_data <- km_data_patient %>%
    full_join(km_data_condition, by = "Id", relationship =
                "many-to-many") %>%
    full_join(km_data_medication, by = "Id", relationship =
                "many-to-many")
  
  #fill missing end_date to today
  km_data$end_date[is.na(km_data$end_date)] <- format(Sys.Date(), format = "%Y-%m-%d")
  
  #calculate survive days by end_date - start_date and assign it to a new column called Times
  km_data$start_date <- as.Date(km_data$start_date, format = "%Y-%m-%d")
  km_data$end_date <- as.Date(km_data$end_date, format = "%Y-%m-%d")
  km_data$Time <- as.integer(km_data$end_date - km_data$start_date)
  
  #filter out two most common group for comperation
  sorted_km_data <- sort(table(km_data$group), decreasing = TRUE)
  drugs_of_interest <- names(sorted_km_data)[1:2]
  filtered_km_data <- km_data[km_data$group %in% drugs_of_interest, ]
  
  #drop repeat info and those Time is negative (dates are entered incorrectly)
  filtered_km_data <- unique(filtered_km_data)
  filtered_km_data <- filtered_km_data[filtered_km_data$Time >= 0, ]
  
  
  #4.output a basic info dataframe
  info_df <- data.frame(
    condition = observe_condition,
    total_patient = total_patient,
    total_medication_record = total_medication_record,
    row.names = NULL
  )
  return(list(geo_data = geo_data, km_data = filtered_km_data, info_df = info_df))
}

#function to get kaplan meier plot
get_kaplan_meier_plot <- function(data, time_unit = "Day") {
  if (time_unit == "Year") {
    data$Time <- data$Time / 365.25  # Convert days to years
  } else if (time_unit == "Month") {
    data$Time <- data$Time / 30.44  # Convert days to months
  }
  
  data = data.frame(Time = data$Time, Status = data$Status,group = data$group)
  km_fit <- surv_fit(Surv(Time, Status) ~ group, data=data)
  # if there is exactly two group then we can use the logrank test 
  whetherlogranktest = (length(unique(data$group))==2)
  pvalue_text = ""
  if(whetherlogranktest){
    pvalue = toString(round(survdiff(Surv(Time, Status) ~ group, data=data)$pvalue,8))
    pvalue_text = paste0("logrank pvalue: \n ",pvalue)
  }
  
  p = autoplot(km_fit, censor.shape = "+", censor.alpha = 0) + 
    labs(x = paste("\n Survival Time in", time_unit) , y = "Survival Probabilities \n", 
         title = paste("Kaplan Meier plot")) + 
    ylim(0, 1) +
    annotate("text", x=max(data$Time)/5, y=0, label= pvalue_text)+
    
    theme(plot.title = element_text(face="bold",hjust = 0.5), 
          axis.title.x = element_text(face="bold", colour="darkgreen", size = 11),
          axis.title.y = element_text(face="bold", colour="darkgreen", size = 11),
          legend.title = element_text(face="bold", size = 10))+
    scale_color_viridis_d()
  
  
  # ggplot do not developed for CI
  ggplotly(p)
}

shinyServer(
    function(input, output, session) {
  
  #load local data
  geo_data1 <- get_tidy_dataframe(heart_disease_data)$geo_data
  km_data1 <- get_tidy_dataframe(heart_disease_data)$km_data
  info_df1 <- get_tidy_dataframe(heart_disease_data)$info_df
  
  geo_data2 <- get_tidy_dataframe(diabetes_data)$geo_data
  km_data2 <- get_tidy_dataframe(diabetes_data)$km_data
  info_df2 <- get_tidy_dataframe(diabetes_data)$info_df
  
  geo_data3 <- get_tidy_dataframe(non_standard_data)$geo_data
  km_data3 <- get_tidy_dataframe(non_standard_data)$km_data
  info_df3 <- get_tidy_dataframe(non_standard_data)$info_df
  
  # Reactive values to manage data filtering
  filtered_data <- reactive({
    switch(input$databaseSelect,
           "Ischemic Heart Disease in Melbourne" = km_data1,
           "Diabetes in Melbourne" = km_data2,
           "Non-Standard Database" = km_data3)
  })
  
  patient_data <- reactive({
    switch(input$databaseSelect,
           "Ischemic Heart Disease in Melbourne" = geo_data1,
           "Diabetes in Melbourne" = geo_data2,
           "Non-Standard Database" = geo_data3)
  })
  
  info_df <- reactive({
    switch(input$databaseSelect,
           "Ischemic Heart Disease in Melbourne" = info_df1,
           "Diabetes in Melbourne" = info_df2,
           "Non-Standard Database" = info_df3)
  })

  # Extracting condition from info_df reactive object
  # Define condition as a reactive value
  condition <- reactive({
    info_df()$condition
  })
  
  # Define total_patient as a reactive value
  total_patient <- reactive({
    info_df()$total_patient
  })
  
  melbourne_suburbs <- melbourne_suburbs
  
  # Make agg_data a reactive expression
  agg_data <- reactive({
    patient_data() %>%
      group_by(Suburb) %>%
      summarize(
        all_patients = n(),
        male_count = sum(GENDER == "1"),
        female_count = sum(GENDER == "2"),
        ratio = all_patients / total_patient()
      )
  })
  # Join the data with melbourne_suburbs inside a reactive expression
  melbourne_suburbs_data <- reactive({
    left_join(melbourne_suburbs, agg_data(), by = c("LOC_NAME" = "Suburb"))
  })

  #output
  output$databaseName1 <- renderText({
    condition()
  })
  
  output$databaseName2 <- renderText({
    condition()
  })
  
  output$melbourneMap <- renderLeaflet({
    bins <- seq(0, total_patient() / 10, by = 10)
    pal <- colorBin("YlGn", domain = melbourne_suburbs_data()$all_patients, bins = bins)
    
    leaflet(data = melbourne_suburbs_data()) %>%
      addProviderTiles("CartoDB.Positron") %>%
      addPolygons(
        layerId = ~ LOC_PID,
        fillColor = ~ pal(all_patients),
        weight = 2,
        opacity = 1,
        color = "white",
        dashArray = "3",
        fillOpacity = 0.7,
        highlight = highlightOptions(
          weight = 5,
          color = "#666",
          dashArray = "",
          fillOpacity = 0.7,
          bringToFront = TRUE
        ),
        label = ~ LOC_NAME,
        labelOptions = labelOptions(
          style = list("font-weight" = "normal", padding = "3px 8px"),
          textsize = "15px",
          direction = "auto"
        )
      ) %>%
      addLegend(
        pal = pal,
        values = ~ all_patients,
        opacity = 0.7,
        title = "Number of patients",
        position = "bottomright"
      )
  })
  
  observe({
    # when hover on
    hover_suburb_LOC_PID <- input$melbourneMap_shape_mouseover$id
    update_suburb_info(hover_suburb_LOC_PID)
  })
  
  observeEvent(input$melbourneMap_shape_click, {
    # when click on
    clicked_suburb_LOC_PID <- input$melbourneMap_shape_click$id
    update_heatmap(clicked_suburb_LOC_PID)
  })
  
  # Rendering the Kaplan-Meier plot
  output$kmPlot <- renderPlotly({
    # Use the reactive filtered_data
    plot_data <- filtered_data()
    get_kaplan_meier_plot(plot_data, 'Year')
  })
  
  
  update_suburb_info <- function(selected_suburb_LOC_PID) {
    output$suburbInfo <- renderUI({
      if (is.null(selected_suburb_LOC_PID)) {
        return(tags$div(""))
      } else {
        selected_suburb <- melbourne_suburbs_data()[melbourne_suburbs_data()$LOC_PID == selected_suburb_LOC_PID,]
        return(tags$div(
          tags$strong(selected_suburb$LOC_NAME, style = "font-size: 20px;"),
          tags$div(
            paste0(
              "Total number of patients: ", selected_suburb$all_patients),
            style = "font-size: 16px;"
          ),
          tags$div(
            paste0("Raito of patients: ", selected_suburb$ratio),
            style = "font-size: 16px;"
          ),
          tags$div(
            paste0("Females: ", selected_suburb$female_count),
            style = "font-size: 16px;"
          ),
          tags$div(
            paste0("Males: ", selected_suburb$male_count),
            style = "font-size: 16px;"
          ),
          style = "line-height: 1.5;" 
        ))
      }
    })
  }
  
  # Function to update heatmap
  update_heatmap <- function(suburb_id) {
    output$suburbNameHeatmap <- renderUI({
      if (is.null(suburb_id)) {
        return(HTML(r"(Select one suburb to view heatmaps.)"))
      } else {
        selected_suburb <- melbourne_suburbs_data()[melbourne_suburbs_data()$LOC_PID == suburb_id,]
        return(tags$div(
          tags$strong(
            "Heatmaps for ", selected_suburb$LOC_NAME, style = "font-size: 20px;")
        ))
      }
    })
    
    if (is.null(suburb_id)) {
      return(NULL)
    } else {
      selected_suburb <- melbourne_suburbs_data()[melbourne_suburbs_data()$LOC_PID == suburb_id,]
      patient_data_selected_suburb <- patient_data()[patient_data()$Suburb == selected_suburb$LOC_NAME,]
      
      hm_race_survival_aggregated_data <- patient_data_selected_suburb %>%
        dplyr::group_by(ETHNICITY, VALUE) %>%
        tally()
      
      
      output$raceSurvivalPlot <- renderPlot({
        
        ggplot(hm_race_survival_aggregated_data,
               aes(
                 x = ETHNICITY,
                 y = as.factor(VALUE),
                 fill = n
               )) +
          geom_tile() +
          geom_text(aes(label = n), vjust = -0.3) +
          scale_fill_gradient(low = "#CAE1FF",
                              high = "slateblue4",
                              name = "Count",
                              labels = scales::number_format(accuracy = 1)) +
          labs(title = "Race vs. Survival Heatmap",
               x = "Ethnicity",
               y = "Survival") +
          scale_y_discrete(labels=c("No", "Yes")) +
          theme(
            plot.title = element_text(face="bold"),
            axis.text.x = element_text(angle = 90, vjust = 0.5),
            axis.text.y = element_text(color = "black"))
      })
      
      income_breaks <- c(0, 40000, 50000, 70000, 100000, 999999999)
      income_range_labels <- c("0-30k", "30-50k", "50-70k", "70-100k", ">100k")
      patient_data_selected_suburb$IncomeRange <- cut(patient_data_selected_suburb$INCOME, breaks = income_breaks, labels = income_range_labels, right = FALSE, include.lowest = TRUE)
      
      hm_income_range_survival_aggregated_data <- patient_data_selected_suburb %>%
        dplyr::group_by(IncomeRange, VALUE) %>%
        tally()
      
      output$incomeRangeSurvivalPlot <- renderPlot({
        ggplot(hm_income_range_survival_aggregated_data,
               aes(
                 x = IncomeRange,
                 y = as.factor(VALUE),
                 fill = n
               )) +
          geom_tile() +
          geom_text(aes(label = n), vjust = -0.3) +
          scale_fill_gradient(low = "#CAE1FF",
                              high = "slateblue4",
                              name = "Count",
                              labels = scales::number_format(accuracy = 1)) +
          labs(title = "Income Range vs. Survival Heatmap",
               x = "Income range",
               y = "Survival") +
          scale_y_discrete(labels=c("No", "Yes")) +
          theme(
            plot.title = element_text(face="bold"),
            axis.text.x = element_text(angle = 90, vjust = 0.5),
            axis.text.y = element_text(color = "black"))
      })
      
      healthcare_expenses_breaks <- c(0, 50000, 100000, 200000, 500000, 1000000, 2000000, 999999999)
      healthcare_expenses_labels <- c("0-50k", "50-100k", "100-200k", "200-500k", "500-1M", "1M-2M",">2M")
      patient_data_selected_suburb$HealthcareExpensesRange <- cut(patient_data_selected_suburb$HEALTHCARE_EXPENSES, breaks = healthcare_expenses_breaks, labels = healthcare_expenses_labels, right = FALSE, include.lowest = TRUE)
      
      hm_healthcare_expenses_survival_aggregated_data <- patient_data_selected_suburb %>%
        dplyr::group_by(HealthcareExpensesRange, VALUE) %>%
        tally()
      
      output$healthcareExpensesSurvivalPlot <- renderPlot({
        ggplot(hm_healthcare_expenses_survival_aggregated_data,
               aes(
                 x = HealthcareExpensesRange,
                 y = as.factor(VALUE),
                 fill = n
               )) +
          geom_tile() +
          geom_text(aes(label = n), vjust = -0.3) +
          scale_fill_gradient(low = "#CAE1FF",
                              high = "slateblue4",
                              name = "Count",
                              labels = scales::number_format(accuracy = 1)) +
          labs(title = "Healthcare Expenses vs. Survival Heatmap",
               x = "Healthcare expenses",
               y = "Survival") +
          scale_y_discrete(labels=c("No", "Yes")) +
          theme(
            plot.title = element_text(face="bold"),
            axis.text.x = element_text(angle = 90, vjust = 0.5),
            axis.text.y = element_text(color = "black"))
      })
    }
  }
}
    
)
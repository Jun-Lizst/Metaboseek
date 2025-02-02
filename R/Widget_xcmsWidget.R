#' xcmsWidget
#' 
#' server module for accessing the xcms data analysis workflow
#' 
#' @inherit MseekWidgets
#' @describeIn xcmsWidget Server logic
#' @param externalFilegroups A data.frame with columns \code{File}
#'  and \code{Group}, specifying files to analyze by xcms. Will be ignored if 
#'  files were loaded from within the xcmsWidget.
#' 
#' @return Returns nothing
#' 
#' @import shiny
#' @import shinydashboard
#' @importFrom shinyjs toggleState
#' @import shinyFiles
#' @import rhandsontable
#' 
#' @examples 
#' \dontrun{
#' library(shiny)
#' 
#' ui <- xcmsWidgetUI("xcmsGUI")
#' 
#' server <- function(input, output) {
#'   
#'   callModule(xcmsWidget, "xcmsGUI", 
#'              static = list(servermode = F,
#'                            rootpath = .MseekOptions$filePaths,
#'                            activateXCMS = T,
#'                            filePattern = .MseekOptions$filePattern))
#' }
#' # Create Shiny app ----
#' shinyApp(ui, server)
#' 
#' }
#' 
#' @export 
xcmsWidget <- function(input,output, session,
                       externalFilegroups = reactive({NULL}),
                       static = list(servermode = F,
                                     rootpath = .MseekOptions$filePaths,
                                     activateXCMS = T,
                                     filePattern = .MseekOptions$filePattern,
                                     defaultSettings = "Metaboseek_defaults")
){
  
  ns <- NS(session$ns(NULL))
  
  internalStatic <- c(list(Mversion =  1),
                      static)
  
  
  internalValues <- reactiveValues(params = list(filegroups = data.frame(File = character(1), Group = character(1), stringsAsFactors = F),
                                                 centWave = read.csv(system.file("config", "xcms", static$defaultSettings, "centWave.csv",package = "Metaboseek"),
                                                                     row.names = 1,
                                                                     stringsAsFactors = F),
                                                 group = read.csv(system.file("config", "xcms", static$defaultSettings, "group.csv",package = "Metaboseek"),
                                                                  row.names = 1,
                                                                  stringsAsFactors = F),
                                                 retcor = read.csv(system.file("config", "xcms", static$defaultSettings, "retcor.csv",package = "Metaboseek"),
                                                                   row.names = 1,
                                                                   stringsAsFactors = F),
                                                 outputs = read.csv(system.file("config", "xcms", static$defaultSettings, "outputs.csv",package = "Metaboseek"),
                                                                    row.names = 1,
                                                                    stringsAsFactors = F),
                                                 peakfilling = read.csv(system.file("config", "xcms", static$defaultSettings, "peakfilling.csv",package = "Metaboseek"),
                                                                        row.names = 1,
                                                                        stringsAsFactors = F),
                                                 camera = read.csv(system.file("config", "xcms", static$defaultSettings, "camera.csv",package = "Metaboseek"),
                                                                   row.names = 1,
                                                                   stringsAsFactors = F)
  ),
  defaultDescription = readLines(system.file("config", "xcms", static$defaultSettings, "description.txt", package = "Metaboseek")),
  wd = character(),
  active = "centWave",
  jobs = NULL,
  viewjob = NULL,
  xcmsModule_loaded = F,
  noRtCorrAnaCheck = T,
  rtCorrAnaCheck = T)
  
  output$defaultSelector <- renderUI({
      
      tagList(selectizeInput(ns("selDefault"), "Use default settings", choices = list.dirs(system.file("config", "xcms", package = "Metaboseek"),
                                                                   recursive = FALSE,
                                                                   full.names = FALSE),
                             selected = static$defaultSettings)
      )
      
      })
  
  observeEvent(input$selDefault,{
      if(!is.null(input$selDefault) && input$selDefault != ""){
      
      internalValues$params <- list(filegroups = internalValues$params$filegroups,
                    centWave = read.csv(system.file("config", "xcms",
                                                    input$selDefault, "centWave.csv",package = "Metaboseek"),
                                        row.names = 1,
                                        stringsAsFactors = F),
                    group = read.csv(system.file("config", "xcms",
                                                 input$selDefault, "group.csv",package = "Metaboseek"),
                                     row.names = 1,
                                     stringsAsFactors = F),
                    retcor = read.csv(system.file("config", "xcms",
                                                  input$selDefault, "retcor.csv",package = "Metaboseek"),
                                      row.names = 1,
                                      stringsAsFactors = F),
                    outputs = read.csv(system.file("config", "xcms",
                                                   input$selDefault, "outputs.csv",package = "Metaboseek"),
                                       row.names = 1,
                                       stringsAsFactors = F),
                    peakfilling = read.csv(system.file("config", "xcms",
                                                       input$selDefault, "peakfilling.csv",package = "Metaboseek"),
                                           row.names = 1,
                                           stringsAsFactors = F),
                    camera = read.csv(system.file("config", "xcms",
                                                  input$selDefault, "camera.csv",package = "Metaboseek"),
                                      row.names = 1,
                                      stringsAsFactors = F)
      )
      internalValues$defaultDescription <- readLines(system.file("config", "xcms",
                                                                input$selDefault, "description.txt",
                                                                package = "Metaboseek"))
      }
      }, ignoreInit = TRUE, ignoreNULL = TRUE)
  
  
  output$defaultDescription <- renderUI({
      
      lapply(internalValues$defaultDescription,p)
      
  })
  
  observeEvent(externalFilegroups(),{
    
    #if raw files are loaded into the MS viewer, load them in here as well
    if(length(externalFilegroups()) >0 
       &&  is(externalFilegroups(),"data.frame") 
       && !internalValues$xcmsModule_loaded #only do this if loadFolder button in xcms module hasnt been used yet
    ){
      internalValues$params$filegroups <- externalFilegroups()[,c("File", "Group")]
      internalValues$params$filegroups$File <- as.character(internalValues$params$filegroups$File)
      internalValues$params$filegroups$Group <- as.character(internalValues$params$filegroups$Group)
      tryCatch({
        internalValues$wd <- get_common_dir(internalValues$params$filegroups$File)  
      },
      error = function(e){
        message("Settings file did not contain file paths.")
      })
      
      internalValues$active <- "filegroups"
      
    }
  })
  
  observeEvent(input$xcms_settingsLoad$datapath,{
    
    exfolder = file.path(dirname(input$xcms_settingsLoad$datapath),
                         gsub("\\.[^.]*$","",input$xcms_settingsLoad$name))
    
    unzip(input$xcms_settingsLoad$datapath, exdir = exfolder )
    
    newfiles <- list.files(exfolder, pattern=".csv", recursive = TRUE, full.names=T)
    
    for( i in newfiles){
      internalValues$params[[gsub("\\.[^.]*$","",basename(i))]] <- read.csv(i,
                                                                            row.names = 1,
                                                                            stringsAsFactors = F)
    }
    
    if(file.exists(file.path(exfolder, "postProcessingSettings.json"))){
      ppOptions <- jsonlite::unserializeJSON(readChar(file.path(exfolder, "postProcessingSettings.json"),
                                                      file.info(file.path(exfolder, "postProcessingSettings.json"))$size))
      
      for(i in names(ppOptions)){
        if(i %in% c("rtCorrAnaCheck", "noRtCorrAnaCheck")){
          internalValues[[i]] <- ppOptions[[i]]
        }else{
          tAnalysisX[[i]] <- ppOptions[[i]]
        }
        
      }
    }
    
    tryCatch({
      internalValues$wd <- get_common_dir(internalValues$params$filegroups$File)
        internalValues$xcmsModule_loaded <- T
        },
    error = function(e){
      message("Settings file did not contain file paths.")
    })
    
    internalValues$params$filegroups$File <- as.character(internalValues$params$filegroups$File)
    internalValues$params$filegroups$Group <- as.character(internalValues$params$filegroups$Group)
    
    
    #if an old outputs.csv file is loaded, replace it with the new default.
    if(ncol(internalValues$params$outputs) < 5) {
      internalValues$params$outputs <- read.csv(system.file("config", "xcms", input$selDefault,"outputs.csv",package = "Metaboseek"),
                                                row.names = 1,
                                                stringsAsFactors = F)
    }
  })
  
  
  output$xcms_settingsDL <- downloadHandler(filename= function(){paste("settings.zip")}, 
                                            content = function(file){
                                              
                                              
                                              flist = paste0(names(internalValues$params),".csv")
                                              for(i in 1:length(internalValues$params)){
                                                write.csv(internalValues$params[[i]], file = flist[i], row.names = T)
                                              }
                                              
                                              posSettings <- reactiveValuesToList(tAnalysisX)
                                              posSettings$rtCorrAnaCheck <- internalValues$rtCorrAnaCheck
                                              posSettings$noRtCorrAnaCheck <- internalValues$noRtCorrAnaCheck
                                              
                                              write(jsonlite::serializeJSON(posSettings, pretty = T), "postProcessingSettings.json")
                                              flist <- c(flist,"postProcessingSettings.json")
                                              
                                              
                                              zip(file, flist, flags = "-j")
                                              if(file.exists(paste0(file, ".zip"))) {file.rename(paste0(file, ".zip"), file)}
                                            },
                                            contentType = "application/zip")
  
  
 
  observe({
    shinyjs::toggleState(id = "xcms_start", condition = length(internalValues$wd)>0 && (!internalStatic$servermode || (internalStatic$servermode && internalStatic$activateXCMS)))
  })
  
  shinyFiles::shinyDirChoose(input, 'xcms_loadfolder', session = session, roots=internalStatic$rootpath)
  
  
  observeEvent(input$xcms_loadfolder,{
    fol <-  shinyFiles::parseDirPath(roots=internalStatic$rootpath, input$xcms_loadfolder)
    if(length(fol)>0 &&!is.na(fol)){
      #taken from xcms package
      
      flist = list.files(fol, pattern=internalStatic$filePattern, recursive = TRUE, full.names=T)
      if(length(flist)){
      internalValues$params$filegroups <- data.frame(File = flist,
                                                     Group = rep("G1", length(flist)),
                                                     stringsAsFactors = F)
      internalValues$wd <- fol
      internalValues$active <- "filegroups"
      internalValues$xcmsModule_loaded <- T
      }else{
        showNotification("No compatible MS data file in the selected folder (and its subfolders)!", duration = 0, type = "error")
      }
      }
  })
  
  output$xcms_selectTab <- renderUI({selectizeInput(ns('xcms_selectTab'),"Change settings for...", 
                                                    choices = list("File Grouping" = "filegroups",
                                                                   "Peak Detection" = "centWave",
                                                                   "Peak filling" = "peakfilling",
                                                                   "Feature grouping" = "group",
                                                                   "CAMERA settings" = "camera",
                                                                   "RT correction" = "retcor",
                                                                   "Output Files" = "outputs"),
                                                    selected = internalValues$active
  )})
  
  observeEvent(input$xcms_selectTab,{
    if(!is.null(input$xcms_settingstab) && nrow(hot_to_r(input$xcms_settingstab)) != 0){
      internalValues$params[[internalValues$active]][,which(colnames(internalValues$params[[internalValues$active]]) != "Description")] <- hot_to_r(input$xcms_settingstab)
    }  
    internalValues$active <- input$xcms_selectTab
    
  })
  
  
  
  
  observeEvent(input$xcms_start,{
    if(!is.null(input$xcms_settingstab) && nrow(hot_to_r(input$xcms_settingstab)) != 0){
      internalValues$params[[internalValues$active]][,which(colnames(internalValues$params[[internalValues$active]]) != "Description")] <- hot_to_r(input$xcms_settingstab)
    }
    
    fo <- file.path(internalValues$wd, paste0(strftime(Sys.time(),"%Y%m%d_%H%M%S"),"_", input$xcms_name))
    dir.create(fo)
    setfo <- file.path(fo,"settings")
    dir.create(setfo)
    
    write.csv(data.frame(X=1,Time=0,Status="",Details="",elapsed_time=0), file = file.path(fo,"status.csv"))
    internalValues$jobs <- c(internalValues$jobs, fo)
    file.copy(system.file("scripts", "xcms_runner_i.R",package = "Metaboseek"),setfo)
    
    for(i in 1:length(internalValues$params)){
      write.csv(internalValues$params[[i]], file = file.path(setfo,paste0(names(internalValues$params)[i],".csv")), row.names = T)
    }
    
    posSettings <- reactiveValuesToList(tAnalysisX)
    posSettings$rtCorrAnaCheck <- internalValues$rtCorrAnaCheck
    posSettings$noRtCorrAnaCheck <- internalValues$noRtCorrAnaCheck
    
    write(jsonlite::serializeJSON(posSettings, pretty = T), file.path(setfo, "postProcessingSettings.json"))
    
    
    zip(file.path(setfo,"settings.zip"), grep(list.files(setfo, full.names = T), pattern = "status.csv", invert = T, value = T), flags = "-j")
    
    runner <- system.file("scripts", "xcms_runner_i.R",package = "Metaboseek")
    rpath <- file.path(R.home(component = "bin"), "Rscript")
    
    
    system(paste0( '"',
                   rpath,
                   '"  --verbose ',
                   '"',
                   runner,
                   '" "',
                   fo,
                   '"'),
           wait = F)
    
    showModal(modalDialog(p("The xcms analysis is running in a separate process now.
                          You can continue using Metaboseek now.
                         Closing the Metaboseek command line window will interrupt the xcms run!
                          The results of this analysis can be found in ", strong(fo)),
                          title = "xcms analysis is running!",
                          easyClose = T
    ))
    
  })
  
  output$xcms_settingstab <- rhandsontable::renderRHandsontable({
    MAT_comments <- matrix(ncol = length(which(colnames(internalValues$params[[internalValues$active]]) != "Description")),
                           nrow = nrow(internalValues$params[[internalValues$active]]))
    if(!is.null(internalValues$params[[internalValues$active]]) & internalValues$active != "filegroups"){
      MAT_comments[, 1] <- internalValues$params[[internalValues$active]]$Description
    }
    
    showme <- as.data.frame(internalValues$params[[internalValues$active]][,which(colnames(internalValues$params[[internalValues$active]]) != "Description")],
                            stringsAsFactors = F,
                            row.names = row.names(internalValues$params[[internalValues$active]]))
    colnames(showme) <- colnames(internalValues$params[[internalValues$active]])[which(colnames(internalValues$params[[internalValues$active]]) != "Description")]
    
    rhandsontable::rhandsontable(showme,
                                 readOnly = F,
                                 contextMenu = T,
                                 selectCallback = TRUE,
                                 comments = MAT_comments,
                                 digits = 8,
                                 highlightCol = TRUE,
                                 highlightRow = TRUE,
                                 rowHeaderWidth = 200) %>%
      rhandsontable::hot_cell(1,"MOSAIC_intensities", readOnly = T) %>%
      rhandsontable::hot_cell(1,"xcms_peakfilling", readOnly = T) %>%
      rhandsontable::hot_cell(1,"CAMERA_analysis", readOnly = T)
    
  })
  
  
  
  observeEvent(input$xcms_statustab,{
    if(!is.null(input$xcms_statustab) && !is.na(hot_to_r(input$xcms_statustab)$Status[1]) && hot_to_r(input$xcms_statustab)$Status[1] == "Finished"){
      showNotification(paste("XCMS analysis finished"), duration = 0)
    }
    
    if(!is.null(input$xcms_statustab) && !is.na(hot_to_r(input$xcms_statustab)$Status[1]) && hot_to_r(input$xcms_statustab)$Status[1] == "Starting analysis"){
      showNotification(paste("XCMS analysis started"), duration = 0)
    }
  })
  
  rfr <- reactive({reactiveFileReader(1500,
                            NULL,
                            file.path(internalValues$jobs[1],"status.csv"),
                            read.csv,
                            stringsAsFactors = F, 
                            row.names = 1)() })
  
  output$xcms_statustab <- rhandsontable::renderRHandsontable({if(!is.null(internalValues$jobs)){
    
    rhandsontable::rhandsontable(rfr(),
                                 readOnly = T,
                                 contextMenu = F,
                                 selectCallback = TRUE,
                                 digits=8,
                                 highlightCol = TRUE,
                                 highlightRow = TRUE,
                                 rowHeaderWidth = 200)
    
  }
  })
  
  # Generate a text output ----
  output$summary <- renderPrint({
    print(gsub("\\\\","/", input$xcms_folder))
  })
  
  output$noRtCorrCheck <- renderUI({
    div(title= "Activate post-processing for non-retention time corrected data.",
        checkboxInput(ns('nortcorrcheck'), 'Before retention time correction', value = internalValues$noRtCorrAnaCheck))
  })
  
  
  observeEvent(input$nortcorrcheck,{
    internalValues$noRtCorrAnaCheck <- input$nortcorrcheck
  })
  
  output$outputSelection <- renderUI({
    tagList(
      div(title= "Which output files should be generated?",
          hr(),
          strong("Output selection")),
      fluidRow(
        column(3,
        div(title= "Perform retention time correction", style = "display:inline-block",
            checkboxInput(ns('runrtcorrcheck'),
                          'RT correction',
                          value = internalValues$params$outputs["peaktable_grouped_Rtcorr","Value"] ))),
        column(3,
        div(title= "Get intensities using Metaboseek intensity function (faster than xcms peak 
            filling but less accurate realtive quantification for broader peaks). Results will be in
            columns with suffix '__XIC'.",
            style = "display:inline-block",
            checkboxInput(ns('intensityselect'),
                           'Get Metaboseek intensities',
                           value = internalValues$params$outputs[c("peaktable_grouped"), "MOSAIC_intensities"]))),
        column(3,
        div(title= "Fill intensities for features for which initial peak detection failed across all files
            (default xcms method, slower than Metaboseek intensities, but more accurate 
            realtive quantification for broader peaks).",
            style = "display:inline-block",
            checkboxInput(ns('fillpeaksselect'),
                           'Fill peaks with xcms',
                           value = internalValues$params$outputs[c("peaktable_grouped"), "xcms_peakfilling"]))),    
        column(3,
        div(title= "Detect adducts and isotope peaks using the CAMERA package",
            style = "display:inline-block",
            checkboxInput(ns('cameraselect'),
                           'Run CAMERA analysis',
                           value = internalValues$params$outputs[c("peaktable_grouped"), "CAMERA_analysis"])))#,    
        # 
        # 
        # div(title= "Export the result of file-by-file feature detection before feature grouping across files",
        #     style = "display:inline-block",
        #     checkboxInput(ns('peaktableallcheck'),
        #                   'Get ungrouped peak table',
        #                   value = internalValues$params$outputs["peaktable_all","Value"] ))
      ))
  })
  
 
  
  ###Metaboseek intensities
  observeEvent(input$intensityselect,{
      internalValues$params$outputs[c("peaktable_grouped","peaktable_grouped_Rtcorr"),"MOSAIC_intensities"] <- input$intensityselect
        })
  
  ###XCMS intensities
  observeEvent(input$fillpeaksselect,{
       internalValues$params$outputs[c("peaktable_grouped","peaktable_grouped_Rtcorr"),"xcms_peakfilling"] <- input$fillpeaksselect
    })
  
 
  
  ##CAMERA analysis
  observeEvent(input$cameraselect,{
       internalValues$params$outputs[c("peaktable_grouped",
                                    "peaktable_grouped_Rtcorr"),
                                  "CAMERA_analysis"] <- input$cameraselect
  })
  
  observeEvent(input$runrtcorrcheck,{
    internalValues$params$outputs["peaktable_grouped_Rtcorr","Value"] <- input$runrtcorrcheck
  })
  
  # observeEvent(input$peaktableallcheck,{
  #   internalValues$params$outputs["peaktable_all","Value"] <- input$peaktableallcheck
  # })
  
  output$rtCorrCheck <- renderUI({
    div(title= "Activate post-processing for retention time corrected data.",
        checkboxInput(ns('rtcorrcheck'), 'After retention time correction', value = internalValues$rtCorrAnaCheck))
  })
  
  observeEvent(input$rtcorrcheck,{
    internalValues$rtCorrAnaCheck <- input$rtcorrcheck
  })
  
  tAnalysisX <- callModule(TableAnalysisModule, "TabAnalysisXcms",
                           reactives = reactive({list(fileGrouping = if(internalValues$active == "filegroups" 
                                                                        && !is.null(input$xcms_settingstab) 
                                                                        && length(hot_to_r(input$xcms_settingstab)$File) > 0 ){
                             hot_to_r(input$xcms_settingstab)}
                             else{internalValues$params$filegroups})
                           }),
                           values = reactiveValues(featureTables = NULL,
                                                   MSData= NULL))
  observeEvent(tAnalysisX,{
    tAnalysisX$analysesSelected <- NULL#tAnalysisX$analysesAvailable
  }, once = T)
  
  return(internalValues)
  
}


#' @describeIn xcmsWidget UI elements
#' @export 
xcmsWidgetUI <-  function(id){
  ns <- NS(id)
  fluidPage(
      useShinyjs(),
fluidRow(
      shinydashboard::box(title = "Run XCMS analysis", width = 12, status= "primary",
                          
                          h3("This module runs and observes an XCMS analysis with customizable settings and generates a new folder inside the selected file folder with results from the xcms analysis."),
                          fluidRow(
                            column(5,
                                   h3("Load Data"),
                                   hr(),
                                   strong("Data must be centroided. Supported File Formats: .mzXML, .mzML, .cdf, .nc, .mzData"),
                                   shinyFiles::shinyDirButton(ns('xcms_loadfolder'), "1. Load MS file folder",
                                                              title = "Select a folder with MS data files.",
                                                              style="height: 50px; border-color: #C41230; width: 100%;"),
                                   
                                   hr(),
                                   textInput(ns('xcms_name'), "Title of this analysis", "xcms_run"),
                                   #fluidRow(
                                     htmlOutput(ns("outputSelection")),
                                   #),
                                   hr(),
                                   actionButton(ns('xcms_start'),"2. Start analysis!",
                                                style="color: #fff; background-color: #C41230; border-color: #595959; height: 50px; width: 100%;")),
                            column(2),
                            column(5, 
                                   h3("Load Presets"),
                                     hr(),
                                   fluidRow(
                                   htmlOutput(ns('defaultSelector'))),
                                   fluidRow(
                                       h5("About the current default settings:"),
                                       htmlOutput(ns("defaultDescription"))
                                   ),
                                   hr(),
                                   fileInput(ns('xcms_settingsLoad'),"Load your own settings", accept = "application/zip"),
                                   
                                   downloadButton(ns("xcms_settingsDL"), "Download current settings")
                            ))
                          
      )),
    
    fluidRow(
      shinydashboard::box(title = "XCMS Settings", width = 12,
                          id = "xcms_settingsBox", status = "primary",
                          fluidPage(
                           # fluidRow(
                            column(7,
                                   
                                   fluidRow(
                                    # hr(),
                                     h3("Automatic post-processing of MS data"),
                                     p("Basic analysis and p-value calculation require more than one group set in File Grouping (in Analysis Settings).")),
                                   fluidRow(
                                     column(3,htmlOutput(ns("noRtCorrCheck"))),
                                     column(3, htmlOutput(ns("rtCorrCheck")))
                                   ),
                                   fluidRow(
                                     TableAnalysisModuleUI(ns("TabAnalysisXcms"))
                                   )
                            ),
                            #column(2),
                            column(5,
                                   fluidRow(
                                     h3("Analysis Settings"),
                                     htmlOutput(ns('xcms_selectTab'))
                                   ), 
                              fluidRow(
                              rhandsontable::rHandsontableOutput(ns('xcms_settingstab'))
                            ))
                            #)
                            ,
                            
                           
                            
                          ))
    ),
    fluidRow(
      shinydashboard::box(title = "Job status", width = 12, status= "primary",
                          p("View status of a running XCMS job here"),
                          rhandsontable::rHandsontableOutput(ns('xcms_statustab'))
      ))
  )
}
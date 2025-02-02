#' LoadNetworkModule
#' 
#' 
#' Module for loading MS2 molecular networks (graphs)
#' 
#' @inherit MseekModules
#' @param layoutFunction reactive, returning the function to use for layout of the resulting graph
#' 
#' @describeIn LoadNetworkModule server logic
#' @export 
LoadNetworkModule <- function(input,output, session, values,
                              reactives = reactive({list(active = NULL)}),
                              layoutFunction = reactive({})){
  
  ns <- NS(session$ns(NULL))
  
  internalValues <- reactiveValues(numNetworks = 0)
  
  
  # loadNodeTab <- callModule(UploadTableModule,'loadNodeTab',
  #                           static = list(title =  "Load node table",
  #                                         filetypes = NULL,
  #                                         format = list(header = T,
  #                                                       sep = NULL,#"\t",
  #                                                       quote = '"',
  #                                                       stringsAsFactors = T))
  # )
  # 
  # loadEdgeTab <- callModule(UploadTableModule,'loadEdgeTab', 
  #                           static = list(title =  "Load edge table",
  #                                         filetypes = NULL,
  #                                         format = list(header = T,
  #                                                       sep = NULL,#"\t",
  #                                                       quote = '"',
  #                                                       stringsAsFactors = T))
  # )
  
  #load and reformat a  network from a file
  observeEvent(input$networkFileLoad$datapath,{
      tryCatch({  
    res <- loadMseekGraph(input$networkFileLoad$datapath, layoutFunction = layoutFunction())
    
    internalValues[[gsub("\\.[^.]*$","",input$networkFileLoad$name)]] <- res
    internalValues$numNetworks <- internalValues$numNetworks + 1
    removeModal()
      },
    error = function(e){
        
        showNotification(paste("An error occured: ", e), duration = 0, type = "error")
        
    }
    
      )

  })
  # 
  # #load and reformat a network from edge and node table
  # observeEvent(input$loadNetwork,{
  #   res <- list(tables = list(nodes = NULL,
  #                             edges = NULL),
  #               graph = NULL)
  #   
  #   res$tables$nodes <- loadNodeTab$df
  #   res$tables$edges <- loadEdgeTab$df
  #   
  #   if(! "fixed__id" %in% colnames(res$tables$nodes)){
  #   res$tables$nodes$fixed__id <- res$tables$nodes[,1]
  # }
  #   
  #   tryCatch({  
  #     g1 <- graph_from_data_frame(d=res$tables$edges, vertices=res$tables$nodes, directed=F) 
  #     
  #     
  #     #V(g1)$label <- V(g1)$parent.mass
  #     V(g1)$id <- seq(vcount(g1))
  #     
  #     # Removing loops from the graph:
  #     g1 <- igraph::simplify(g1, remove.multiple = F, remove.loops = T) 
  #     
  #     #important for overview mode!
  #     V(g1)$subcl <-  clusters(g1)$membership
  #     
  #     #make a fixed layout and add it to the graph in a way the NetworkModule will understand
  #     if(is.null(V(g1)$x__coord) || is.null(V(g1)$y__coord)){
  #         layo <- layout_components_qgraph(g1, qgraph::qgraph.layout.fruchtermanreingold)
  #         
  #         V(g1)$x__coord <- layo$layout[,1]
  #         V(g1)$y__coord <- layo$layout[,2]
  #         
  #     }
  # 
  #     res$graph <- g1
  #     
  #     internalValues[[gsub("\\.[^.]*$","",input$NetName)]] <- res
  #     internalValues$numNetworks <- internalValues$numNetworks + 1
  #     
  #     removeModal()
  #   },
  #   error = function(e){
  #     #print("graph not loaded")
  #     #print(e)
  #     showModal(
  #       modalDialog(title = "An error has occured",
  #                   "Load a node and edge table belonging to the same network, and make sure you selected the correct Table Options (tab or comma separated?) for your input table.",
  #                   hr(),
  #                   p(strong("Error:")),
  #                   p(paste(e, collapse = "\n")),
  #                   easyClose = T
  #       )
  #     )
  #   }
  #   
  #   )
  # })
  
  FindMS2 <- callModule(FindMS2ScansModule, "findms2network",
                        values = reactiveValues(featureTables = values$featureTables,
                                                MSData = values$MSData),
                        static = list(tooltip = "Make a new MS2 network from the current feature table",
                                      label = "New MS2 network")
  )
  
  SaveNetworks <- callModule(SaveNetworkModule, "savenetworks",
                             reactives = reactive({list(graphname = reactives()$active,
                                                        filename = paste0("networks/",reactives()$active))}),
                             values = reactiveValues(Networks = internalValues,
                                                     projectData = values$projectData),
                             static = list(tooltip = "Save Network as a graphml file",
                                           label = "",
                                           allowformats = list("Metaboseek Graph (.mskg)" = ".mskg",
                                                               "graphML" = ".graphML"))
  )
  
  observeEvent(FindMS2$done,{
    
    if(FindMS2$done){
      
      
      
      showModal(
        modalDialog(
          fluidPage(
            fluidRow(
              p(strong("Generate an edge table for the current feature table")),
              p("A network will be constructed using the available MS2 scans identified in the previous step.")
            ),
            hr(),
            
            if(!is.null(values$featureTables$tables[[values$featureTables$active]]$edges)){
              tagList(
                p(strong("An edge table exists already for this feature table. do you want to keep using it?")),
                div(title = "If not selected, a new edge table will be generated using the settings below (potentially time consuming).",
                    checkboxInput(ns("useOldEdges"), "Use previous edge list", value = T)),
                hr()
              )
            }else{p("")},
            
            
            fluidRow(
              column(2, div(title = "Use parent m/z information for networking",
                            checkboxInput(ns("useparentmasses"),"Use parent masses", value = T))),
              column(2, div(title = "Define m/z tolerance for MS2 fragment peak matching. Peaks will be matched if they are within m/z tolerance AND/OR ppm tolerance!",
                            numericInput(ns("mzdiff"),"m/z tolerance", value = 0.002))),
              column(2, div(title = "Define m/z tolerance for MS2 fragment peak matching in ppm. Peaks will be matched if they are within m/z tolerance AND/OR ppm tolerance!",
                            numericInput(ns("ppmdiff"),"ppm tolerance", value = 5))),
              column(2, div(title = "Minimum number of peaks that need to match between each pair of MS2 spectra",
                            numericInput(ns("minpeaks"),"min. peaks", value = 6))),
              column(3, div( title = "Remove noise (peaks below this reltaive intensity in a merged MS2 spectrum will be ignored)", 
                             numericInput(ns("noise"), "Noise level in %", value = 2))),
              column(1, div( title = "Search MS2 scans", 
                             mActionButton(ns("makeNetwork"), "Proceed", red = T)))
            ),
            fluidRow(column(2, div(title = "Remove peaks below m/z 100 before running the networking analysis",
                                   checkboxInput(ns("removesmallfrags"),"Ignore small fragments", value = FALSE))))
            ),
          title = "Make edges for network",
          easyClose = T,
          fade = F,
          size = "l",
          footer = modalButton("Cancel") 
        ))
      
      FindMS2$done <- F
    }
  })
  
  output$edgeInfo <- renderUI({
    
    if(!is.null(input$cosThresh)
       && !is.null(is.null(values$featureTables$tables[[values$featureTables$active]]$edges))){
      
      p(paste0("With the current cutoff at ", input$cosThresh,", a network would contain ", 
               sum(values$featureTables$tables[[values$featureTables$active]]$edges$cosine >= input$cosThresh),
               " edges."))
      
    }
    
  })
  
  observeEvent(input$makeNetwork,{
    
    
    tryCatch({  
      

      if(is.null(FeatureTable(values)$df$specList) 
         || (!is.null(input$useOldEdges) && !input$useOldEdges)){
    
        withProgress(message = 'Please wait!', detail = "Saving changes to Feature Table", value = 0, {
          
        updateFT(values)
            
            FeatureTable(values) <- getSpecList(FeatureTable(values), values$MSData$data,
                                                merge = TRUE,
                                                noiselevel = input$noise*0.01,
                                                ppm = input$ppmdiff, mzdiff = input$mzdiff,
                                                mzThreshold = if(input$removesmallfrags){100}else{NULL})
        
        
        tempn <- sum(!sapply(FeatureTable(values)$df$specList,function(x){return(is.null(x) || nrow(x) == 0)}))
        
        incProgress(0.2, detail = paste0("Calculating similarity between ", tempn, " features (",(tempn*(tempn-1))/2," comparisons)."  ))
        
        FeatureTable(values) <- FTedges(FeatureTable(values),
                                            useParentMZs = input$useparentmasses, minpeaks = input$minpeaks, mzdiff = input$mzdiff)
        
        if(hasError(previousStep(FeatureTable(values)))){
            showNotification(paste("An error occured: ",
                                   unlist(error(previousStep(FeatureTable(values))))),
                             duration = 0, type = "error")
            
        }else{
            
            showNotification(paste("Finished MS2 simiarity calculation"), duration = 10)
        }
        
      })
                removeModal()

      }
      showModal(
        modalDialog(
          fluidPage(
            fluidRow(
              p(strong("Finish Network assembly")),
              p("Give a name to the new network:"),
              textInput(ns('NetName2'), "Network name", value = paste0("Custom_Network_", length(names(internalValues)) )),
              if(length(names(internalValues)) > 1){
              p(strong("Note:"),paste0("Network names that already exist (will be overriden if you use the same name): ", paste(names(internalValues)[names(internalValues) != "numNetworks"], collapse = ", ")))
              }else{p("")}
                
                ),
            hr(),
            fluidRow(
              p("Hint: You can remove edges from this network later, e.g. by setting a higher (more strict) cosine threshold. However, you have to rebuild the network if you want to use a lower cosine score threshold later."),
              div( title = "Remove edges with cosine below this threshold: ", 
                   numericInput(ns("cosThresh"), "Cosine threshold", value = 0.6))
              
            ),
            fluidRow(
              htmlOutput((ns("edgeInfo")))
            ),
            fluidRow(
              div( title = "Search MS2 scans", 
                   actionButton(ns("makeNetwork2"), "Make Network"))
            )
        ),
        title = "Finish Molecular Network",
        easyClose = T,
        fade = F,
        size = "l",
        footer = modalButton("Cancel") 
      ))
    
     
    },
    error = function(e){
      #print("graph not loaded")
      #print(e)
      showModal(
        modalDialog(title = "An error has occured",
                    "Make sure MS2 data for the current feature table is loaded into Mseek",
                    hr(),
                    p(strong("Error:")),
                    p(paste(e, collapse = "\n")),
                    easyClose = T
        )
      )
    }
    
  )
      
   
  })

observeEvent(input$makeNetwork2,{
  
  tryCatch({  
  
    internalValues[[gsub("\\.[^.]*$","",input$NetName2)]] <- buildMseekGraph(FeatureTable(values), cosineThreshold = input$cosThresh,
                                                                             layoutFunction = layoutFunction())
    
    internalValues$numNetworks <- internalValues$numNetworks + 1
    removeModal()
  },
  error = function(e){
    print(e)
    removeModal()
    
    showModal(
      modalDialog(title = "An error has occured",
                  "Make sure MS2 data for the current feature table is loaded into Mseek",
                  hr(),
                  p(strong("Error:")),
                  p(paste(e, collapse = "\n")),
                  easyClose = T
      )
    )
  }
  
  )
})

observeEvent(input$loadNetworkModal,{
  
  showModal(
    modalDialog(
  fluidPage(
    fluidRow(
      # column(4,
      #        UploadTableModuleUI(ns('loadNodeTab'))),
      # column(4,
      #        UploadTableModuleUI(ns('loadEdgeTab'))),
      # column(4,
      #        style = "margin-top: 45px;",
             # p("Load with automatic presets"),
             div(title = "Load a network file.",
                      fileInput(ns('networkFileLoad'),"Load  network (.graphml or .mskg files only)", accept = NULL))
    # fluidRow(
    #   column(8,
    #          textInput(ns('NetName'), "Network name", value = "Custom_Network_1")),
    #   column(4,
    #          style = "margin-top: 25px;",
    #          tags$div(title = "Load network from custom tables. Requires both a node and an edge table to be loaded.",
    #                   actionButton(ns("loadNetwork"), "Load Network"))
    #   )
    # )
    )
    ),
  title = "Load a network",
  easyClose = T,
  fade = F,
  size = "l",
  footer = modalButton("Cancel") 
    ))
  
  
  
})



# observe({
#   shinyjs::toggleState(id = "loadNetwork",condition = (!is.null(loadNodeTab$df) && !is.null(loadEdgeTab$df)))
# })

return(internalValues)
}

#' @describeIn LoadNetworkModule UI elements
#' @export
LoadNetworkModuleUI <-  function(id){
  ns <- NS(id)
    fluidRow(
      column(2,
             div(title = "Load a network",
             actionButton(ns("loadNetworkModal"), "", icon = icon("folder-open", lib = "font-awesome"))
             )
             ),
      column(2,
             SaveNetworkModuleUI(ns("savenetworks"))
             ),
      column(8,
             FindMS2ScansModuleUI(ns('findms2network')))
    )
    }
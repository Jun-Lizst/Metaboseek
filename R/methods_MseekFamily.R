#' @include methods_buildMseekFT.R

### Methods with  work on all members of the MseekFamily of S3 classes:
#' @title MseekFamily
#' 
#' @aliases addProcessHistory
#' @rdname MseekFamily
#' 
#' @description The MseekFamily of classes includes the \code{MseekFT} and 
#' \code{MseekGraph} S3 classes. Many methods described here will work on both classes
#' 
#' \code{addProcessHistory}: adds (appends) a single \code{\link{ProcessHistory}}
#'  object to the \code{.processHistory} slot. Copied description and Method 
#'  template for \code{addProcessHistory} from \code{xcms}.
#' 
#' @param ph a \code{ProcessHistory} object
#' @param fun character(1), function name to look for
#' @param value for \code{groupingTable<-}: a data.frame with columns 
#' \code{Column} and \code{Group}. For \code{intensityCols<-}: a character vector of column names
#' 
#' @return
#' The \code{addProcessHistory} method returns the input object with the
#' provided \code{\link{ProcessHistory}} appended to the process history.
#'
#' @rdname MseekFamily
#' @export
setMethod("addProcessHistory", c("MseekFamily", "ProcessHistory"), function(object, ph) {
    if (!inherits(ph, "ProcessHistory"))
        stop("Argument 'ph' has to be of type 'ProcessHistory' or a class ",
             "extending it!")
    object$.processHistory[[(length(object$.processHistory) + 1)]] <- ph
    if (validObject(object))
        return(object)
})

#' @aliases processHistory
#' @description \code{processHistory}: extract a list of \code{ProcessHistory} objects from an object,
#'  representing changes made to the object.
#' 
#' @rdname MseekFamily
#' @export
setMethod("processHistory", "MseekFamily", function(object) {
    if(!length(object$.processHistory)){
        return(list())
    }else{
        return(object$.processHistory)
    }
})

#' @aliases previousStep
#'
#' @description \code{previousStep}: extract the most recent \code{ProcessHistory} object from an object,
#'  representing the last recorded changes made to the object.
#'
#' @rdname MseekFamily
#' @export
setMethod("previousStep", "MseekFamily",
          function(object){
              object$.processHistory[[length(object$.processHistory)]]
          })

#' @param x object to test for class
#' @rdname MseekFamily
#' @export
is.MseekFT <- function(x){
    (length(x) && "MseekFT" %in% class(x))
}

#' @rdname MseekFamily
#' @export
is.MseekGraph <- function(x){
    (length(x) 
     && "MseekGraph" %in% class(x)
     && length(x$graph))
    
}

#' @rdname MseekFamily
#' @export
is.MseekFamily <- function(x){
    (length(x)
     && ("MseekFT" %in% class(x)
     ||"MseekGraph" %in% class(x)))
}


#' Get a history entries for a function
#' @rdname MseekFamily
#' @param index get index in list instead of actual value
#' @description \code{searchFunParam}: extract the \code{ProcessHistory} objects
#' which were generated by a function named like \code{fun} (looking in the 
#' object@@param@@fun slots from all \code{ProcessHistory} objects).
#' 
#' @export
setMethod("searchFunParam", "MseekFamily",
          function(object, fun = "", index = FALSE){
              if(!length(processHistory(object))){return(list())}
              
              hits <- sapply(processHistory(object), function(x){
                  if(!"param" %in% slotNames(x)){return(FALSE)}
                  if(!"fun" %in% slotNames(x@param)){return(FALSE)}
                  if(x@param@fun != fun){return(FALSE)}
                  return(TRUE)
              })
              if(index){
                  return(which(hits))
              }else{
                  return(processHistory(object)[hits])
              }
              
          })

#' @description \code{groupingTable, groupingTable<-}: Get or set the Mseek intensity column grouping
#' @rdname MseekFamily
#' @export
setMethod("groupingTable", "MseekFamily",
          function(object){
              object$anagrouptable   
          })
#' @rdname MseekFamily
#' @export         
setReplaceMethod("groupingTable", c("MseekFamily", "data.frame"),
                 function(object, value){
                     beforeHash <- MseekHash(object)
                     
                     object <- updateFTgrouping(object,value)
                     
                     object <- addProcessHistory(object, FTProcessHistory(info = "Changed intensity column grouping",
                                                                          inputHash = beforeHash,
                                                                          outputHash = MseekHash(object),
                                                                          param = FunParam(fun = "Metaboseek::intensityCols",
                                                                                           args = list(groupingTable = value))))
                     
                     object
                 })


#' @description \code{intensityCols, intensityCols<-}: Get or set the Mseek intensity column names
#' @rdname MseekFamily
#' @export
setMethod("intensityCols", "MseekFamily",
          function(object){
              object$intensities   
          })

#' @rdname MseekFamily
#' @export         
setReplaceMethod("intensityCols", "MseekFamily",
                 function(object, value){
                     
                     #note: history is handled by groupingTable<-
                     if(is.data.frame(groupingTable(object)) 
                        && nrow(groupingTable) == length(value)){
                         
                         gt <- groupingTable(object)
                         gt$Column <- value
                         groupingTable(object) <- gt
                         
                     }else{
                         groupingTable(object) <- data.frame(Column = value,
                                                             Group = "G1",
                                                             stringsAsFactors = FALSE)
                     }
                     
                     object
                 })



#' @aliases hasAdjustedRtime
#' @description \code{hasAdjustedRtime}: check if the object contains retention time
#' correction information.
#' @return For \code{hasAdjustedRtime}: A logical, indicating if the object 
#' contains retention time correction information.
#' 
#' @rdname MseekFamily
#' @export
setMethod("hasAdjustedRtime", "MseekFamily",
          function(object){
              return(!is.null(object$RTcorrected) && object$RTcorrected)
          })

#' @aliases MseekHash
#' @description \code{MseekHash}: digests the object (excluding the process
#'  history) into a character string
#' @importFrom digest digest
#' @rdname MseekFamily
#' @export
setMethod("MseekHash", c("MseekFamily"),
          function(object) {
              digest(object[names(object) != ".processHistory"],
                             algo = "xxhash64")
          })

#' @aliases rename
#' 
#' @description \code{rename}: rename a \code{MseekFamily} object
#'
#' @param object an \code{MseekFT} object.
#' @param name file path to write to
#' 
#'   
#' @rdname MseekFamily
setMethod("rename", 
          "MseekFamily",
          function(object, name){
              beforeHash <- MseekHash(object)
              
              object$tablename <- name

              object <- addProcessHistory(object, FTProcessHistory(info = "Renamed MseekFT object",
                                                                   inputHash = beforeHash,
                                                                   outputHash = MseekHash(object),
                                                                   param = FunParam(fun = "Metaboseek:::rename",
                                                                                    args = list(name = name))))
              
              return(object)
          })




#' @noRd
#' @export
setMethod("FTFilter", c("data.frame"),
          function(object,
                   filters = list(),
                   sortBy = character(),
                   decreasing = TRUE){
              
              
              if(!missing(filters) && length(filters)){
                  
                  sel <- TRUE
                  
                  for(i in filters){
                      
                      names(i) <- gsub("Init$","",names(i))
                      
                      if(length(i$colSelected) == 0 || !i$colSelected %in% colnames(object)){
                          i$active <- FALSE
                      }
                      
                      if(length(i$active) && i$active){
                          if(i$numeric){
                              sel <- sel & (object[,i$colSelected] >= as.numeric(i$minSel)
                                            & object[,i$colSelected] <= as.numeric(i$maxSel))
                          }else{
                              
                              
                              if(!is.null(i$modeSel) && i$modeSel=="contains"){
                                  sel <- sel &  grepl(i$txtSel,
                                                      as.character(object[,i$colSelected]),
                                                      fixed = TRUE)
                              }else if(!is.null(i$modeSel) && i$modeSel=="does not contain"){
                                  sel <- sel & !grepl(i$txtSel,
                                                      as.character(object[,i$colSelected]),
                                                      fixed = TRUE)
                              }else if(!is.null(i$modeSel) && i$modeSel=="is not"){
                                  sel <- sel &  ! (as.character(object[,i$colSelected]) == i$txtSel)
                                  
                              }
                              #if(input$modeSel=="is"){
                              else{
                                  sel <- sel &  as.character(object[,i$colSelected]) == i$txtSel
                              }
                          }
                          
                          if(!length(i$excludeNAs) || i$excludeNAs){
                              #working under the assumption that NA values from the column in numeric, and in some cases (is, is not) in character,
                              #are passed into the logical() 
                              sel[is.na(sel)] <- FALSE
                          }else{
                              sel[is.na(sel)] <- TRUE
                          }
                          
                      }
                  }
                  
                  object <- object[sel,, drop = FALSE]
              }
              
              if(length(sortBy) && sortBy %in% colnames(object)){
                  ord <- order(object[,sortBy],
                               decreasing = decreasing)
                  object <- object[ord,]
              }
              
              return(object)
              
          })

#' @aliases FTFilter
#' @rdname MseekFamily
#' @description \code{FTFilter}: apply a list of filters to a MseekFT object
#' @param filters a list of filters
#' @param sortBy sort by this column
#' @param decreasing logical to specify if sort should be decreasing.
#' @export
setMethod("FTFilter", c("MseekFT"),
          function(object,
                   filters = list(),
                   sortBy = character(),
                   decreasing = TRUE){
              beforeHash <- MseekHash(object)
              
              
              p1 <- proc.time()
              beforeRows <- nrow(object$df)

              err <- list()
              tryCatch({
                  
                  if(missing(filters) 
                     || (!length(filters) && !length(sortBy))){
                      return(object)
                  }
                  
                  
                  object$df <- FTFilter(object$df,
                                        filters = filters,
                                        sortBy = sortBy,
                                        decreasing = decreasing)
                  
              },
              error = function(e){
                  #this assigns to object err in function environment,
                  #but err has to exist in the environment, otherwise
                  #will move through scopes up to global environment..
                  err$FTFilter <<- paste(e)
              },
              finally = {
                  p1 <- (proc.time() - p1)["elapsed"]
                  afterHash <- MseekHash(object)
                  
                  if(!length(err)){
                      msg <- paste("Filtered Feature Table; before:", beforeRows,
                                   "Features, after:", nrow(object$df), "Features" )
                  }else{
                      msg <- "Failed to filter MseekFT object"
                  }
                  
                  object <- addProcessHistory(object,
                                              FTProcessHistory(changes = afterHash != beforeHash,
                                                               inputHash = beforeHash,
                                                               outputHash = afterHash,
                                                               fileNames = character(),
                                                               error = err,
                                                               sessionInfo = NULL,
                                                               processingTime = p1,
                                                               info = msg,
                                                               param = FunParam(fun = "Metaboseek::FTFilter",
                                                                                args = list(filters = filters,
                                                                                            sortBy = sortBy,
                                                                                            decreasing = decreasing),
                                                                                longArgs = list())
                                              ))
              }
              )
              return(object)
          })

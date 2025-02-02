% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/Functions_class_featureTable.R
\name{.reformatFeatureTable}
\alias{.reformatFeatureTable}
\title{.reformatFeatureTable}
\usage{
.reformatFeatureTable(
  df,
  from = c("auto", "unknown", "mzMINE Aligned Peak List",
    "MetaboAnalyst Peak Intensity Table", "MS-DIAL Alignment Result")
)
}
\arguments{
\item{df}{data.frame}

\item{from}{input format. If auto, will run \code{.getFTFormat} to determine
the format.}
}
\value{
a list
\itemize{
 \item df: reformatted input data.frame
 \item grouping: anagrouptable format (if grouping information can be 
 extracted from input) or NULL
 \item from: which input format was used
}
}
\description{
Tries to identify the format of a feature table input data frame and 
reformats it for compatibility with \code{constructFeatureTable}
}

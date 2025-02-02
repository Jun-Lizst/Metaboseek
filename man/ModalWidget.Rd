% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/Widget_ModalWidget.R
\name{ModalWidget}
\alias{ModalWidget}
\alias{ModalWidgetUI}
\title{ModalWidget}
\usage{
ModalWidget(
  input,
  output,
  session,
  reactives = reactive({     fp = NULL }),
  static = list(tooltip = "Tooltip", title = "title", label = "label", icon =
    icon("bar-chart", lib = "font-awesome"), modalButtonLabel = "Cancel"),
  useActionLink = F,
  style = "color:#ffffff;padding:15px;border-left-width:0;border-right:1px solid #eee"
)

ModalWidgetUI(id)
}
\arguments{
\item{input}{arguments necessary for use with 
\code{\link[shiny]{callModule}()}}

\item{output}{arguments necessary for use with 
\code{\link[shiny]{callModule}()}}

\item{session}{arguments necessary for use with 
\code{\link[shiny]{callModule}()}}

\item{reactives}{a \code{reactive({})} returning a list with one element,
\code{fp}, see details}

\item{static}{a list of arguments that are not in a reactive context 
and hence do not change while the app is running.}

\item{useActionLink}{if TRUE, will use an \code{actionLink} instead 
of an \code{actionButton} to open the modal Dialog}

\item{style}{style settings to apply to the modal button}

\item{id}{id to be used to define a namespace via  \code{\link[shiny]{NS}()}
(must match \code{id} in \code{\link[shiny]{callModule}} 
for the server Module)}
}
\value{
returns its internalValues
}
\description{
Generic module for modal dialogs that are launched from a button.
}
\details{
Because the UI elements of the modal dialog are passed in as 
\code{reactives()$fp}, they can be namespaced and easily accessed in the 
parent module that can then handle the input from the modal dialog.
\describe{
\item{reactives()$fp}{Specify the UI elements of the modal dialog here}
\item{static}{
\itemize{
\item \code{tooltip} tooltip when hovering over the button
\item \code{title} title of the modal dialog
\item \code{label} label of the button opening the modal dialog
\item \code{icon} \code{\link[shiny]{icon}()} of the button opening the modal dialog
}
}
}
}
\section{Functions}{
\itemize{
\item \code{ModalWidget}: Server logic

\item \code{ModalWidgetUI}: UI elements
}}


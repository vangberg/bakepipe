% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/graph.R
\name{graph}
\alias{graph}
\title{Create dependency graph from parsed script data}
\usage{
graph(parse_data)
}
\arguments{
\item{parse_data}{Named list from parse() function, where each element
represents a script with 'inputs' and 'outputs' character vectors.}
}
\value{
List containing:
\itemize{
\item{nodes: Character vector of script names}
\item{edges: Data frame with 'from', 'to', and 'file' columns}
}
}
\description{
Builds a Directed Acyclic Graph (DAG) where scripts are nodes and files are edges.
Each edge represents a file dependency between two scripts.
}
\examples{
\dontrun{
# Parse scripts and create dependency graph
parsed <- parse()
graph_obj <- graph(parsed)
}
}

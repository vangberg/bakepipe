% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/parse.R
\name{parse}
\alias{parse}
\title{Parse R scripts to extract file dependencies}
\usage{
parse()
}
\value{
List with four elements:
\itemize{
\item{scripts: Named list where each element represents a script with 'inputs', 'outputs', and 'externals'}
\item{inputs: Character vector of all files used as inputs across all scripts}
\item{outputs: Character vector of all files produced as outputs across all scripts}
\item{externals: Character vector of all external files referenced across all scripts}
}
}
\description{
Finds all R scripts in the project and parses them to detect file_in() and
file_out() calls. Only string literals are supported as arguments to these
functions.
}
\keyword{internal}

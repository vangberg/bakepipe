% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/parse.R
\name{extract_file_calls}
\alias{extract_file_calls}
\title{Extract file_in or file_out calls from an expression}
\usage{
extract_file_calls(expr, func_name)
}
\arguments{
\item{expr}{Parsed R expression}

\item{func_name}{Either "file_in" or "file_out"}
}
\value{
Character vector of file paths found
}
\description{
Extract file_in or file_out calls from an expression
}
\keyword{internal}

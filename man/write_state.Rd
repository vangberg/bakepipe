% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/state.R
\name{write_state}
\alias{write_state}
\title{Write pipeline state to disk}
\usage{
write_state(state_file, parse_data)
}
\arguments{
\item{state_file}{Path to the state file to write
(typically ".bakepipe.state")}

\item{parse_data}{List from parse() function with 'scripts', 'inputs', 'outputs'}
}
\description{
Writes the current state of all files in the pipeline to a CSV file.
This includes scripts and all their input/output files with their
current checksums and timestamps.
}

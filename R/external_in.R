#' Mark a file as external input to the script
#'
#' Mark a file as external input to the script. This function simply returns the path
#' and is used for static analysis to determine script dependencies. Unlike file_in(),
#' external_in() is used for files that are provided by the user and are not produced 
#' by any other script in the pipeline. This helps distinguish between pipeline-internal
#' dependencies and external data sources.
#'
#' @param path Character string specifying the path to the external input file
#' @return The file path (unchanged)
#' @export
#' @examples
#' # In a bakepipe script, mark a file as external input and use it directly
#' # user_data <- read.csv(external_in("input.csv"))
#' # config <- readRDS(external_in("config.rds"))
#' 
#' # The function simply returns the path unchanged
#' file_path <- external_in("input.csv")
#' print(file_path)  # "input.csv"
external_in <- function(path) {
  path
}
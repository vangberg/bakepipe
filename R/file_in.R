#' Mark a file as input to the script
#'
#' Mark a file as input to the script. This function simply returns the path
#' and is used for static analysis to determine script dependencies. It can be
#' used directly when reading files.
#'
#' @param path Character string specifying the path to the input file
#' @return The file path (unchanged)
#' @export
#' @examples
#' # In a bakepipe script, mark a file as input and use it directly when reading
#' \donttest{
#' data <- read.csv(file_in("processed.csv"))
#' }
#' 
#' # The function simply returns the path unchanged
#' file_path <- file_in("data.csv")
#' print(file_path)  # "data.csv"
file_in <- function(path) {
  path
}
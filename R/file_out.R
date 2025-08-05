#' Mark a file as output from the script
#'
#' Mark a file as output from the script. This function simply returns the path
#' and is used for static analysis to determine script dependencies. It can be
#' used directly when writing files.
#'
#' @param path Character string specifying the path to the output file
#' @return The file path (unchanged)
#' @export
#' @examples
#' # In a bakepipe script, mark a file as output and use it directly when writing
#' output_file <- file.path(tempdir(), "output.csv")
#' write.csv(mtcars, file_out(output_file))
#'
#' # The function simply returns the path unchanged
#' file_path <- file_out("output.csv")
#' print(file_path) # "output.csv"
file_out <- function(path) {
  path
}

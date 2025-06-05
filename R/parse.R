#' Parse R scripts to extract file dependencies
#'
#' Finds all R scripts in the project and parses them to detect file_in() and
#' file_out() calls. Only string literals are supported as arguments to these
#' functions.
#'
#' @return Named list where each element represents a script. Names are script
#'   paths relative to project root. Each element contains 'inputs' and 'outputs'
#'   character vectors.
#' @keywords internal
#' @examples
#' \dontrun{
#' # Parse all scripts in the project
#' dependencies <- parse()
#' }
parse <- function() {
  # Get all R scripts in the project
  script_paths <- scripts()
  
  # If no scripts found, return empty list
  if (length(script_paths) == 0) {
    return(list())
  }
  
  # Get project root to make relative paths
  project_root <- root()
  
  # Initialize result list
  result <- list()
  
  # Parse each script
  for (script_path in script_paths) {
    # Get relative path for the result key
    rel_path <- normalizePath(script_path)
    rel_path <- sub(paste0("^", normalizePath(project_root), "/"), "", rel_path)
    rel_path <- sub(paste0("^", normalizePath(project_root), "\\\\"), "", rel_path)
    
    # Parse the script
    script_info <- parse_script(script_path)
    
    # Add to result with relative path as key
    result[[rel_path]] <- script_info
  }
  
  return(result)
}

#' Parse a single R script for file dependencies
#'
#' @param script_path Absolute path to the R script
#' @return List with 'inputs' and 'outputs' character vectors
#' @keywords internal
parse_script <- function(script_path) {
  # Read the script content
  script_content <- readLines(script_path, warn = FALSE)
  
  # Parse the script as R code
  tryCatch({
    parsed <- base::parse(text = script_content, keep.source = TRUE)
  }, error = function(e) {
    stop("Failed to parse R script: ", script_path, "\nError: ", e$message)
  })
  
  # Extract file_in and file_out calls
  inputs <- character(0)
  outputs <- character(0)
  
  # Walk through all expressions in the parsed code
  for (expr in parsed) {
    inputs <- c(inputs, extract_file_calls(expr, "file_in"))
    outputs <- c(outputs, extract_file_calls(expr, "file_out"))
  }
  
  # Remove duplicates and return
  list(
    inputs = unique(inputs),
    outputs = unique(outputs)
  )
}

#' Extract file_in or file_out calls from an expression
#'
#' @param expr Parsed R expression
#' @param func_name Either "file_in" or "file_out"
#' @return Character vector of file paths found
#' @keywords internal
extract_file_calls <- function(expr, func_name) {
  if (!is.language(expr)) {
    return(character(0))
  }
  
  files <- character(0)
  
  # Check if this expression is a call to the target function
  if (is.call(expr) && length(expr) >= 2) {
    # Check if the function name matches
    if (is.name(expr[[1]]) && as.character(expr[[1]]) == func_name) {
      # Extract the argument - must be a string literal
      if (length(expr) >= 2) {
        arg <- expr[[2]]
        if (is.character(arg) && length(arg) == 1) {
          files <- c(files, arg)
        } else {
          stop(func_name, "() only supports string literals")
        }
      }
      # Don't recurse into arguments of matching function calls
      return(files)
    }
  }

  # Recursively search in all parts of the expression
  if (is.call(expr) || is.expression(expr)) {
    for (i in seq_along(expr)) {
      # Always recurse into sub-expressions
      tryCatch({
        files <- c(files, extract_file_calls(expr[[i]], func_name))
      }, error = function(e) {
        # Re-throw the error to propagate it up
        stop(e$message)
      })
    }
  }

  files
}
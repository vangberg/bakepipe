#' Parse R scripts to extract file dependencies
#'
#' Finds all R scripts in the project and parses them to detect file_in() and
#' file_out() calls. Only string literals are supported as arguments to these
#' functions.
#'
#' @return List with three elements:
#'   \itemize{
#'     \item{scripts: Named list where each element represents a script with 'inputs' and 'outputs'}
#'     \item{inputs: Character vector of all files used as inputs across all scripts}
#'     \item{outputs: Character vector of all files produced as outputs across all scripts}
#'   }
#' @keywords internal
#' @importFrom fs path_rel
#' @examples
#' \dontrun{
#' # Parse all scripts in the project
#' dependencies <- parse()
#' }
parse <- function() {
  # Get all R scripts in the project
  script_paths <- scripts()
  
  # If no scripts found, return empty structure
  if (length(script_paths) == 0) {
    return(list(
      scripts = list(),
      inputs = character(0),
      outputs = character(0)
    ))
  }
  
  # Get project root to make relative paths
  project_root <- root()
  
  # Initialize result lists
  scripts <- list()
  all_inputs <- character(0)
  all_outputs <- character(0)
  
  # Parse each script
  for (script_path in script_paths) {
    # Get relative path for the result key
    rel_path <- fs::path_rel(script_path, project_root)
    
    # Parse the script
    script_info <- parse_script(script_path)
    
    # Add to scripts list
    scripts[[rel_path]] <- script_info
    
    # Collect all inputs and outputs
    all_inputs <- c(all_inputs, script_info$inputs)
    all_outputs <- c(all_outputs, script_info$outputs)
  }
  
  return(list(
    scripts = scripts,
    inputs = unique(all_inputs),
    outputs = unique(all_outputs)
  ))
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
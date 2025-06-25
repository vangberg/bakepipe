#' Find project root directory
#'
#' Find the project root by locating the nearest _bakepipe.R file,
#' searching upward from the current working directory.
#'
#' @return Character string with the absolute path to the project root
root <- function() {
  current_dir <- getwd()
  
  # Start from current directory and walk up the tree
  while (TRUE) {
    # Check if _bakepipe.R exists in current directory
    bakepipe_path <- file.path(current_dir, "_bakepipe.R")
    
    if (file.exists(bakepipe_path)) {
      return(normalizePath(current_dir))
    }
    
    # Get parent directory
    parent_dir <- dirname(current_dir)
    
    # If we've reached the filesystem root (parent is same as current)
    if (parent_dir == current_dir) {
      stop("Could not find _bakepipe.R in any parent directory")
    }
    
    # Move up one level
    current_dir <- parent_dir
  }
}
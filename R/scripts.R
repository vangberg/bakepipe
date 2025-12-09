#' Find all R scripts in project
#'
#' Returns a vector with paths to all .R scripts in or below the project root.
#' The project root is determined by bakepipe::root().
#'
#' @return Character vector of absolute paths to .R files
scripts <- function() {
  project_root <- root()

  # Find all .R files recursively from the project root
  r_files <- list.files(
    path = project_root,
    pattern = "\\.R$",
    recursive = TRUE,
    full.names = TRUE,
    ignore.case = TRUE
  )

  # Filter out _bakepipe.R and _targets.R files, and renv
  r_files <- r_files[!grepl("_bakepipe\\.R$|_targets\\.R$|renv/", r_files, ignore.case = TRUE)]

  # Return normalized paths
  normalizePath(r_files)
}
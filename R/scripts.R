#' Find all R scripts in project
#'
#' Returns a vector with paths to all .R scripts in or below the project root.
#' The project root is determined by bakepipe::root().
#'
#' @return Character vector of absolute paths to .R files
scripts <- function() {
  project_root <- root()

  # Find all .R files recursively from the project root
  # all.files = FALSE (default) excludes hidden files and directories (those starting with .)
  r_files <- list.files(
    path = project_root,
    pattern = "\\.R$",
    recursive = TRUE,
    full.names = TRUE,
    ignore.case = TRUE,
    all.files = FALSE
  )

  # Filter out special files and common dependency/cache directories
  # Patterns to exclude:
  # - _bakepipe.R and _targets.R (special pipeline files)
  # - renv/ (R package dependency manager)
  # - packrat/ (legacy R package dependency manager)
  # - Library/ (R package library caches)
  exclude_pattern <- paste(
    "_bakepipe\\.R$",
    "_targets\\.R$",
    "renv/",
    "packrat/",
    "Library/",
    sep = "|"
  )

  r_files <- r_files[!grepl(exclude_pattern, r_files, ignore.case = TRUE)]

  # Return normalized paths
  normalizePath(r_files)
}
#' Run pipeline
#'
#' Execute scripts in the pipeline graph in topological order. Only runs
#' scripts that are stale (have changed or have stale dependencies) for
#' incremental execution.
#'
#' @param verbose Logical. If TRUE (default), prints progress messages
#'   to console.
#' @return Character vector of files that were created or updated
#' @examples
#' # Copy sample project to temp directory
#' temp_dir <- tempfile()
#' dir.create(temp_dir)
#' sample_proj <- system.file("extdata", "sample-project", package = "bakepipe")
#' file.copy(sample_proj, temp_dir, recursive = TRUE)
#'
#' # Change to the sample project directory
#' old_wd <- getwd()
#' setwd(file.path(temp_dir, "sample-project"))
#'
#' # Execute the pipeline
#' created_files <- run()
#'
#' # The function returns paths of files that were created or updated
#' print(created_files)
#'
#' # Restore working directory and clean up
#' setwd(old_wd)
#' unlink(temp_dir, recursive = TRUE)
#' @export
run <- function(verbose = TRUE) {
  # Parse dependencies to know what files will be created
  deps <- parse()

  generate_targets_file()

  # Control targets output verbosity
  callr_args <- list(show = verbose, spinner = verbose)
  targets::tar_make(callr_arguments = callr_args)

  # Get which targets ran in this execution
  progress <- targets::tar_progress(fields = "progress")
  ran_targets <- progress$name[progress$progress == "completed"]

  # Map back to output files from the scripts that ran
  output_files <- character(0)
  for (script_name in names(deps$scripts)) {
    output_target_name <- path_to_target_name(script_name, "output")
    if (output_target_name %in% ran_targets) {
      output_files <- c(output_files, deps$scripts[[script_name]]$outputs)
    }
  }

  # Remove duplicates if any
  output_files <- unique(output_files)

  invisible(output_files)
}

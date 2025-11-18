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
  # Parse scripts to get dependencies
  pipeline_data <- parse()

  # Handle empty pipeline
  if (length(pipeline_data$scripts) == 0) {
    if (verbose) {
      message("\n[PIPELINE] \033[1;36mBakepipe Pipeline\033[0m")
      message("\033[33m   No scripts found in pipeline\033[0m\n")
    }
    return(character(0))
  }

  # Generate _targets.R file
  generate_targets_file()

  # Store outputs before running to track what gets created
  all_outputs <- unique(unlist(
    lapply(pipeline_data$scripts, function(s) s$outputs)
  ))

  # Store modification times of output files before running
  output_times_before <- sapply(all_outputs, function(f) {
    if (file.exists(f)) file.info(f)$mtime else as.POSIXct(NA)
  }, USE.NAMES = TRUE)

  # Print header
  if (verbose) {
    message("\n[PIPELINE] \033[1;36mBakepipe Pipeline\033[0m")
  }

  # Execute pipeline using targets
  start_time <- Sys.time()

  tryCatch(
    {
      # Run targets pipeline
      # Use callr_function = NULL to run in the same process for simplicity
      targets::tar_make(
        callr_function = NULL,
        reporter = if (verbose) "verbose" else "silent"
      )
    },
    error = function(e) {
      stop("Error executing pipeline: ", e$message)
    }
  )

  end_time <- Sys.time()
  elapsed <- as.numeric(difftime(end_time, start_time, units = "secs"))

  # Determine which files were created/updated by comparing modification times
  created_files <- character(0)
  for (output_file in all_outputs) {
    if (file.exists(output_file)) {
      time_before <- output_times_before[[output_file]]
      time_after <- file.info(output_file)$mtime

      # File was created or updated if it didn't exist before or mtime changed
      if (is.na(time_before) || time_after > time_before) {
        created_files <- c(created_files, output_file)
      }
    }
  }

  # Print summary
  if (verbose) {
    if (length(created_files) > 0) {
      message("\n\033[1;36m[SUMMARY]\033[0m")

      if (elapsed < 1) {
        time_str <- sprintf("%.0fms", elapsed * 1000)
      } else {
        time_str <- sprintf("%.1fs", elapsed)
      }
      message(sprintf(
        "\033[32m   Executed pipeline in %s\033[0m",
        time_str
      ))

      message(sprintf(
        "\033[36m   Created/updated %d file%s:\033[0m",
        length(created_files),
        if (length(created_files) > 1) "s" else ""
      ))
      for (file in sort(unique(created_files))) {
        message(sprintf("\033[2m     - %s\033[0m", file))
      }
      message("")
    } else {
      message("\n\033[32m[OK] All scripts are up to date!\033[0m\n")
    }
  }

  # Return unique list of created files
  unique(created_files)
}

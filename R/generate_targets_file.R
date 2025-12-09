#' Generate _targets.R file from bakepipe scripts
#'
#' Parses all R scripts in the project and generates a _targets.R file
#' that defines targets for the targets package. This allows bakepipe
#' to use targets as a backend for pipeline execution.
#'
#' @return Invisibly returns the path to the generated _targets.R file
#' @importFrom callr r
#' @export
generate_targets_file <- function() {
  # Parse all scripts to get dependencies
  parsed <- parse()

  # Get project root
  project_root <- root()
  targets_file <- file.path(project_root, "_targets.R")

  # Start building the targets file content
  lines <- character(0)

  # Add library calls
  lines <- c(lines, "library(targets)")
  lines <- c(lines, "")

  # Add the list of targets
  lines <- c(lines, "list(")

  # Generate targets for each script and its dependencies
  target_lines <- character(0)

  # Track all files that need file targets
  all_file_targets <- character(0)

  # First pass: add all external input file targets
  for (script_name in names(parsed$scripts)) {
    script_info <- parsed$scripts[[script_name]]
    
    for (ext_file in script_info$externals) {
      ext_target_name <- path_to_target_name(ext_file, "")
      if (!(ext_target_name %in% all_file_targets)) {
        target_lines <- c(
          target_lines,
          sprintf(
            '  tar_target(%s, "%s", format = "file"),',
            ext_target_name,
            ext_file
          )
        )
        all_file_targets <- c(all_file_targets, ext_target_name)
      }
    }
  }

  # Second pass: generate one target per script
  for (script_name in names(parsed$scripts)) {
    script_info <- parsed$scripts[[script_name]]

    # Generate target name from script path
    output_target_name <- path_to_target_name(script_name, "output")

    # Collect dependencies
    deps <- character(0)

    # Track the script itself so changes are detected
    script_target_name <- path_to_target_name(script_name, "script")
    target_lines <- c(
      target_lines,
      sprintf(
        '  tar_target(%s, "%s", format = "file"),',
        script_target_name,
        script_name
      )
    )
    deps <- c(deps, script_target_name)

    # Add external input dependencies
    for (ext_file in script_info$externals) {
      ext_target_name <- path_to_target_name(ext_file, "")
      deps <- c(deps, ext_target_name)
    }

    # Add input file dependencies (from other scripts)
    for (input_file in script_info$inputs) {
      # Search through all scripts to find which one produces this input
      for (producer_script in names(parsed$scripts)) {
        if (input_file %in% parsed$scripts[[producer_script]]$outputs) {
          # Found the producer script - depend on its output target
          input_target_name <- path_to_target_name(producer_script, "output")
          deps <- c(deps, input_target_name)
          break
        }
      }
    }

    # Build the script target
    target_start <- c(
      sprintf("  tar_target("),
      sprintf("    %s,", output_target_name),
      sprintf("    {")
    )

    # Add dependencies
    dep_lines <- character(0)
    for (dep in deps) {
      dep_lines <- c(dep_lines, sprintf("      %s", dep))
    }

    # Add script execution via callr for isolation
    exec_lines <- c(
      sprintf("      callr::r("),
      sprintf("        func = function(script_path) {"),
      sprintf("          source(script_path, local = TRUE)"),
      sprintf("        },"),
      sprintf('        args = list(script_path = "%s")', script_name),
      sprintf("      )")
    )

    # Add output vector if script has outputs
    output_lines <- character(0)
    if (length(script_info$outputs) > 0) {
      output_files_r <- paste0('"', script_info$outputs, '"', collapse = ", ")
      output_lines <- c(output_lines, sprintf("      c(%s)", output_files_r))
    } else {
      # No outputs - return empty character vector
      output_lines <- c(output_lines, sprintf("      character(0)"))
    }

    target_end <- c(
      sprintf("    },"),
      sprintf("    format = \"file\""),
      sprintf("  ),")
    )

    # Combine all parts
    full_target <- c(target_start, dep_lines, exec_lines, output_lines, target_end)
    target_lines <- c(target_lines, full_target)

    all_file_targets <- c(all_file_targets, output_target_name)
  }

  # Remove trailing comma from last target
  if (length(target_lines) > 0) {
    last_line <- target_lines[length(target_lines)]
    target_lines[length(target_lines)] <- sub(",$", "", last_line)
  }

  # Combine everything
  lines <- c(lines, target_lines)
  lines <- c(lines, ")")

  # Write to file
  writeLines(lines, targets_file)

  invisible(targets_file)
}

#' Convert file path to valid R target name
#'
#' Converts a file path to a valid R identifier for use as a target name.
#' Special characters are replaced with underscores.
#'
#' @param path File path
#' @param prefix Prefix to add (e.g., "script", "run", or "")
#' @return Valid R identifier
#' @keywords internal
path_to_target_name <- function(path, prefix = "") {
  # Convert to lowercase and replace special chars with underscores
  name <- tolower(path)

  # Replace directory separators, dots (except in extensions), hyphens
  # and other special characters with underscores
  name <- gsub("[/\\.-]", "_", name)

  # Remove any remaining non-alphanumeric characters
  name <- gsub("[^a-z0-9_]", "_", name)

  # Remove consecutive underscores
  name <- gsub("_+", "_", name)

  # Remove leading/trailing underscores
  name <- gsub("^_|_$", "", name)

  # Add prefix if provided
  if (nzchar(prefix)) {
    name <- paste(prefix, name, sep = "_")
  }

  name
}

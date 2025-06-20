#' Read pipeline state from disk
#'
#' Reads the .bakepipe.state file and computes current checksums to
#' determine which files are stale. A file is considered stale if its
#' current checksum differs from the stored checksum.
#'
#' @param state_file Path to the state file (typically ".bakepipe.state")
#' @return Data frame with columns 'file' and 'stale' (logical)
#' @importFrom utils read.csv write.csv
read_state <- function(state_file) {
  # Initialize empty state if file doesn't exist
  if (!file.exists(state_file)) {
    return(data.frame(
      file = character(0),
      stale = logical(0),
      stringsAsFactors = FALSE
    ))
  }

  # Read existing state file
  state_data <- utils::read.csv(state_file, stringsAsFactors = FALSE)

  # Get current checksums for all files in state
  current_checksums <- character(0)
  for (file_path in state_data$file) {
    if (file.exists(file_path)) {
      current_checksums[file_path] <- compute_file_checksum(file_path)
    } else {
      current_checksums[file_path] <- NA_character_
    }
  }

  # Determine which files are stale based on checksum comparison
  stale <- logical(nrow(state_data))
  for (i in seq_len(nrow(state_data))) {
    file_path <- state_data$file[i]
    stored_checksum <- state_data$checksum[i]
    current_checksum <- current_checksums[file_path]

    # File is stale if checksum differs or file is missing
    stale[i] <- is.na(current_checksum) || current_checksum != stored_checksum
  }

  # Return data frame with file and stale columns
  data.frame(
    file = state_data$file,
    stale = stale,
    stringsAsFactors = FALSE
  )
}

#' Write pipeline state to disk
#'
#' Writes the current state of all files in the pipeline to a CSV file.
#' This includes scripts and all their input/output files with their
#' current checksums and timestamps.
#'
#' @param state_file Path to the state file to write
#'   (typically ".bakepipe.state")
#' @param parse_data List from parse() function with 'scripts', 'inputs', 'outputs'
write_state <- function(state_file, parse_data) {
  # Collect all unique files from parse_data
  all_files <- character(0)

  # Add script names
  all_files <- c(all_files, names(parse_data$scripts))
  
  # Add all inputs and outputs
  all_files <- c(all_files, parse_data$inputs)
  all_files <- c(all_files, parse_data$outputs)

  all_files <- unique(all_files)

  # Create state data frame
  state_data <- data.frame(
    file = all_files,
    checksum = character(length(all_files)),
    last_modified = character(length(all_files)),
    stringsAsFactors = FALSE
  )

  # Compute checksums and timestamps for existing files
  for (i in seq_len(nrow(state_data))) {
    file_path <- state_data$file[i]

    if (file.exists(file_path)) {
      state_data$checksum[i] <- compute_file_checksum(file_path)
      file_info <- file.info(file_path)
      state_data$last_modified[i] <- as.character(file_info$mtime)
    } else {
      # For missing files, use NA checksum and current timestamp
      state_data$checksum[i] <- NA_character_
      state_data$last_modified[i] <- as.character(Sys.time())
    }
  }

  # Write to CSV file
  utils::write.csv(state_data, state_file, row.names = FALSE)
}

#' Compute MD5 checksum for a file
#'
#' @param file_path Path to the file
#' @return Character string containing the MD5 checksum
#' @keywords internal
compute_file_checksum <- function(file_path) {
  if (!file.exists(file_path)) {
    return(NA_character_)
  }

  # Use tools::md5sum for consistency with base R
  checksum <- tools::md5sum(file_path)
  as.character(checksum)
}

#' Read state file for incremental builds
#'
#' Reads existing state and checks the status of tracked files by comparing
#' their current checksums with cached values. Only concerns itself with files
#' that are already tracked, not all possible files.
#'
#' @return List where each element represents a tracked file with:
#'   \itemize{
#'     \item{checksum: MD5 hash of file content}
#'     \item{last_modified: File modification timestamp}
#'     \item{status: "fresh" or "stale"}
#'   }
#' @export
#' @examples
#' \dontrun{
#' # Get state information for tracked files
#' state_obj <- read_state()
#' 
#' # Check if a specific script is stale
#' if (state_obj$"my_script.R"$status == "stale") {
#'   # Script needs to be re-run
#' }
#' }
read_state <- function() {
  state_file <- file.path(root(), ".bakepipe.state")
  
  # Read existing state if it exists
  if (!file.exists(state_file)) {
    return(list())
  }
  
  existing_state <- read.csv(state_file, stringsAsFactors = FALSE)
  
  # Build state object only for files that are already tracked
  state_obj <- list()
  
  for (i in seq_len(nrow(existing_state))) {
    file_name <- existing_state$file[i]
    tracked_checksum <- existing_state$checksum[i]
    
    if (file.exists(file_name)) {
      # Calculate current checksum and modification time
      current_checksum <- tools::md5sum(file_name)
      current_mtime <- file.info(file_name)$mtime
      
      # Compare checksums to determine status
      status <- if (tracked_checksum == current_checksum) "fresh" else "stale"
      
      state_obj[[file_name]] <- list(
        checksum = as.character(current_checksum),
        last_modified = as.character(current_mtime),
        status = status
      )
    } else {
      # File no longer exists - mark as stale
      state_obj[[file_name]] <- list(
        checksum = tracked_checksum,
        last_modified = existing_state$last_modified[i],
        status = "stale"
      )
    }
  }
  
  state_obj
}


#' Write state to disk
#'
#' Rebuilds the entire state based on the pipeline structure and marks
#' executed scripts as fresh. This is called by run() after scripts
#' complete successfully.
#'
#' @param parse_obj Parsed pipeline object containing script dependencies
#' @keywords internal
write_state <- function(parse_obj) {
  state_file <- file.path(root(), ".bakepipe.state")

  # Build state object from all files in pipeline
  state_obj <- list()

  # Add all files (scripts, inputs, outputs) to state
  all_files <- character(0)
  for (script_name in names(parse_obj)) {
    all_files <- c(all_files, script_name, 
                   parse_obj[[script_name]]$inputs, 
                   parse_obj[[script_name]]$outputs)
  }
  all_files <- unique(all_files)
  for (file_name in all_files) {
    if (file.exists(file_name)) {
      state_obj[[file_name]] <- list(
        checksum = as.character(tools::md5sum(file_name)),
        last_modified = as.character(file.info(file_name)$mtime),
        status = "fresh"
      )
    }
  }

  # Convert to data frame and write to CSV
  state_df <- data.frame(
    file = names(state_obj),
    checksum = sapply(state_obj, function(x) x$checksum),
    last_modified = sapply(state_obj, function(x) x$last_modified),
    status = sapply(state_obj, function(x) x$status),
    stringsAsFactors = FALSE
  )

  write.csv(state_df, state_file, row.names = FALSE)

  invisible(state_obj)
}
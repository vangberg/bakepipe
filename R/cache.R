#' Read cache file state for incremental builds
#'
#' Tracks file checksums and modification times to determine which scripts
#' and artifacts are fresh or stale. Reads existing cache and compares
#' with current file state without modifying the cache file.
#'
#' @return List where each element represents a file with:
#'   \itemize{
#'     \item{checksum: MD5 hash of file content}
#'     \item{last_modified: File modification timestamp}
#'     \item{status: "fresh" or "stale"}
#'   }
#' @export
#' @examples
#' \dontrun{
#' # Get cache information for all files
#' cache_obj <- read_cache()
#' 
#' # Check if a specific script is stale
#' if (cache_obj$"my_script.R"$status == "stale") {
#'   # Script needs to be re-run
#' }
#' }
read_cache <- function() {
  cache_file <- ".bakepipe_cache.csv"
  
  # Get all files in current directory (scripts and potential artifacts)
  all_files <- list.files(pattern = "\\.(R|csv|txt|json|xlsx?|rds|rda)$", 
                         ignore.case = TRUE)
  
  # Read existing cache if it exists
  existing_cache <- if (file.exists(cache_file)) {
    read.csv(cache_file, stringsAsFactors = FALSE)
  } else {
    data.frame(file = character(0), checksum = character(0), 
               last_modified = character(0), status = character(0),
               stringsAsFactors = FALSE)
  }
  
  # Build cache object
  cache_obj <- list()
  
  for (file_name in all_files) {
    if (file.exists(file_name)) {
      # Calculate current checksum and modification time
      current_checksum <- tools::md5sum(file_name)
      current_mtime <- file.info(file_name)$mtime
      
      # Look up existing cache entry
      existing_entry <- existing_cache[existing_cache$file == file_name, ]
      
      if (nrow(existing_entry) == 0) {
        # New file - mark as stale
        status <- "stale"
      } else {
        # Compare checksums to determine status
        if (existing_entry$checksum == current_checksum) {
          status <- "fresh"
        } else {
          status <- "stale"
        }
      }
      
      cache_obj[[file_name]] <- list(
        checksum = as.character(current_checksum),
        last_modified = as.character(current_mtime),
        status = status
      )
    }
  }
  
  # Return cache object without writing to disk
  cache_obj
}

#' Cache file state for incremental builds (deprecated)
#'
#' @export
#' @keywords internal
cache <- function() {
  read_cache()
}

#' Write cache state to disk
#'
#' Updates the cache file to mark specified scripts as fresh after successful
#' execution. This is called by run() after scripts complete successfully.
#'
#' @param executed_scripts Character vector of script names that were executed
#' @keywords internal
write_cache <- function(executed_scripts) {
  cache_file <- ".bakepipe_cache.csv"
  
  # Get current cache state
  cache_obj <- read_cache()
  
  # Mark executed scripts and their outputs as fresh
  for (script_name in executed_scripts) {
    if (script_name %in% names(cache_obj)) {
      cache_obj[[script_name]]$status <- "fresh"
    }
    
    # Also mark outputs of this script as fresh
    tryCatch({
      pipeline_data <- parse()
      if (script_name %in% names(pipeline_data)) {
        script_outputs <- pipeline_data[[script_name]]$outputs
        for (output_file in script_outputs) {
          if (file.exists(output_file)) {
            # Add to cache if not present, or update existing entry
            cache_obj[[output_file]] <- list(
              checksum = as.character(tools::md5sum(output_file)),
              last_modified = as.character(file.info(output_file)$mtime),
              status = "fresh"
            )
          }
        }
      }
    }, error = function(e) {
      # If parsing fails, just continue
    })
  }
  
  # Convert to data frame and write to CSV
  cache_df <- data.frame(
    file = names(cache_obj),
    checksum = sapply(cache_obj, function(x) x$checksum),
    last_modified = sapply(cache_obj, function(x) x$last_modified),
    status = sapply(cache_obj, function(x) x$status),
    stringsAsFactors = FALSE
  )
  
  write.csv(cache_df, cache_file, row.names = FALSE)
  
  invisible(cache_obj)
}
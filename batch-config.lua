-- Batch Processing Configuration
-- Centralized settings for the SVG batch importer

return {
  -- File paths
  metadata_file = "aavegotchi_db_wearables.json",
  log_file = "batch_import_log.txt",
  
  -- Default settings
  default_target_size = 64,
  default_view_index = 0,  -- 0=front, 1=left, 2=right, 3=back
  
  -- View names for logging and file naming
  views = {"front", "left", "right", "back"},
  
  -- Processing settings
  max_file_size_mb = 10,  -- Maximum SVG file size to process
  timeout_seconds = 30,   -- Timeout per file processing
  
  -- Logging settings
  log_level = "INFO",     -- DEBUG, INFO, WARN, ERROR
  log_timestamps = true,
  log_file_details = true, -- Include detailed per-file info
  
  -- Canvas settings
  canvas_color_mode = "RGB",
  background_color = {r = 0, g = 0, b = 0, a = 0}, -- Transparent
  
  -- Error handling
  continue_on_error = true,
  max_errors = 100,       -- Stop processing after this many errors
  
  -- Output settings
  create_subdirs = false, -- Create view subdirectories in output
  preserve_structure = false, -- Keep input directory structure
}



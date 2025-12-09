# Bakepipe Sample Project Setup
cat("🍞 Bakepipe Sample Project Interactive Session\n")
cat("=============================================\n\n")

# Get the bakepipe root directory (parent of current directory)
bakepipe_root <- dirname(getwd())

# Change to bakepipe root to load the package
old_wd <- getwd()
setwd(bakepipe_root)
cat("Loading bakepipe package...\n")
devtools::load_all()

# Change back to sample project
setwd(old_wd)
cat("Working directory set to:", getwd(), "\n\n")

cat("Available bakepipe functions:\n")
cat(" - external_in(path) : Mark external input files\n")
cat("- file_in(path)      : Mark input files\n")
cat("- file_out(path)     : Mark output files\n")
cat("- status()           : View pipeline structure\n")
cat("- run()              : Execute pipeline\n\n")
cat("- clean()            : Clean generated outputs\n\n")

cat("Sample project files:\n")
cat("- _bakepipe.R (root marker)\n")
cat("- raw_data.csv (input)\n")
cat("- 01_clean_data.R\n")
cat("- 02_analyze_data.R\n")
cat("- 03_generate_report.R\n\n")

cat("Try running:\n")
cat("  status()  # to see pipeline structure\n")
cat("  run()     # to execute the pipeline\n\n")

cat("Ready for testing!\n")
cat("==================\n")

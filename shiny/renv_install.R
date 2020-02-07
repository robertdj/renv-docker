renv::settings$external.libraries("/usr/local/lib/R/site-library")

# Make sure renv knows of the new external library
source(".Rprofile")

renv::restore(confirm = FALSE)

renv::isolate()


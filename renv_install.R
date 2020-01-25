renv:::renv_paths_cache()

renv::settings$external.libraries("/usr/local/lib/R/site-library")
renv::restore(confirm = FALSE)

renv::isolate()


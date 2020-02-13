#!/usr/bin/env sh

docker run --rm -it \
    -v `pwd`:/home/shiny/project \
    shiny-docker:latest Rscript -e 'renv::settings$external.libraries("/usr/local/lib/R/site-library")'

docker run --rm -it \
    -e "RENV_PATHS_CACHE=/home/shiny/renv/cache" \
    -v /home/robert/Documents/R/renv-cache:/home/shiny/renv/cache \
    -v `pwd`:/home/shiny/project \
    shiny-docker:latest Rscript -e "renv::restore(confirm = FALSE)" -e "renv::isolate()"


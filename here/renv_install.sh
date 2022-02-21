#!/usr/bin/env sh

docker run --rm \
    -e "RENV_PATHS_CACHE=/home/shiny/renv/cache" \
    -v /home/robert/code/R/renv-cache:/home/shiny/renv/cache \
    -v `pwd`:/home/shiny/project \
    renv-test:latest Rscript -e "renv::restore(confirm = FALSE)" -e "renv::isolate()"


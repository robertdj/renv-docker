#!/usr/bin/env sh

docker run --rm -it \
    -e "RENV_PATHS_CACHE=/home/shiny/renv/cache" \
    -v /home/robert/Documents/R/renv-cache:/home/shiny/renv/cache \
    -v `pwd`:/home/shiny/project \
    shiny-docker:latest Rscript renv_install.R


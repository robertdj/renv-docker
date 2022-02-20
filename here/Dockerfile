ARG R_VERSION
FROM robertdj/r-base:${R_VERSION}

USER shiny

COPY --chown=shiny:shiny . /home/shiny/project/

WORKDIR /home/shiny/project


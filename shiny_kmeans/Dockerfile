ARG R_VERSION
ARG SHINY_VERSION
FROM robertdj/shiny:${R_VERSION}-${SHINY_VERSION}

USER shiny

COPY --chown=shiny:shiny . /home/shiny/project/

RUN ln -s /home/shiny/project /srv/shiny-server/project

WORKDIR /home/shiny/project


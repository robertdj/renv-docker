ARG R_VERSION
ARG SHINY_VERSION
FROM robertdj/shiny:${R_VERSION}-${SHINY_VERSION}

COPY --chown=shiny:shiny . $HOME/project/

RUN ln -s /home/shiny/project /srv/shiny-server/project

WORKDIR $HOME/project


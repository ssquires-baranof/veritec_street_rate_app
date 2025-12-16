FROM rocker/r2u

RUN apt-get update

RUN install2.r --error --skipinstalled --ncpus -1 \
    bs4Dash \
    clock \
    devtools \
    dplyr \
    DT \
    duckdb \
    fresh \
    glue \
    highcharter \
    httr2 \
    lubridate \
    paws.application.integration \
    purrr \
    reactable \
    reactablefmtr \
    readxl \
    reticulate \
    retry \
    shiny \
    shinyauthr \
    shinycssloaders \
    shinyWidgets \
    sodium \
    shinyjs \
    shinyalert \
    stringr \
    tidyr \
    tibble \
    visNetwork \
    && rm -rf /tmp/downloaded_packages \
    && rm -rf /var/lib/apt/lists/*

COPY vtsr_app /home

WORKDIR /home

### INSTALL SHINY SERVER

RUN apt update \
    && apt-get install -y gdebi-core \
    && dpkg --add-architecture amd64 \
    && apt update \
    && apt-get install -y wget \
    && apt install -y python3-venv python3-pip python3-dev

RUN wget --no-verbose  https://download3.rstudio.org/ubuntu-18.04/x86_64/shiny-server-1.5.22.1017-amd64.deb \
    && gdebi -n shiny-server-1.5.22.1017-amd64.deb
    
EXPOSE 8777

COPY vtsr_app /srv/shiny-server/
  
WORKDIR /srv/shiny-server/
  
  # run app
CMD Rscript /srv/shiny-server/app.R
    

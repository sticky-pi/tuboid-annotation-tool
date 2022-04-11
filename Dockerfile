FROM rocker/r-ver:3.6.3

RUN apt-get update && apt-get install -y \
    sudo \
    gdebi-core \
    pandoc \
    pandoc-citeproc \
    libcurl4-gnutls-dev \
    libcairo2-dev \
    libxt-dev \
    xtail \
    wget \
    libsodium-dev \
    libssl-dev \
    libmariadbclient-dev\
    libicu-dev

# Download and install shiny server
RUN wget --no-verbose https://download3.rstudio.org/ubuntu-14.04/x86_64/VERSION -O "version.txt" && \
    VERSION=$(cat version.txt)  && \
    wget --no-verbose "https://download3.rstudio.org/ubuntu-14.04/x86_64/shiny-server-$VERSION-amd64.deb" -O ss-latest.deb && \
    gdebi -n ss-latest.deb && \
    rm -f version.txt ss-latest.deb && \
    . /etc/environment && \
    R -e "install.packages(c('shiny', 'rmarkdown'), repos='$MRAN')" && \
    cp -R /usr/local/lib/R/site-library/shiny/examples/* /srv/shiny-server/ && \
    chown shiny:shiny /var/lib/shiny-server

# Install R deps

RUN R -e "install.packages(c('DT',  'RSQLite', 'data.table', 'jsonlite', 'shiny.router', 'shinyjs', 'shinythemes', 'curl', 'memoise', 'cachem'), repos='http://cran.rstudio.com/')"

RUN apt-get install python-pip -y && pip install s3cmd
#
# ARG SHINY_UID
# ENV SHINY_UID=$SHINY_UID
# RUN usermod -u $SHINY_UID shiny



RUN pip install ete3 numpy
COPY pull_taxonomy.py ./
RUN python pull_taxonomy.py ./taxonomy.json
RUN mv  ./taxonomy.json /home/shiny


COPY s3cfg_template /home/shiny/s3cfg_template

# Copy configuration files into the Docker image
COPY shiny-server.conf  /etc/shiny-server/shiny-server.conf

# Copy further configuration files into the Docker image
COPY shiny-server.sh /usr/bin/shiny-server.sh
RUN  chmod 700  /usr/bin/shiny-server.sh

COPY insect_id_app /srv/shiny-server/insect_id_app

# RUN chown shiny.shiny /home/shiny/.s3cfg
# RUN mkdir /opt/data_root_dir &&  chown shiny /opt/data_root_dir
VOLUME /opt/data_root_dir

# Make the ShinyApp available at port 80
EXPOSE 80


CMD ["/usr/bin/shiny-server.sh"]

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
    libmariadbclient-dev\
    libssl-dev \
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
RUN R -e "install.packages(c('DT',  'RSQLite', 'data.table', 'jsonlite', 'shiny.router', 'shinyjs', 'shinythemes'), repos='http://cran.rstudio.com/')"


RUN apt-get install python-pip -y && pip install s3cmd 

# Copy configuration files into the Docker image
COPY shiny-server.conf  /etc/shiny-server/shiny-server.conf
# Copy further configuration files into the Docker image
COPY shiny-server.sh /usr/bin/shiny-server.sh
RUN  chmod 700  /usr/bin/shiny-server.sh

RUN mkdir /opt/data_root_dir &&  chown shiny /opt/data_root_dir
VOLUME /opt/data_root_dir


COPY insect_id_app /srv/shiny-server/insect_id_app
COPY .secret_s3cmd_conf /home/shiny/.s3cfg
RUN chown shiny.shiny /home/shiny/.s3cfg
#RUN ln -s /opt/data_root_dir/tuboids /srv/shiny-server/insect_id_app/www/tuboids

# Make the ShinyApp available at port 80
EXPOSE 80

CMD ["/usr/bin/shiny-server.sh"]

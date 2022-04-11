CONFIG_ENV_FILE <- '/home/shiny/env.R'

# The default config . typically for testing offline with rstudio (no api)
# these are overwritten with environment variables in API testing and production
config_vars <- list(MYSQL_DATABASE = NA, 
                 MYSQL_READER = NA,
                 MYSQL_SERVER_IP = NA,
                 MYSQL_PASSWORD = NA,
                 MYSQL_READER_PASSWORD = NA,
                 API_IP = NA, 
                 API_PORT = NA,
                 STICKY_PI_TESTING_USER = NA, 
                 STICKY_PI_TESTING_PASSWORD = NA, 
                 STICKY_PI_TESTING_RSHINY_AUTOLOGIN = FALSE, 
                 STICKY_PI_TESTING_RSHINY_BYPASS_LOGGIN = FALSE, 
                 DATA_ROOT_DIR = "/opt/data_root_dir",
                 S3_BUCKET = NA,
                S3_HOST = NA,
                S3_ACCESS_KEY = NA,
                S3_PRIVATE_KEY = NA)

get_config<- function(){
    out <- config_vars
    #populate with accessible vars from sys
    sys_vars <- Sys.getenv(names(config_vars))
    
    sys_vars <- sys_vars[sys_vars != ""]
    out[names(sys_vars)] <- sys_vars
    
    #overwide from config file, if available (docker only)
    if(file.exists(CONFIG_ENV_FILE)){
      source(CONFIG_ENV_FILE)
      for(v in names(out)){
        try({
        out[[v]] <- get(v)
      }, silent=TRUE)
      }
    }
    
    out
}

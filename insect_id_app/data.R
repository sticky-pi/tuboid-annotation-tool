
split_path <- function(x) if (dirname(x)==x) x else c(basename(x),split_path(dirname(x)))


get_next_to_annotate <- function(state, input){
  ann_dt <- get_comp_prop(state, annotation_dt)
  tub_dt <- get_comp_prop(state, tuboids_dt)
  
  n_dt <- ann_dt[, .(n_annots =.N), keyby=tuboid_id]
  
  n_dt <- rbind( n_dt, tub_dt[! tuboid_id %in% n_dt$tuboid_id, .(tuboid_id=tuboid_id,n_annots=0)])

  n_dt <- n_dt[tuboid_id != state$user$current_tuboid_id]
  
  n_dt <- n_dt[n_annots == min(n_annots)]
  sample(n_dt[,tuboid_id], 1)
}

make_index <- function(result_dir){
    all_dirs <- sort(list.dirs(root_dir,recursive = TRUE, full.names = FALSE))
    paths <- sapply(all_dirs, function(x){
      o <- split_path(x)
      if(length(o) == 3)
        return(o[1])
      else
        return(NA)
      })
    paths <- paths[!is.na(paths)]
    dt <- data.table::data.table(tuboid_id=paths, tuboid_dir=names(paths))
    fwrite(dt, file.path(result_dir, 'index.csv'))
}

get_s3_url <- function(bucket, file, duration=3600){
  s3_path = sprintf('s3://%s/%s', bucket, file)
  link = system2('s3cmd', args=list('signurl', s3_path, sprintf('+%i', duration)), stdout=TRUE)
}
tuboids_dt <- function(state, input){
  
  " The index file is a DF like this:
   tuboid_id: [08038ade.2020-06-24_22-00-00.2020-07-01_12-00-00.0000, ...]
   tuboid_dir: [08038ade.2020-06-24_22-00-00.2020-07-01_12-00-00/08038ade.2020-06-24_22-00-00.2020-07-01_12-00-00.0000, ...]
  "
  bucket <- state$config$S3_BUCKET
  url <- get_s3_url(bucket, 'tuboids/index.csv')
  dt <- data.table::fread(url)
  setkey(dt, tuboid_id)
  dt
}

# 
# tuboids_dt <- function(state, input){
#   root_dir <- state$config$DATA_ROOT_DIR
#   all_dirs <- sort(list.dirs(root_dir,recursive = TRUE, full.names = FALSE))
#   paths <- sapply(all_dirs, function(x){
#     o <- split_path(x)
#     if(length(o) == 4)
#       return(o[1])
#     else
#       return(NA)
#   })
#   paths <- paths[!is.na(paths)]
#   dt <- data.table::data.table(tuboid_id=paths, tuboid_dir=names(paths))
#   setkey(dt, tuboid_id)
#   dt
# }

annotation_dt <- function(state, input){
  t <- state$updaters$db_fetch_time
  root_dir <- state$config$DATA_ROOT_DIR
  if(!dir.exists(root_dir))
    stop(sprintf("root dir %s does not exist", root_dir))
  
  db_path <- file.path(root_dir, 'database.db')
  con <- dbConnect(RSQLite::SQLite(), db_path)
    on.exit(dbDisconnect(con))
  if(!"ANNOTATIONS" %in% dbListTables(con)){
    dt <- data.table(tuboid_id=character(), 
                     user=character(), 
                     type=character(),
                     order=character(),
                     family=character(),
                     genus=character(),
                     species=character(),
                     extra=character(),
                     confidence=numeric(),
                     notes = character(),
                     datetime=as.POSIXct(numeric(), origin='1970-01-01')
    )
    dbCreateTable(con, 'ANNOTATIONS', dt)
  }
  dt <- as.data.table(dbReadTable(con, 'ANNOTATIONS'))
  setkey(dt, tuboid_id)
  dt
}

get_all_image_urls_for_tuboid <- function(state, tuboid_dir){
  # tuboid_dir <- file.path(state$config$DATA_ROOT_DIR, tuboid_subdir)
  # tuboid_shots <- list.files(tuboid_dir, pattern = "tuboid.jpg",full.names = FALSE)
  # context_image <- list.files(tuboid_dir, pattern = "context.jpg", full.names = FALSE)
  bucket <- state$config$S3_BUCKET
  context_image <- get_s3_url(bucket, paste('tuboids', tuboid_dir, 'context.jpg', sep='/'))
  tuboid_image <- get_s3_url(bucket, paste('tuboids', tuboid_dir, 'tuboid.jpg', sep='/'))
  # path in www (to be served) www is mapped to `tuboid_dir` through symlink
  list(tuboid = tuboid_image, context = context_image)
}

add_new_annotation <- function(state, input){
  d =  data.table(tuboid_id=state$user$current_tuboid_id , 
                   user=state$user$username , 
                   type=state$choice$type,
                   order=state$choice$order,
                   family=state$choice$family,
                   genus=state$choice$genus,
                   species=state$choice$species,
                   extra=state$choice$extra,
                   confidence=state$choice$confidence,
                   notes = state$choice$notes,
                   datetime=Sys.time())
  root_dir <- state$config$DATA_ROOT_DIR
  if(!dir.exists(root_dir))
    stop(sprintf("root dir %s does not exist", root_dir))
  db_path <- file.path(root_dir, 'database.db')
  con <- dbConnect(RSQLite::SQLite(), db_path)
  on.exit(dbDisconnect(con))
  dbAppendTable(con, 'ANNOTATIONS', d)
  state$updaters$db_fetch_time <- Sys.time()
  change_page(state$user$next_tuboid_url)
}

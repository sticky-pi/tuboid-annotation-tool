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

get_s3_url <- function(bucket, file, duration=3600){
  s3_path = sprintf('s3://%s/%s', bucket, file)
  expiration_time = (1 + (as.integer(Sys.time()) + duration) %/% 3600) * 3600
  link = system2('s3cmd', args=list('signurl', s3_path, sprintf('%i', expiration_time)), stdout=TRUE)
}

tuboids_dt <- function(state, input){

  " The index file is a DF like this:
   tuboid_id: [08038ade.2020-06-24_22-00-00.2020-07-01_12-00-00.0000, ...]
   tuboid_dir: [08038ade.2020-06-24_22-00-00.2020-07-01_12-00-00/08038ade.2020-06-24_22-00-00.2020-07-01_12-00-00.0000, ...]
  "
  bucket <- state$config$S3_BUCKET
  url <- get_s3_url(bucket, 'index.csv')
  dt <- data.table::fread(url)
  setkey(dt, tuboid_id)
  dt
}

candidates_dt <- function(state, input){
  bucket <- state$config$S3_BUCKET
  url <- get_s3_url(bucket, 'candidate_labels.csv')
  dt <- NULL
  tryCatch({dt <<- dt <- data.table::fread(url)},
           error = function(e) e)
  if(is.null(dt))
    dt <- data.table::data.table(tuboid_id = character(0),
                      type = character(0),
                      order = character(0),
                      family = character(0),
                      genus = character(0),
                      species = character(0))

  setkey(dt, tuboid_id)
  dt
}

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
                     # tuboid_id_button = character(),
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
  bucket <- state$config$S3_BUCKET
  if(!shiny::isTruthy(tuboid_dir))
    return(NULL)
  context_image <- get_s3_url(bucket, paste(tuboid_dir, 'context.jpg', sep='/'))
  tuboid_image <- get_s3_url(bucket, paste( tuboid_dir, 'tuboid.jpg', sep='/'))
  metadata_url <- get_s3_url(bucket, paste( tuboid_dir, 'metadata.txt', sep='/'))
  metadata <- data.table::fread(metadata_url)
  setnames(metadata, c("image_id", "x", "y", "scale"))
  metadata[, length := 224 / scale ]
  # path in www (to be served) www is mapped to `tuboid_dir` through symlink
  list(tuboid = tuboid_image, context = context_image, metadata = metadata)
}

add_new_annotation <- function(state, input){
  if(state$user$allow_write == TRUE){
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
  }
  change_page(state$user$next_tuboid_url)
}

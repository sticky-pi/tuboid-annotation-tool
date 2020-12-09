library(data.table)
split_path <- function(x) if (dirname(x)==x) x else c(basename(x),split_path(dirname(x)))

make_s3_bucket_index_file <- function(root_dir, output){
  if(basename(output) !=  'index.csv')
    stop('Output filename should be "index.csv"')
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
  fwrite(dt, output)
}

args = commandArgs(trailingOnly=TRUE)

make_s3_bucket_index_file(args[1], args[2])
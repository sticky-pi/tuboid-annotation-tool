
phylo_make_tree <- function(bucket){
  #url = get_s3_url(bucket, 'taxonomy.json')

  jsonlite::fromJSON('/home/shiny/taxonomy.json')
}
phylo_make_levels <- function(){
  levels = c('type','order','family', 'genus', 'species')
}

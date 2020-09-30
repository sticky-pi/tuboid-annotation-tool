
phylo_make_tree <- function(tree_file){
  if(!file.exists(tree_file))
    stop(sprintf('No taxonomy file %s', tree_file))
  jsonlite::fromJSON(tree_file)
}
phylo_make_levels <- function(){
  levels = c('type','order','family', 'genus', 'species')
}

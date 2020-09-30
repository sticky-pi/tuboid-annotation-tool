
phylo_make_tree <- function(tree_file){
  jsonlite::fromJSON(tree_file)
}
phylo_make_levels <- function(){
  levels = c('type','order','family', 'genus', 'species')
}


make_state <- function(input, config){
  rv <- reactiveValues
  state <- list(
    config = do.call(rv,config),
    user = rv(is_logged_in=FALSE,
              username="",
              role="user",
              current_tuboid_id = "",
              next_tuboid_url = NULL,
              allow_write=FALSE),
    data = rv(tub_dt = data.table(),
              ann_dt = data.table()),
    choice = rv(type = NULL, 
                order = NULL,
                family = NULL,
                genus = NULL,
                species = NULL,
                extra = NULL,
                confidence = NULL,
                notes = NULL),
    
    updaters = rv(db_fetch_time=Sys.time() # so we can force update on api requests
    ),
    "_computed_props_"=reactiveValues(),
    "_input_" = input
  )
  
}

set_comp_prop <- function(state, foo){
  #fixme won't work for anonymouse methods etc
  method_name <- deparse(substitute(foo))
  rct <- reactive({
    foo(state, state[["_input_"]])
  })
  
  state[["_computed_props_"]][[method_name]] <- rct
  state
  
}

get_comp_prop <- function(state, prop_name){
  
  if(!is.character(prop_name))
    prop_name <- deparse(substitute(prop_name))
  # a react function stored in the state
  react <- state[["_computed_props_"]][[prop_name]]
  if(is.null(react))
    stop(sprintf("Could not find computed pro: %s\n props are: %s", prop_name, paste(names(state[["_computed_props_"]]))))
  react()
  
}
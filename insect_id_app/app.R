rm(list=ls())
library(shiny)
library(shinyjs)
library(shiny.router)
library(DT)
library(RSQLite)
library(data.table)
library(jsonlite)
library(shinythemes)
# 

source("login.R")
source("ui.R")
source("config.R")
source('state.R')
source('data.R')
source('phylo.R')

router <- make_router(
  route("/", home_page, NA)
)

server <- function(input, output, session) {
  router(input, output, session)
  config <- get_config()
  state <- make_state(input, config)
  state <- set_comp_prop(state, tuboids_dt)
  state <- set_comp_prop(state, annotation_dt)
  
  levels=phylo_make_levels()
  
  tree = phylo_make_tree(isolate(file.path(state$config$DATA_ROOT_DIR, 'taxonomy.json')))
  observe({login_fun(state, input)})
  
  output$tuboids_table <- DT::renderDataTable(get_comp_prop(state, tuboids_dt))
  output$annotation_table <- DT::renderDataTable({
    tbl = get_comp_prop(state, annotation_dt)
    # print(tbl)
    tbl[, datetime:=as.POSIXct(datetime, origin='1970-01-01')]
    tbl[order(-datetime)]
    
  })
  
  component <- reactive({
    if (is.null(get_query_param()$tub_id)) {
      return("")
    }
    get_query_param()$tub_id
  })
  
  make_selectize <- function(level){
    parent_level_id = which(levels == level) - 1
    parent_level = levels[parent_level_id]
    choices = NULL
    
    if(length(parent_level) ==0)
      choices = names(tree)
    else if(!is.null(state$choice[[parent_level]])){
      sub_tree = tree
      for(l in levels[1:parent_level_id]){
        sub_tree = sub_tree[[state$choice[[l]]]]
      }
      choices = c("",names(sub_tree))
    }
    
    selectizeInput(inputId = paste0('search_', level),
                   label = level,
                   choices = choices,
                   selected = NULL,
                   multiple = FALSE,
                   options = list(create = FALSE)) # if TRUE, allows newly created inputs
  }
  
  Map(function(l) {
    output[[paste0('search_',l)]] <- renderUI({ make_selectize(l)})
    }, levels)

  output$id_selected <- renderUI(
    {
      id_names <- c(input$search_type, input$search_order, input$search_family, input$search_genus, input$search_species, input$search_extra)
      
    o = lapply(id_names, function(x) {
      link <- sprintf("https://en.wikipedia.org/w/index.php?search=%s", x)
      tags$a(x, href=link, target="_blank")
      }
      )
    div(o)
    }
  )
  
  observeEvent(input$button_submit, {
    add_new_annotation(state, input)}
  )
  
  observeEvent(input$button_skip, {
    change_page(state$user$next_tuboid_url)}
  )
  
  Map(function(l){
    observeEvent(input[[paste0('search_',l)]], {
      state$choice[[l]] <- input[[paste0('search_',l)]]}
    )
  }, levels)
  output$button_submit <- renderUI({
    actionButton("button_submit", "Submit")
  })
  output$button_skip <- renderUI({
    actionButton("button_skip", "Skip")
  })
  
  output$next_url <- renderUI({h3(tags$a(href=state$user$next_tuboid_url, 'Skip'))})
  output$tuboid_page <- renderUI({
    
    tub_id = component()
    state$user$current_tuboid_id <- tub_id
    tub_dt = get_comp_prop(state, tuboids_dt)
    next_tuboid = get_next_to_annotate(state, input)
    state$user$next_tuboid_url <- sprintf("?tub_id=%s#!/",next_tuboid)
    if(is.null(tub_dt) | !tub_id %in% tub_dt[, tuboid_id])
      change_page(state$user$next_tuboid_url)
      
    
    all_imgs = get_all_images_for_tuboid(state, tub_dt[tuboid_id==tub_id, tuboid_dir])
    
    
    o = lapply(all_imgs$tuboid, function(x){
            tags$img(src=x, width=200, height=200, alt=x)
          })
    context = tags$img(src=all_imgs$context, class='img-responsive', alt=all_imgs$context)    
  
    # we can pre fetch and let the browser cache the next batch of images
    all_imgs_next_tub = get_all_images_for_tuboid(state, tub_dt[tuboid_id==next_tuboid, tuboid_dir])
    o_next = lapply(all_imgs_next_tub$tuboid, function(x){
      tags$img(src=x)
    })
    context_next = tags$img(src=all_imgs_next_tub$context)    
    
    
    return(list(
              column(width=6,context), 
              column(width=3, id='tuboid_shots', o),
              hidden(div(o_next, context_next))
          ))
  })
  output$secured_ui <- renderUI({
    if (state$user$is_logged_in == TRUE ) {
      shinyUI(fluidPage(theme = shinytheme("journal"),
                        useShinyjs(),
                        tags$head(
                          tags$link(rel = "stylesheet", type = "text/css", href = "style.css")
                        ),
                        router_ui()
      ))
    }
    else {
      login_ui()
    }
  })
}

ui <- make_ui()

shinyApp(ui = ui, server = server)


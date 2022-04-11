rm(list=ls())
library(shiny)
library(shinyjs)
library(shiny.router)
library(DT)
library(RSQLite)
library(data.table)
library(jsonlite)
library(shinythemes)
library(memoise)


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
  router$server(input, output, session)
  config <- get_config()
  state <- make_state(input, config)
  state <- set_comp_prop(state, tuboids_dt)
  state <- set_comp_prop(state, candidates_dt)
  state <- set_comp_prop(state, annotation_dt)

  levels=phylo_make_levels()

  tree = phylo_make_tree(isolate(state$config$S3_BUCKET))
  observe({login_fun(state, input)})

  output$tuboids_table <- DT::renderDataTable(get_comp_prop(state, tuboids_dt))
  output$annotation_table <- DT::renderDataTable({
    tbl = get_comp_prop(state, annotation_dt)
    tbl[, datetime:=as.POSIXct(datetime, origin='1970-01-01')]

    clmn = data.table(link = sapply( tbl$tuboid_id, function(x){
      as.character(shiny::actionButton(x,label="", icon=icon("link"), onClick="Shiny.setInputValue('tuboid_page', this.id);"))}
    ))
    tbl <- cbind(clmn, tbl)
    tbl[order(-datetime)]
  }, escape = FALSE, selection = 'none')

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

    #tree root here
    if(length(parent_level) ==0)
      choices = names(tree)

    else if(!is.null(state$choice[[parent_level]])){
      sub_tree = tree
      for(l in levels[1:parent_level_id]){
        sub_tree = sub_tree[[state$choice[[l]]]]
      }
      choices = c("",names(sub_tree))
    }

    candidates_dt = get_comp_prop(state, candidates_dt)
    candidate = candidates_dt[tuboid_id == state$user$current_tuboid_id,]

    preselected <- NULL
    if(nrow(candidate) == 1)
      if(isTruthy(candidate[[level]]))
        preselected <- candidate[[level]]
    selectizeInput(inputId = paste0('search_', level),
                   label = level,
                   choices = choices,
                   selected = preselected,
                   multiple = FALSE,
                   options = list(create = FALSE)) # if TRUE, allows newly created inputs
  }

  Map(function(l) {
    output[[paste0('search_',l)]] <- renderUI({ make_selectize(l)})
    }, levels)

  output$id_selected <- renderUI({

      id_names <- c(input$search_type, input$search_order, input$search_family,
                    input$search_genus, input$search_species, input$search_extra)

    o = lapply(id_names, function(x) {
      link <- sprintf("https://en.wikipedia.org/w/index.php?search=%s", x)
      tags$a(x, href=link, target="_blank")
      })

    div(o)
    }
  )

  observeEvent(input$button_submit, {
    add_new_annotation(state, input)
    })

  observeEvent(input$button_skip, {change_page(state$user$next_tuboid_url)})
  observeEvent(input$tuboid_page, {
    message(paste("tuboid_page", date()))

    url <-  sprintf("?tub_id=%s#!/", input$tuboid_page)

    o <- change_page(url)
    message(paste("tuboid_page, done", date()))
    o
   })

  Map(function(l){
    observeEvent(input[[paste0('search_',l)]], {
      state$choice[[l]] <- input[[paste0('search_',l)]]}
    )
  }, levels)

  output$button_submit <- renderUI({
    if(state$user$allow_write)
      actionButton("button_submit", "Submit")

    else
      actionButton("button_skip", "READ-ONLY")
  })

  output$button_skip <- renderUI({
    actionButton("button_skip", "Skip")
  })

  output$next_url <- renderUI({h3(tags$a(href=state$user$next_tuboid_url, 'Skip'))})

  tub_imgs <- reactive({

    tub_id = component()
    state$user$current_tuboid_id <- tub_id

    tub_dt = get_comp_prop(state, tuboids_dt)

    next_tuboid = get_next_to_annotate(state, input)

    state$user$next_tuboid_url <- sprintf("?tub_id=%s#!/",next_tuboid)
    if(is.null(tub_dt) | !tub_id %in% tub_dt[, tuboid_id])
      change_page(state$user$next_tuboid_url)

    all_imgs = get_all_image_urls_for_tuboid(state, tub_dt[tuboid_id==tub_id, tuboid_dir])

    all_imgs_next_tub = get_all_image_urls_for_tuboid(state, tub_dt[tuboid_id==next_tuboid, tuboid_dir])

    list(current=all_imgs, nextt=all_imgs_next_tub)
  })

  output$tuboid_shots <- renderUI({
    all_imgs_cur_next = tub_imgs()
    all_imgs <- all_imgs_cur_next$current
    all_imgs_next_tub = all_imgs_cur_next$nextt

    context = tags$img(src=all_imgs$context, class='img-responsive', alt=all_imgs$context)
    tub = tags$img(src=all_imgs$tuboid, class='img-responsive', alt=all_imgs$tuboid, width=800, height=800)

    # we can pre fetch and let the browser cache the next batch of images
    context_next = tags$img(src=all_imgs_next_tub$context,  width="1", height="1")
    tub_next = tags$img(src=all_imgs_next_tub$tuboid, class='img-responsive', alt=all_imgs_next_tub$tuboid, width=1, height=1)

    return(list(
              tub,
              div(id='preloader', tub_next)
          ))
  })
  output$metadata <- renderUI({
    all_imgs_cur_next = tub_imgs()
    if(is.null(all_imgs_cur_next$current))
      return(NULL)
    metadata <- all_imgs_cur_next$current$metadata

    metadata[1,scale]
    return(list(
      tags$h3(sprintf("Length: %.01f px", mean(metadata[,length]))),
      tags$h3(sprintf("First image: %s.jpg", metadata[1,image_id]))
    ))
  })

  output$context_img <- renderUI({
    all_imgs_cur_next = tub_imgs()
    all_imgs <- all_imgs_cur_next$current
    all_imgs_next_tub = all_imgs_cur_next$nextt

    context = tags$img(src=all_imgs$context, class='img-responsive', alt=all_imgs$context)
    tub = tags$img(src=all_imgs$tuboid, class='img-responsive', alt=all_imgs$tuboid, width=800, height=800)
    # we can pre fetch and let the browser cache the next batch of images
    context_next = tags$img(src=all_imgs_next_tub$context,  width="1", height="1")
    tub_next = tags$img(src=all_imgs_next_tub$tuboid, class='img-responsive', alt=all_imgs_next_tub$tuboid, width=1, height=1)

    return(list(
      context,
      div(id='preloader', context_next)
    ))
  })

  output$secured_ui <- renderUI({
    if (state$user$is_logged_in == TRUE ) {
      shinyUI(
        fluidPage(theme = shinytheme("journal"),
                        tags$head(
                          tags$link(rel = "stylesheet", type = "text/css", href = "style.css")
                        ),
                        useShinyjs(),
                        router$ui
        )
      )
    }
    else {
      login_ui()
    }
  })

     output$download_db <- downloadHandler(
        filename = function() {

          # paste(input$dataset, ".csv", sep = "")
          "database.db"
        },
      content = function(file) {

        root_dir <- state$config$DATA_ROOT_DIR
        db_path <- file.path(root_dir, 'database.db')
        file.copy(db_path, file)
        # write.csv(datasetInput(), file, row.names = FALSE)
      }
  )


  output$button_download <- renderUI({
      downloadButton("download_db", "Download Annotation Data")
  })




}

ui <- make_ui()

shinyApp(ui = ui, server = server)


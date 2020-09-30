# Main page UI.
home_page <- div(

  fluidRow(
    # column(width = 8,
      uiOutput("tuboid_page"),
      # ),
    column(width = 3, 
      
      uiOutput("search_type"),
      uiOutput("search_order"),
      uiOutput("search_family"),
      uiOutput("search_genus"),
      uiOutput("search_species"),
      uiOutput('id_selected'),
      uiOutput("button_submit"),
      uiOutput("button_skip"),
    ),
    fluidRow(column(width = 12, dataTableOutput('annotation_table')))
  )
  
) 

make_ui <- function(){
  uiOutput('secured_ui')
  
}

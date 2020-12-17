

login_ui <- function(){
  # log on press enter
    js <- '
$(document).on("keyup", function(e) {
  if(e.keyCode == 13){
    Shiny.onInputChange("login", Math.round((new Date()).getTime() / 1000));
  }
});
'
    div(id = "loginpage",
     style = "width: 500px; max-width: 100%; margin: 0 auto; padding: 20px;",
    tags$script(js),
    wellPanel(
     tags$h2("LOG IN", class = "text-center", style = "padding-top: 0;color:#333; font-weight:600;"),
     textInput("userName", placeholder="Username", label = tagList(icon("user"), "Username")),
     passwordInput("passwd", placeholder="Password", label = tagList(icon("unlock-alt"), "Password")),
     br(),
     div(
       style = "text-align: center;",
       list(
         actionButton("login",
                    "SIGN IN",
                    style = "color: white; background-color:#3c8dbc;padding: 10px 15px; width: 150px; cursor: pointer;font-size: 18px; font-weight: 600;"),
         shinyjs::hidden(
           div(id = "nomatch",
               tags$p("Incorrect username or password!",
                      style = "color: red; font-weight: 600;
                              padding-top: 5px;font-size:16px;",
                      class = "text-center")))
       )
     )
     )
    )
}

login_fun <- function(state, input){
  is_logged_in <- state$user$is_logged_in
  no_password_test  <- state$config$STICKY_PI_TESTING_RSHINY_BYPASS_LOGGIN
        if (is_logged_in == FALSE) {
          # this is when running without a container for instance. no db, so no password
          
          if(no_password_test){
            state$user$is_logged_in <- TRUE
            state$user$username <- "MOCK USER"
            state$user$allow_write <- TRUE
            }
            

          else if (!is.null(input$login)) {
            if (input$login > 0) {
                Username <- isolate(input$userName)
                Password <- isolate(input$passwd)
                auth = verify_passwd(state, Username, Password)
                token <- auth[[1]]
                
                if(token != ""){
                  state$user$auth_token <- token
                  state$user$is_logged_in <- TRUE
                  state$user$username <- Username
                  state$user$allow_write <- auth[[2]]
                }
            else{
              shinyjs::toggle(id = "nomatch", anim = TRUE, time = 1, animType = "fade")
              shinyjs::delay(3000, shinyjs::toggle(id = "nomatch", anim = TRUE, time = 1, animType = "fade"))
            }
            }
          }
        }
}

verify_passwd <- function(state, Username, Password){
  cred_file <- file.path(state$config$DATA_ROOT_DIR, 'credentials.json')
  users = jsonlite::fromJSON(cred_file)
  if(! Username %in% names(users)){
    return("")
  }
  if(Password != users[[Username]]$password){
    return("")
  }
  allow_write = users[[Username]]$allow_write
  if(is.na(allow_write) || is.null(allow_write))
    stop("allow_write must be defined for each user")
  
  return(list(as.character(round(runif(1, 0, 1e6))), allow_write))
  
}
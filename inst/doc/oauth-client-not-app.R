## -----------------------------------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>"
)

## -----------------------------------------------------------------------------
library(gargle)

## -----------------------------------------------------------------------------
path <- system.file(
  "extdata", "client_secret_web.googleusercontent.com.json",
  package = "gargle"
)
(client <- gargle_oauth_client_from_json(path))
class(client)

## -----------------------------------------------------------------------------
# drive_auth <- function(...) {
#   # code not shown
#   cred <- gargle::token_fetch(
#     scopes = scopes,
#     client = drive_oauth_client() %||% gargle::tidyverse_client(),
#     email = email,
#     path = path,
#     package = "googledrive",
#     cache = cache,
#     use_oob = use_oob,
#     token = token
#   )
#   # code not shown
# }

## -----------------------------------------------------------------------------
# drive_auth_configure <- function(client, path, api_key) {
#   # code not shown
#   .auth$set_client(client)
#   # code not shown
# }
# 
# drive_oauth_client <- function() .auth$client


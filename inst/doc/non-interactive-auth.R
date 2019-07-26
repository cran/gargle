## ---- include = FALSE----------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>"
)

## ----eval = FALSE--------------------------------------------------------
#  library(googledrive)
#  
#  drive_auth(path = "/path/to/your/service-account-token.json")

## ----eval = FALSE--------------------------------------------------------
#  options(gargle_quiet = FALSE)

## ----eval = FALSE--------------------------------------------------------
#  library(googledrive)
#  
#  my_oauth_token <- # some process that results in the token you want to use
#  drive_auth(token = my_oauth_token)

## ----eval = FALSE--------------------------------------------------------
#  # googledrive
#  drive_auth(token = readRDS("/path/to/your/oauth-token.rds"))

## ----eval = FALSE--------------------------------------------------------
#  library(gcalendr)
#  
#  # designate project-specific cache
#  options(gargle_oauth_cache = ".secrets")
#  
#  # check it
#  gargle::gargle_oauth_cache()
#  
#  # trigger auth on purpose --> store a token in the cache
#  calendar_auth()
#  
#  # see your token in the cache
#  list.files(".secrets/")

## ----eval = FALSE--------------------------------------------------------
#  library(gcalendr)
#  
#  options(
#    gargle_oauth_cache = ".secrets",
#    # as long as .secrets/ holds EXACTLY ONE token, this gives gcalendar
#    # permission to use it without requiring user to confirm
#    gargle_oauth_email = TRUE
#  
#    # alternative if .secrets/ holds more than one gcalendr token:
#    # you could disambiguate by specifying the user's email
#    # gargle_oauth_email = 'jenny@example.org'
#  )
#  
#  # now use gcalendr with no need for explicit auth
#  calendar_list()


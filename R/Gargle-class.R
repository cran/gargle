#' Generate a gargle token
#'
#' Constructor function for objects of class [Gargle2.0].
#'
#' @param email Optional. If specified, `email` can take several different
#'   forms:
#' * `"jane@gmail.com"`, i.e. an actual email address. This allows the user to
#' target a specific Google identity. If specified, this is used for token
#' lookup, i.e. to determine if a suitable token is already available in the
#' cache. If no such token is found, `email` is used to pre-select the targeted
#' Google identity in the OAuth chooser. (Note, however, that the email
#' associated with a token when it's cached is always determined from the token
#' itself, never from this argument).
#' * `"*@example.com"`, i.e. a domain-only glob pattern. This can be helpful if
#' you need code that "just works" for both `alice@example.com` and
#' `bob@example.com`.
#' * `TRUE` means that you are approving email auto-discovery. If exactly one
#'   matching token is found in the cache, it will be used.
#' * `FALSE` or `NA` mean that you want to ignore the token cache and force a
#' new OAuth dance in the browser.
#'
#' Defaults to the option named `"gargle_oauth_email"`, retrieved by
#' [gargle::gargle_oauth_email()] (unless a wrapper package implements different
#' default behavior).
#' @param client A Google OAuth client, preferably constructed via
#'   [gargle::gargle_oauth_client_from_json()], which returns an instance of
#'   `gargle_oauth_client`. For backwards compatibility, for a limited time,
#'   gargle will still accept an "OAuth app" created with [httr::oauth_app()].
#' @param package Name of the package requesting a token. Used in messages.
#' @param scope A character vector of scopes to request.
#' @param use_oob Whether to use out-of-band authentication (or, perhaps, a
#'   variant implemented by gargle and known as "pseudo-OOB") when first
#'   acquiring the token. Defaults to the value returned by
#'   [gargle::gargle_oob_default()]. Note that (pseudo-)OOB auth only affects
#'   the initial OAuth dance. If we retrieve (and possibly refresh) a
#'   cached token, `use_oob` has no effect.
#'
#'   If the OAuth client is provided implicitly by a wrapper package, its type
#'   probably defaults to the value returned by
#'   [gargle::gargle_oauth_client_type()]. You can take control of the client
#'   type by setting `options(gargle_oauth_client_type = "web")` or
#'   `options(gargle_oauth_client_type = "installed")`.
#' @param cache Specifies the OAuth token cache. Defaults to the option named
#'   `"gargle_oauth_cache"`, retrieved via [gargle::gargle_oauth_cache()].
#' @inheritParams httr::oauth2.0_token
#' @param ... Absorbs arguments intended for use by other credential functions.
#'   Not used.
#' @param app `r lifecycle::badge('deprecated')` Replaced by the `client`
#'   argument.
#' @return An object of class [Gargle2.0], either new or loaded from the cache.
#' @export
#' @examples
#' \dontrun{
#' gargle2.0_token()
#' }
gargle2.0_token <- function(email = gargle_oauth_email(),
                            client = gargle_client(),
                            package = "gargle",
                            ## params start
                            scope = NULL,
                            use_oob = gargle_oob_default(),
                            ## params end
                            credentials = NULL,
                            cache = if (is.null(credentials)) gargle_oauth_cache() else FALSE,
                            ...,
                            app = deprecated()) {
  if (lifecycle::is_present(app)) {
    lifecycle::deprecate_soft(
      "1.5.0",
      "gargle2.0_token(app)",
      "gargle2.0_token(client)"
    )
    client <- app
  }

  params <- list(
    scope = scope,
    use_oob = use_oob,
    as_header = TRUE
  )

  # pseudo-OOB flow
  client_type <- if (inherits(client, "gargle_oauth_client")) client$type else NA
  if (use_oob && identical(client_type, "web")) {
    params$oob_value <- select_pseudo_oob_value(client$redirect_uris)
  }
  # params$oob_value is deliberately left unspecified for conventional OOB,
  # with the intent of falling back to urn:ietf:wg:oauth:2.0:oob

  # this allows pseudo-OOB auth to work on colab, because:
  # 1) gargle's attempts to communicate with the user route through readline()
  #    which is shimmed in Jupyter (and therefore Colab)
  # 2) httr >= 1.4.5 honors the "rlang_interactive" option when deciding whether
  #   it will try the oauth dance
  if (is_google_colab()) {
    withr::local_options(rlang_interactive = TRUE)
  }

  Gargle2.0$new(
    email = email,
    client = client,
    package = package,
    params = params,
    credentials = credentials,
    cache_path = cache
  )
}

#' OAuth2 token objects specific to Google APIs
#'
#' @description
#' `Gargle2.0` is based on the [`Token2.0`][httr::Token-class] class provided in
#' httr. The preferred way to create a `Gargle2.0` token is through the
#' constructor function [gargle2.0_token()]. Key differences with `Token2.0`:
#' * The key for a cached `Token2.0` comes from hashing the endpoint, client,
#' and scopes. For the `Gargle2.0` subclass, the identifier or key is expanded
#' to include the email address associated with the token. This makes it easier
#' to work with Google APIs with multiple identities.
#' * `Gargle2.0` tokens are cached, by default, at the user level, following the
#' XDG spec for storing user-specific data and cache files. In contrast, the
#' default location for `Token2.0` is `./.httr-oauth`, i.e. in current working
#' directory. `Gargle2.0` behaviour makes it easier to reuse tokens across
#' projects and makes it less likely that tokens are accidentally synced to a
#' remote location like GitHub or DropBox.
#' * Each `Gargle2.0` token is cached in its own file. The token cache is a
#' directory of such files. In contrast, `Token2.0` tokens are cached as
#' components of a list, which is typically serialized to `./.httr-oauth`.
#'

#' @param email Optional email address. See [gargle2.0_token()] for full
#'   details.
#' @param client An OAuth consumer application.
#' @param package Name of the package requesting a token. Used in messages.
#' @param credentials Exists largely for testing purposes.
#' @param params A list of parameters for the internal function
#'   `init_oauth2.0()`, which is a modified version of [httr::init_oauth2.0()].
#'   gargle actively uses `scope` and `use_oob`, but does not use `user_params`,
#'   `type`, `as_header` (hard-wired to `TRUE`), `use_basic_auth` (accept
#'   default of `use_basic_auth = FALSE`), `config_init`, or
#'   `client_credentials`.
#' @param cache_path Specifies the OAuth token cache. Read more in
#'   [gargle::gargle_oauth_cache()].
#' @param app `r lifecycle::badge('deprecated')` Use `client` instead.
#'
#' @keywords internal
#' @export
#' @name Gargle-class
Gargle2.0 <- R6::R6Class("Gargle2.0", inherit = httr::Token2.0, list(
  #' @field email Email associated with the token.
  email = NULL,
  #' @field package Name of the package requesting a token. Used in messages.
  package = NULL,
  #' @field client An OAuth client.
  client = NULL,
  #' @description Create a Gargle2.0 token
  #' @return A Gargle2.0 token.
  initialize = function(email = gargle_oauth_email(),
                        client = gargle_client(),
                        package = "gargle",
                        credentials = NULL,
                        params = list(),
                        cache_path = gargle_oauth_cache(),
                        app = deprecated()) {
    gargle_debug("Gargle2.0 initialize")
    # I'm using deprecate_warn() intentionally here. Most folks should be
    # instantiating through gargle2.0_token() anyway, so anyone who sees this
    # warning probably needs to see it.
    if (lifecycle::is_present(app)) {
      lifecycle::deprecate_warn(
        "1.5.0",
        "Gargle2.0$initialize(app)",
        "Gargle2.0$initialize(client)"
      )
      client <- app
    }
    stopifnot(
      is.null(email) || is_scalar_character(email) ||
        isTRUE(email) || isFALSE(email) || is_na(email),
      is.oauth_app(client),
      is_string(package),
      is.list(params)
    )
    if (identical(email, "")) {
      gargle_abort(c(
        "{.arg email} must not be \"\" (the empty string).",
        "i" = "Do you intend to consult an env var, but it's unset?"
      ))
    }
    if (isTRUE(email)) {
      email <- "*"
    }
    if (isFALSE(email) || is_na(email)) {
      email <- NA_character_
    }
    # https://developers.google.com/identity/protocols/OpenIDConnect#login-hint
    # optional hint for the auth server to pre-fill the email box
    login_hint <- if (is_string(email) && !startsWith(email, "*")) email

    self$endpoint   <- gargle_oauth_endpoint()
    self$email      <- email
    self$client     <- client
    # for backwards compatibility and also because the parent class has $app;
    # I can never remove it
    self$app        <- client
    self$package    <- package
    params$scope    <- normalize_scopes(add_email_scope(params$scope))
    params$query_authorize_extra <- list(login_hint = login_hint)
    self$params     <- params
    self$cache_path <- cache_establish(cache_path)

    if (!is.null(credentials)) {
      # Use credentials created elsewhere - usually for tests
      gargle_debug("credentials provided directly")
      self$credentials <- credentials
      return(self$cache())
    }

    # Are credentials cached already?
    if (self$load_from_cache()) {
      self
    } else {
      gargle_debug("no matching token in the cache")
      self$init_credentials()
      self$email <- token_email(self) %||% NA_character_
      self$cache()
    }
  },
  #' @description Format a Gargle2.0 token
  #' @param ... Not used.
  format = function(...) {
    x <- list(
      oauth_endpoint = "google",
      client         = self$client$name,
      email          = cli::format_inline("{.email {self$email}}"),
      scopes         = commapse(base_scope(self$params$scope)),
      credentials    = commapse(names(self$credentials))
    )
    c(
      cli::cli_format_method(
        cli::cli_h1("<Token (via {.pkg gargle})>")
      ),
      glue("{fr(names(x))}: {fl(x)}")
    )
  },
  #' @description Print a Gargle2.0 token
  #' @param ... Not used.
  print = function(...) {
    # a format method is not sufficient for Gargle2.0 because the parent class
    # has a print method
    cli::cat_line(self$format())
  },
  #' @description Generate the email-augmented hash of a Gargle2.0 token
  hash = function() {
    paste(super$hash(), self$email, sep = "_")
  },
  #' @description Put a Gargle2.0 token into the cache
  cache = function() {
    token_into_cache(self)
    self
  },
  #' @description (Attempt to) get a Gargle2.0 token from the cache
  load_from_cache = function() {
    gargle_debug("loading token from the cache")
    if (is.null(self$cache_path) || is_na(self$email)) {
      return(FALSE)
    }

    gargle_debug("email: {.email {self$email}}")
    gargle_debug("oauth client name: {self$client$name}")
    gargle_debug("oauth client name: {self$client$type}")
    gargle_debug("oauth client id: {self$client$id}")
    gargle_debug("scopes: {commapse(base_scope(self$params$scope))}")

    cached <- token_from_cache(self)
    if (is.null(cached)) {
      return(FALSE)
    }

    gargle_debug("matching token found in the cache")
    self$endpoint    <- cached$endpoint
    self$email       <- cached$email
    self$client      <- cached$client
    self$app         <- cached$client
    self$credentials <- cached$credentials
    self$params      <- cached$params
    TRUE
  },
  #' @description (Attempt to) refresh a Gargle2.0 token
  refresh = function() {
    cred <- refresh_oauth2.0(
      self$endpoint, self$client, self$credentials,
      package = self$package
    )
    if (is.null(cred)) {
      token_remove_from_cache(self)
      # It's tricky to decide what to do here. Currently we return the current,
      # invalid, unrefreshed token, but we clear the refresh_token field, to
      # prevent subsequent refresh attempts.
      #
      # Analysis from a BYO token POV:
      # I've decided the status quo may be the best move, because it causes
      # token_fetch() to return instead of moving on to try other methods. If
      # someone provides token_fetch(token =), I think it's clear that they
      # want/hope to use that token and they don't want to end up doing the
      # OAuth browser dance. If we threw an error or returned NULL,
      # token_fetch() would just keep going. The refresh failure does throw a
      # visible warning:
      #
      # Warning message:
      # Unable to refresh token: invalid_grant
      # • Token has been expired or revoked.
      #
      # However, this does mean that functions like PKG_has_token() still return
      # TRUE and that some other method must be used to find out if we have a
      # *valid* token. gargle::token_tokeninfo() and API-specific functions for
      # "tell me about the current user" are good candidates, such as
      # gmailr::gm_profile() or googledrive::drive_user().
      self$credentials$refresh_token <- NULL
    } else {
      self$credentials <- cred
      self$cache()
    }
    self
  },
  #' @description Initiate a new Gargle2.0 token
  init_credentials = function() {
    gargle_debug("initiating new token")
    if (is_interactive()) {
      if (!isTRUE(self$params$use_oob) && !is_hosted_session()) {
        encourage_httpuv()
      }
      self$credentials <- init_oauth2.0(
        self$endpoint,
        self$client,
        scope = self$params$scope,
        use_oob = self$params$use_oob,
        oob_value = self$params$oob_value,
        query_authorize_extra = self$params$query_authorize_extra
      )
    } else {
      # TODO: good candidate for an eventual sub-classed gargle error
      # would be useful in testing to know that this is exactly where we aborted
      gargle_abort("OAuth2 flow requires an interactive session.")
    }
  }
))

encourage_httpuv <- function() {
  if (!is_interactive() || isTRUE(is_installed("httpuv"))) {
    return(invisible())
  }
  choice <- cli_menu(
   "The {.pkg httpuv} package enables a nicer Google auth experience, in many \\
    cases, but it isn't installed.",
    "Would you like to install it now?",
    choices = c("Yes", "No")
  )
  if (choice == 1) {
    utils::install.packages("httpuv")
  }
  invisible()
}

# I want to encourage users to create an OAuth client (newer httr2-y language)
# directly from downloaded JSON, using gargle_oauth_client_from_json().
# Sometimes there are multiple URIs and I think we can usually figure out which
# one to use for the pseudo-OOB flow.
select_pseudo_oob_value <- function(redirect_uris) {
  # https://developers.google.com/identity/protocols/oauth2/resources/oob-migration#inspect-your-application-code
  bad_values <- c(
    "urn:ietf:wg:oauth:2.0:oob",
    "urn:ietf:wg:oauth:2.0:oob:auto",
    "oob"
  )
  redirect_uris <- setdiff(redirect_uris, bad_values)

  # https://developers.google.com/identity/protocols/oauth2/web-server#uri-validation
  bad_regex <- "^http[s]?://(localhost|127.0.0.1)"
  redirect_uris <- grep(bad_regex, redirect_uris, value = TRUE, invert = TRUE)
  redirect_uris <- grep("^https", redirect_uris, value = TRUE)

  # inspired by these guidelines re: URIs associated with URL shorteners:
  # 'redirect URI must either contain "/google-callback/" in its path or end
  # with "/google-callback"'
  m <- grep("/google-callback(/|$)", redirect_uris)
  if (length(m) > 0) {
    redirect_uris <- redirect_uris[m]
  }

  if (length(redirect_uris) == 0) {
    gargle_abort('
      OAuth client does not have a redirect URI suitable for the pseudo-OOB \\
      flow.')
  }

  if (length(redirect_uris) > 1) {
    msg <- c(
      "Can't determine which redirect URI to use for the pseudo-OOB flow:",
      set_names(redirect_uris, ~ rep_along(., "*"))
    )
    gargle_abort(msg)
  }

  redirect_uris
}

test_that("default options", {
  withr::local_options(list(
    gargle_oauth_cache = NULL,
    gargle_oob_default = NULL, httr_oob_default = NULL,
    gargle_oauth_client_type = NULL,
    gargle_oauth_email = NULL,
    gargle_verbosity   = NULL,
    gargle_quiet       = NULL
  ))
  expect_equal(gargle_oauth_cache(), NA)
  if (is_hosted_session()) {
    expect_true(gargle_oob_default())
    expect_equal(gargle_oauth_client_type(), "web")
  } else {
    expect_false(gargle_oob_default())
    expect_equal(gargle_oauth_client_type(), "installed")
  }
  expect_null(gargle_oauth_email())
  expect_equal(gargle_verbosity(), "info")
})

test_that("gargle_oob_default() consults gargle's option before httr's", {
  withr::local_options(list(
    gargle_oob_default = TRUE,
    httr_oob_default = FALSE
  ))
  expect_true(gargle_oob_default())
})

test_that("gargle_oob_default() consults httr's option", {
  withr::local_options(list(
    gargle_oob_default = NULL,
    httr_oob_default = TRUE
  ))
  expect_true(gargle_oob_default())
})

test_that("gargle_oauth_client_type() consults the option", {
  withr::local_options(list(gargle_oauth_client_type = "web"))
  expect_equal(gargle_oauth_client_type(), "web")
})

test_that("gargle API key", {
  key <- gargle_api_key()
  expect_true(is_string(key))
})

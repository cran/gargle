test_that("request_retry() logic works as advertised", {
  faux_response <- function(status_code = 200, h = NULL) {
    structure(
      list(
        status_code = status_code,
        headers = if (!is.null(h)) httr::insensitive(h)
      ),
      class = "response"
    )
  }
  # allows us to replay a fixed set of responses
  faux_request_make <- function(responses = list(faux_response())) {
    i <- 0
    force(responses)
    function(...) {
      i <<- i + 1
      responses[[i]]
    }
  }

  # turn this: Retry 1 happens in 1.7 seconds
  #            Retry 1 happens in 1 seconds
  # into this: Retry 1 happens in {WAIT_TIME} seconds
  scrub_wait_time <- function(x) {
    sub(
      "(?<=in )[[:digit:]]+([.][[:digit:]]+)?(?= seconds)",
      "{WAIT_TIME}",
      x,
      perl = TRUE
    )
  }
  # turn this: (strategy: exponential backoff, full jitter, clipped to floor of 1 seconds)
  #            (strategy: exponential backoff, full jitter, clipped to ceiling of 45 seconds)
  # into this: (strategy: exponential backoff, full jitter)
  scrub_strategy <- function(x) {
    sub(
      ", clipped to (floor|ceiling) of [[:digit:]]+([.][[:digit:]]+)? seconds",
      "",
      x,
      perl = TRUE
    )
  }
  scrub <- function(x) scrub_strategy(scrub_wait_time(x))
  local_gargle_verbosity("debug")
  local_mocked_bindings(gargle_error_message = function(...) "oops")

  # succeed on first try
  local_mocked_bindings(request_make = faux_request_make())
  out <- request_retry()
  expect_equal(httr::status_code(out), 200)

  # fail, then succeed (exponential backoff)
  r <- list(faux_response(429), faux_response())
  local_mocked_bindings(request_make = faux_request_make(r))
  expect_snapshot(
    fail_then_succeed <- request_retry(max_total_wait_time_in_seconds = 5),
    transform = scrub
  )
  expect_equal(httr::status_code(fail_then_succeed), 200)

  # fail, then succeed (Retry-After header)
  r <- list(
    faux_response(429, h = list(`Retry-After` = 1.4)),
    faux_response()
  )
  local_mocked_bindings(request_make = faux_request_make(r))
  expect_snapshot(
    fail_then_succeed <- request_retry(),
    transform = scrub
  )
  expect_equal(httr::status_code(fail_then_succeed), 200)

  # make sure max_tries_total is adjustable)
  r <- list(
    faux_response(429),
    faux_response(429),
    faux_response(429),
    faux_response()
  )
  local_mocked_bindings(request_make = faux_request_make(r[1:3]))
  expect_snapshot(
    fail_max_tries <- request_retry(
      max_tries_total = 3, max_total_wait_time_in_seconds = 6
    ),
    transform = scrub
  )
  expect_equal(httr::status_code(fail_max_tries), 429)
})

test_that("backoff() obeys obvious bounds from min_wait and max_wait", {
  faux_error <- function() {
    structure(list(status_code = 429), class = "response")
  }

  # raw wait_times in U[0,1], therefore all become min_wait + U[0,1]
  local_mocked_bindings(gargle_error_message = function(...) "oops")

  suppressMessages(
    wait_times <- vapply(
      rep.int(1, 100),
      backoff,
      FUN.VALUE = numeric(1),
      resp = faux_error(), min_wait = 3
    )
  )
  expect_true(all(wait_times > 3))
  expect_true(all(wait_times < 4))

  # raw wait_times in U[0,6], those that are < 1 become min_wait + U[0,1] and
  # those > 3 become max_wait + U[0,1]
  suppressMessages(
    wait_times <- vapply(
      rep.int(1, 100),
      backoff,
      FUN.VALUE = numeric(1),
      resp = faux_error(), base = 6, max_wait = 3
    )
  )
  expect_true(all(wait_times > 1))
  expect_true(all(wait_times < 3 + 1))
})

test_that("backoff() honors Retry-After header", {
  faux_429 <- function(h) {
    structure(
      list(
        status_code = 429,
        headers = httr::insensitive(h)
      ),
      class = "response"
    )
  }
  local_mocked_bindings(gargle_error_message = function(...) "oops")

  # play with capitalization and character vs numeric
  suppressMessages(
    out <- backoff(1, faux_429(list(`Retry-After` = "1.2")))
  )
  expect_equal(out, 1.2)

  suppressMessages(
    out <- backoff(1, faux_429(list(`retry-after` = 2.4)))
  )
  expect_equal(out, 2.4)

  # should work even when tries_made > 1
  suppressMessages(
    out <- backoff(3, faux_429(list(`reTry-aFteR` = 3.6)))
  )
  expect_equal(out, 3.6)
})

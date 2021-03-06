context("Multi handle")

test_that("Max connections works", {
  skip_if_not(curl_version()$version >= as.numeric_version("7.30"),
    "libcurl does not support host_connections")
  multi_set(host_con = 2, multiplex = FALSE)
  for(i in 1:3){
    multi_add(new_handle(url = httpbin("delay/2")))
  }
  out <- multi_run(timeout = 3.5)
  expect_equal(out, list(success = 2, error = 0, pending = 1))
  out <- multi_run(timeout = 2)
  expect_equal(out, list(success = 1, error = 0, pending = 0))
  out <- multi_run()
  expect_equal(out, list(success = 0, error = 0, pending = 0))
})

test_that("Max connections reset", {
  multi_set(host_con = 6, multiplex = TRUE)
  for(i in 1:3){
    multi_add(new_handle(url = httpbin("delay/2")))
  }
  out <- multi_run(timeout = 4)
  expect_equal(out, list(success = 3, error = 0, pending = 0))
})

test_that("Timeout works", {
  h1 <- new_handle(url = httpbin("delay/3"))
  h2 <- new_handle(url = httpbin("post"), postfields = "bla bla")
  h3 <- new_handle(url = "https://urldoesnotexist.xyz", connecttimeout = 1)
  h4 <- new_handle(url = "http://localhost:14", connecttimeout = 1)
  m <- new_pool()
  multi_add(h1, pool = m)
  multi_add(h2, pool = m)
  multi_add(h3, pool = m)
  multi_add(h4, pool = m)
  rm(h1, h2, h3, h4)
  gc()
  out <- multi_run(timeout = 2, pool = m)
  expect_equal(out, list(success = 1, error = 2, pending = 1))
  out <- multi_run(timeout = 0, pool = m)
  expect_equal(out, list(success = 0, error = 0, pending = 1))
  out <- multi_run(pool = m)
  expect_equal(out, list(success = 1, error = 0, pending = 0))
})

test_that("Callbacks work", {
  total = 0;
  h1 <- new_handle(url = httpbin("get"))
  multi_add(h1, done = function(...){
    total <<- total + 1
    multi_add(h1, done = function(...){
      total <<- total + 1
    })
  })
  gc() # test that callback functions are protected
  out <- multi_run()
  expect_equal(out, list(success=2, error=0, pending=0))
  expect_equal(total, 2)
})

test_that("Multi cancel works", {
  expect_length(multi_list(), 0)
  h1 <- new_handle(url = httpbin("get"))
  multi_add(h1)
  expect_length(multi_list(), 1)
  expect_error(multi_add(h1), "locked")
  expect_equal(multi_run(timeout = 0), list(success = 0, error = 0, pending = 1))
  expect_length(multi_list(), 1)
  expect_is(multi_cancel(h1), "curl_handle")
  expect_length(multi_list(), 0)
  expect_is(multi_add(h1), "curl_handle")
  expect_length(multi_list(), 1)
  expect_equal(multi_run(), list(success = 1, error = 0, pending = 0))
  expect_length(multi_list(), 0)
})

test_that("Errors in Callbacks", {
  pool <- new_pool()
  cb <- function(req){
    stop("testerror in callback!")
  }
  curl_fetch_multi(httpbin("get"), pool = pool, done = cb)
  curl_fetch_multi(httpbin("status/404"), pool = pool, done = cb)
  curl_fetch_multi("https://urldoesnotexist.xyz", pool = pool, fail = cb)
  gc()
  expect_equal(total_handles(), 3)
  expect_error(multi_run(pool = pool), "testerror")
  gc()
  expect_equal(total_handles(), 2)
  expect_error(multi_run(pool = pool), "testerror")
  gc()
  expect_equal(total_handles(), 1)
  expect_error(multi_run(pool = pool), "testerror")
  gc()
  expect_equal(total_handles(), 0)
  expect_equal(multi_run(pool = pool), list(success = 0, error = 0, pending = 0))
})

test_that("GC works", {
  gc()
  expect_equal(total_handles(), 0L)
})


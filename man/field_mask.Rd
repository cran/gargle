% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/field_mask.R
\name{field_mask}
\alias{field_mask}
\title{Generate a field mask}
\usage{
field_mask(x)
}
\arguments{
\item{x}{A named R list, where the requirement for names applies at all
levels, i.e. recursively.}
}
\value{
A Google API field mask, as a string.
}
\description{
Many Google API requests take a field mask, via a \code{fields} parameter, in the
URL and/or in the body. \code{field_mask()} generates such a field mask from an R
list, typically a list that is destined to be part of the body of a request
that writes or updates a resource. \code{field_mask()} is designed to help in the
common case where the attributes you wish to modify are exactly the ones
represented in the object. It is possible to use a "larger" field mask, that
is either less specific or that explicitly includes other attributes, in
which case the attributes covered by the mask but absent from the object are
reset to default values. This is not exactly the use case \code{field_mask()} is
designed for, but its output could still be useful as a first step in
constructing such a mask.
}
\examples{
x <- list(sheetId = 1234, title = "my_favorite_worksheet")
field_mask(x)

x <- list(
  userEnteredFormat = list(
    backgroundColor = list(
      red = 159 / 255, green = 183 / 255, blue = 196 / 255
    )
  )
)
field_mask(x)

x <- list(
  sheetId = 1234,
  gridProperties = list(rowCount = 5, columnCount = 3)
)
field_mask(x)
}
\seealso{
The documentation for the \href{https://protobuf.dev/reference/protobuf/google.protobuf/#json-encoding-of-field-masks}{JSON encoding of a Protocol Buffers FieldMask}.
}

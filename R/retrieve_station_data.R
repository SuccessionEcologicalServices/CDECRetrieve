#' Function builds CDEC Url to request data
#' @param station_id three letter identification for CDEC location
#' @param sensor_num sensor number for the measure of interest
#' @param dur_code duration code for measure interval, "E", "H", "D"
#' @param start_date date to start the query on
#' @param end_date a non-inclusive date to end the query on
#' @return string url
make_cdec_url <- function(station_id, sensor_num,
                     dur_code, start_date, end_date=as.character(Sys.Date())) {
  cdec_urls$download_shef %>%
    stringr::str_replace("STATION", station_id) %>%
    stringr::str_replace("SENSOR", sensor_num) %>%
    stringr::str_replace("DURCODE", dur_code) %>%
    stringr::str_replace("STARTDATE", start_date) %>%
    stringr::str_replace("ENDDATE", end_date)

}

#' Function converts shef downloaded data into one of a tidy format
#' @param file shef filename obtained from CDEC
#' @return data frame in tidy form
shef_to_tidy <- function(file) {
  raw <- readr::read_delim(file, skip = 9, col_names = FALSE, delim = " ")

  if (ncol(raw) < 5) {
    stop("A faulty query was requested, please check query,
         does this station have this duration and sensor combination?")
  }

  raw <- raw[, c(2, 3, 5, 6, 7)]  # keep relevant cols
  raw <- raw %>% tidyr::unite_(col = "datetime",
                               from = c("X3", "X5"), sep ="", remove = TRUE)
  raw$datetime <- lubridate::ymd_hm(raw$datetime)

  shef_code <- raw$X6[1]
  cdec_code <- ifelse(is.null(shef_code_lookup[[shef_code]]),
                      NA, shef_code_lookup[[shef_code]])
  raw$X6 <- rep(cdec_code, nrow(raw))
  colnames(raw) <- c("location_id", "datetime", "parameter_cd", "parameter_value")

  # parse to correct type
  raw$parameter_value <- as.numeric(raw$parameter_value)

  return(raw[, c(2, 1, 3, 4)])
}

#' Function queries the CDEC services to obtain desired station data
#' @param station_id three letter identification for CDEC location.
#' @param sensor_num sensor number for the measure of interest.
#' @param dur_code duration code for measure interval, "E", "H", "D", which correspong to Event, Hourly and Daily.
#' @param start_date date to start the query on.
#' @param end_date a date to end query on, defaults to current date.
#' @return tidy dataframe
#' @examples
#' kwk_hourly_temp <- CDECRetrieve::retrieve_station_data("KWK", "20", "H", "2017-01-01")
#'
#' @export
retrieve_station_data <- function(station_id, sensor_num,
                                dur_code, start_date, end_date="") {

  # a real ugly side effect here, but its reliability is great
  raw_file <- utils::download.file(make_cdec_url(station_id, sensor_num,
                                          dur_code, start_date, end_date),
                            destfile = "tempdl.txt",
                            quiet = TRUE)

  # catch the case when cdec is down
  if (file.info("tempdl.txt")$size == 0) {
    stop("query did not produce a result, possible cdec is down?")
  }

  on.exit(file.remove("tempdl.txt"))
  resp <- shef_to_tidy("tempdl.txt")
  resp$agency_cd <- "CDEC"
  resp[,c(5, 1:4)]
}

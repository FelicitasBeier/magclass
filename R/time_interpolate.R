#' time_interpolate
#' 
#' Function to extrapolate missing years in MAgPIE objects.
#' 
#' 
#' @param dataset An MAgPIE object
#' @param interpolated_year Vector of years, of which values are required. Can
#' be in the formats 1999 or y1999.
#' @param integrate_interpolated_years FALSE returns only the dataset of the
#' interpolated year, TRUE returns the whole dataset, including all years of
#' data and the itnerpolated year
#' @param extrapolation_type Determines what happens if extrapolation is
#' required, i.e. if a requested year lies outside the range of years in
#' \code{dataset}. Specify "linear" for a linear extrapolation. "constant" uses
#' the value from dataset closest in time to the requested year.
#' @return Uses linear extrapolation to estimate the values of the interpolated
#' year, using the values of the two surrounding years. If the value is before
#' or after the years in data, the two closest neighbours are used for
#' extrapolation.
#' @author Benjamin Bodirsky, Jan Philipp Dietrich
#' @seealso \code{\link{lin.convergence}}
#' @examples
#' 
#' data(population_magpie)
#' time_interpolate(population_magpie,"y2000",integrate=TRUE)
#' time_interpolate(population_magpie,c("y1980","y2000"),integrate=TRUE,extrapolation_type="constant")
#' 
#' @export time_interpolate
time_interpolate <- function(dataset, interpolated_year, integrate_interpolated_years=FALSE,extrapolation_type="linear") {
  if(!is.magpie(dataset)){stop("Invalid Data format of measured data. Has to be a MAgPIE-object.")}
  if (all(isYear(interpolated_year,with_y=FALSE))) { interpolated_year<-paste("y",interpolated_year,sep="")} else 
  { if (any(isYear(interpolated_year, with_y=TRUE))==FALSE) {stop("year not in the right format")} }
  
  Md <- getMetadata(dataset)
  if(nyears(dataset)==1) {
    tmp <- dataset
    dimnames(tmp)[[2]] <- "y0000"
    dataset <- mbind(tmp,dataset)
  }
  
  interpolated_year_filtered <- interpolated_year[!interpolated_year%in%getYears(dataset)]
  dataset_interpolated       <- array(NA,
                                      dim=c(dim(dataset)[1],length(interpolated_year_filtered),dim(dataset)[3]),
                                      dimnames=list(getCells(dataset),interpolated_year_filtered,getNames(dataset))
  )
  dataset<-as.array(dataset)
  
  
  for(single_interpolated_year in interpolated_year_filtered) {
    sorted_years                <-  sort(c(dimnames(dataset)[[2]],single_interpolated_year))
    if (sorted_years[1]==single_interpolated_year)
    {
      year_before <-sorted_years[2]
      year_after  <-sorted_years[3]    
      year_extrapolate<-ifelse(extrapolation_type=="constant",sorted_years[2],-1) 
    } else if (sorted_years[length(sorted_years)]==single_interpolated_year){
      year_before <-sorted_years[length(sorted_years)-2]
      year_after  <-sorted_years[length(sorted_years)-1]     
      year_extrapolate<-ifelse(extrapolation_type=="constant",sorted_years[length(sorted_years)-1],-1)     
    } else{
      year_before<-sorted_years[which(sorted_years==single_interpolated_year)-1]
      year_after<-sorted_years[which(sorted_years==single_interpolated_year)+1]
      year_extrapolate<- -1
    }
    
    interpolated_year_int       <- as.integer(substring(single_interpolated_year,2))
    year_before_int             <- as.integer(substring(year_before,2))
    year_after_int              <- as.integer(substring(year_after,2))
    
    dataset_difference          <-  dataset[,year_after,,drop=FALSE] - dataset[,year_before,,drop=FALSE]
    year_before_to_after        <-  year_after_int        - year_before_int
    year_before_to_interpolated <-  interpolated_year_int - year_before_int
    
    
    if(year_extrapolate== -1){
      dataset_interpolated[,single_interpolated_year,] <- dataset[,year_before,,drop=FALSE]+ year_before_to_interpolated * dataset_difference / year_before_to_after
    } else {
      dataset_interpolated[,single_interpolated_year,] <- dataset[,year_extrapolate,,drop=FALSE]
    }
  }
  if(integrate_interpolated_years==FALSE) {
    add_years <- setdiff(interpolated_year,interpolated_year_filtered)
    if(length(add_years)>0){
      dataset <- abind::abind(dataset_interpolated,dataset[,add_years,,drop=FALSE],along=2)
    } else {
      dataset <- dataset_interpolated
    }
  } else {
    if (any(getYears(dataset)=="y0000")){
      dataset <- dataset[,-which(getYears(dataset)=="y0000"),,drop=FALSE]
    }
    dataset<-abind::abind(dataset,dataset_interpolated,along=2)
  }
  dataset <- as.magpie(dataset)
  dataset <- dataset[,sort(getYears(dataset)),]
  getMetadata(dataset) <- Md
  return(dataset)
}

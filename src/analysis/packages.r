## Author: Alan Ruttenberg
## Project: OHD
## Date: 2015-04-16
##
## Try to install packages we need, if necessary


install_if_necessary <- function (package,from=NULL)
{ if (!require(package,character.only = TRUE)) 
    { cat("****************\n****************\n\n Installing R package ",package,"\n\n****************\n****************",sep="")
      if (is.null(from))
        { install.packages(package,dependencies=TRUE); require(package) }
      else
        { install.packages(c((paste(getwd(),"/",from,sep="")),repos=NULL),type="source") }
    }
}

install_if_necessary("XML")
install_if_necessary("SPARQL")
install_if_necessary("rJava")
install_if_necessary("rrdflibs","rrdflibs_1.3.0.tar.gz")
install_if_necessary("rrdf","rrdf_2.0.2.tar.gz")
install_if_necessary("ggthemes")
install_if_necessary("Cairo")
install_if_necessary("gridExtra")
install_if_necessary("httr")
install_if_necessary("GetoptLong")
install_if_necessary("pryr")
install_if_necessary("simPH")

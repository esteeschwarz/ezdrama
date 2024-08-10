library(reticulate)
getwd()
test_r<-100
source_python("test.py",envir = globalenv())

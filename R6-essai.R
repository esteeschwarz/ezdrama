# R6 essai
P6 <- R6::R6Class("Parser",
                      public = list(
                       # self$tree_root <- xml_new_root("TEI", ns = "http://www.tei-c.org/ns/1.0"),
                       tree_root = NULL,
                       x.df = NULL, #data.frame(left=1:10,right=LETTERS[1:10]),
                         adchild = function(tag,text){
                           print(1)
                          xml_add_child(self$tree_root,tag)
                          t1<-xml_find_first(self$tree_root,tag)
                          xml_text(t1)<-text
                          self$playchild(tag)
                          self$ad2child("2tag")
                        },
                        playchild = function(what){
                          print(2)
                          print(xml_find_all(self$tree_root,what))
                          t1<-xml_find_first(self$tree_root,what)
                          xml_text(t1)
                          print(self$x.df)
                        },
                       ad2child = function(tag){
                         child2<-xml_find_first(self$tree_root,"//sp")
                         xml_add_child(child2,tag)
                         #self$tree_root
                       },
                        initialize = function(range=1:10) {
                          library(xml2)
                          print(3)
                          x.df = data.frame(left=range,right=letters[range])
                          
                          self$tree_root <- xml_new_root("TEI", ns = "http://www.tei-c.org/ns/1.0")
                        }
                      ))
p6<-P6$new()
p6$initialize(range=1:25)
p6$adchild("sp","dummy")
p6$tree_root
#x1<-parser$tree_root
#xml2<-read_xml(x1)
xml1<-read_xml("sample.sf.xml")
#xml_add_child(xml1$text,"dummy")
xml1[[1]]
library(purrr)
xml1%>%xml_ns_strip()
xml1$TEI$text
xml_child(xml1, 3)
#xml_child(parser[["tree_root"]], 3)
#xml_find_all(parser[["tree_root"]],"//body")
save(p6,file = "p6env.RData")

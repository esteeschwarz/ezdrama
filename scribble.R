xml_new_document("tree_root")
#B <- xml_add_child(self$tree_root, "text")
a<-xml_new_root("tree_root")
#?xml_new_root
#A0<-xml_find_first(a,"text")
B<-xml_add_child(a, "text")
A0<-xml_find_first(a,"text")
A1 <- xml_add_child(A0, "top")
D <- xml_add_child(A1, "front")
C <- xml_add_child(D, "body")
a
tree_root<-parser$tree_root
line<-"@title: dummyline"

str_trim(substr(line, 7, nchar(line)))
xml_add_child(C, str_trim(substr(line, 7, nchar(line))))
xml_set_text(A, str_trim(substr(line, 7, nchar(line))))
A <- xml_add_child(B, "title",line)

str_trim(line)
B
F_F <- xml_add_child(a, "sp")
xml_set_attr(F_F,a_J,"who") # who
xml_add_child(F_F, a_M, B) # speaker
C <- substr(line, 1, 1)
C %in% strsplit(parser$special_symb_list, "")[[1]]

E <- substr(line, 2, nchar(B))

C<-"@ham (laut) !
sausage and
ham"
B <- strsplit(C, a_H)[[1]] # \n
D <- B[1]

D
B <- str_match(D, '([^()]+)(\\(.+?\\))([.,:!;])?')
B

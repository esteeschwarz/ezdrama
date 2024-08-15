xml_new_document("tree_root")
#B <- xml_add_child(self$tree_root, "text")
a<-xml_new_root("tree_root")
?xml_new_root
B<-xml_add_child(a, "text")
D <- xml_add_child(B, "front")
C <- xml_add_child(B, "body")
a
tree_root<-parser$tree_root
line<-"@title: dummyline"
str_trim(substr(line, 7, nchar(line)))
xml_add_child(C, str_trim(substr(line, 7, nchar(line))))
xml_set_text(A, str_trim(substr(line, 7, nchar(line))))
A <- xml_add_child(B, "title",line)

str_trim(line)
B

# 14317.ezdrama-parser.R-translation.essai
# 20240802
##########
# Q: <https://github.com/dracor-org/ezdrama/blob/main/parser.py>
# python file compression to char < 20.000: <https://freecodingtools.org/online-minifier/python>
# base translation: <https://www.codeconvert.ai/app>

library(xml2)
library(stringr)
library(rvest)

a_L <- 'castList'
a_K <- '-->\\s*$'
a_J <- 'who'
a_I <- 'xml:id'
a_H <- '\n'
a_G <- '.,:!; '
a_F <- 'stage'
a_E <- 'titleStmt'
a_D <- TRUE
a_C <- 'xml'
a_B <- 'type'
a_A <- 'level'

Parser <- R6::R6Class("Parser",
                      public = list(
                        tree_root = NULL,
                        is_prose = NULL,
                        current_lowest_tag = NULL,
                        current_lowest_div = NULL,
                        lasting_comment = NULL,
                        special_symb_list = NULL,
                        bracketstages = NULL,
                        tree_to_write = NULL,
                        outputname = NULL,
                        
                        
                        initialize = function(bracketstages = a_D, is_prose = a_D, dracor_id = 'insert_id', dracor_lang = 'insert_lang') {
                          self$tree_root <- xml_new_root("TEI", ns = "http://www.tei-c.org/ns/1.0")
                          xml_set_attr(self$tree_root, a_I, dracor_id)
                          xml_set_attr(self$tree_root, "xml:lang", dracor_lang)
                          self$create_and_add_header()
                          self$add_standoff()
                          B <- xml_add_child(self$tree_root, "text")
                          D <- xml_add_child(B, "front")
                          C <- xml_add_child(B, "body")
                          self$is_prose <- is_prose
                          self$current_lowest_tag <- C
                          self$current_lowest_div <- C
                          self$current_lowest_div[a_A] <- 0
                          self$special_symb_list <- '@$^#<'
                          self$bracketstages <- bracketstages
                        },
                        
                        create_and_add_header = function() {
                          C <- xml_add_child(self$tree_root, "teiHeader")
                          A <- xml_add_child(C, "fileDesc")
                          D <- xml_add_child(A, a_E)
                          self$add_pbstmt(A)
                          self$add_sourcedesc(A)
                        },
                        
                        add_standoff = function() {
                          A <- format(Sys.Date(), "%Y")
                          C <- sprintf('
        <standOff>
            <listEvent>
            <event type="print" when="%s">
            <desc/>
            </event>
            <event type="premiere" when="%s">
            <desc/>
            </event>
            <event type="written" when="%s">
            <desc/>
            </event>
            </listEvent>
            <listRelation>
            <relation name="wikidata" active="INSERT" passive="INSERT"/>
            </listRelation>
        </standOff>', A, A, A)
                          D <- read_xml(C)
                          E <- xml_find_first(D, "//standOff")
                          xml_add_child(self$tree_root, E)
                        },
                        
                        add_pbstmt = function(filedesc) {
                          A <- '
          <publicationStmt>
            <publisher xml:id="dracor">DraCor</publisher>
            <idno type="URL">https://dracor.org</idno>
            <availability>
              <licence>
                <ab>CC0 1.0</ab>
                <ref target="https://creativecommons.org/publicdomain/zero/1.0/">Licence</ref>
              </licence>
            </availability>
          </publicationStmt>'
                          B <- read_xml(A)
                          xml_add_child(filedesc, B)
                        },
                        
                        add_sourcedesc = function(filedesc) {
                          A <- '
          <sourceDesc>
            <bibl type="digitalSource">
              <name>ENTER SOURCE NAME HERE</name>
              <idno type="URL">ENTER SOURCE URL HERE</idno>
              <availability status="free">
                <p>In the public domain.</p>
              </availability>
            </bibl>
          </sourceDesc>'
                          B <- read_xml(A)
                          xml_add_child(filedesc, B)
                        },
                        
                        add_title_to_header = function(header, line) {
                          header<-xml_find_first(header,"teiHeader") #14321 /*
                          
                          B <- xml_find_first(header, a_E)
                          A <- xml_add_child(B, "title", line[6:nchar(line)])
                          xml_set_attr(A, a_B, 'main')
                        },
                        
                        add_author_to_header = function(header, line) {
                          header<-xml_find_first(header,"teiHeader/*")
                          B <- xml_find_first(header, a_E)
                          A <- xml_add_child(B, "author", line[7:nchar(line)])
                        },
                        
                        add_subtitle_to_header = function(header, line) {
                          header<-xml_find_first(header,"teiHeader/*")
                          B <- xml_find_first(header, a_E)
                          A <- xml_add_child(B, "title", line[9:nchar(line)])
                          xml_set_attr(A, a_B, 'sub')
                        },
                        
                        parse_lines = function(ezdramalines) {
                          self$lasting_comment <- FALSE
                          for (B in ezdramalines) {
                            if (startsWith(B, '@author')) {
                              self$add_author_to_header(self$tree_root, str_trim(B))
                            } else if (startsWith(B, '@title')) {
                              self$add_title_to_header(self$tree_root, str_trim(B))
                            } else if (startsWith(B, '@subtitle')) {
                              self$add_subtitle_to_header(self$tree_root, str_trim(B))
                            } else {
                              C <- substr(B, 1, 1)
                              E <- substr(B, 2, nchar(B))
                              if (C %in% strsplit(self$special_symb_list, "")[[1]]) {
                                self$handle_line_with_markup(C, E)
                              } else if (self$lasting_comment && grepl(a_K, B)) {
                                B <- gsub('(\\<\\!--|--\\>)', '', B)
                                xml_add_child(self$current_lowest_tag, B)
                                self$current_lowest_tag <- self$current_lowest_div
                                self$lasting_comment <- FALSE
                              } else {
                                xml_add_child(self$current_lowest_tag, B)
                              }
                            }
                          }
                        },
                        
                        process_file = function(path_to_file) {
                          B <- path_to_file
                          D <- readLines(B)
                          self$parse_lines_to_xml(D)
                          self$output_to_file(sub('.txt$', '.xml', B))
                        },
                        
                        parse_lines_to_xml = function(ezdramalines) {
                          self$parse_lines(ezdramalines)
                          self$post_process()
                          #B <- self$indent_dracor_style()
                          B <- self$tree_root
                          
                          self$tree_to_write <- self$add_spaces_inline_stages(B)
                        },
                        
                        handle_line_with_markup = function(first_character, rest_of_line) {
                          D <- first_character
                          B <- rest_of_line
                         # current_lw_div_sp<-xml_find_all(parser,"current_lowest_div/*")
                        #  current_lw_div_sp<-xml_find_all(parser$tree_root,"teiHeader")
                          print(xml_text(parser$current_lowest_div))
                         # FF<-xml_add_child(parser$current_lowest_div,"dum")
                        #  xml_add_child(FF,B)
                          if (D == '$') {
                            E <- xml_add_child(self$current_lowest_div, a_F)
                            xml_add_child(E, str_trim(B))
                            self$current_lowest_tag <- E
                          } else if (D == '@') {
                            F_m <- xml_add_child(self$current_lowest_div, "sp")
                           # xml_add_child(F_m, B)
                            xml_add_child(F_m, "speaker")
                            self$current_lowest_tag <- F_m
                          } else if (D == '^') {
                            front.tx<-xml_find_first(self$tree_root,"text/*")
                           #G <- xml_add_child(self$tree_root$front, a_L)
                            G <- xml_add_child(front.tx, a_L)
                            xml_add_child(G, B)
                            self$current_lowest_tag <- G
                          } else if (D == '<') {
                            if (startsWith(B, '!--')) {
                              H <- xml_add_child(self$current_lowest_div, "comment")
                              if (!grepl(a_K, B)) {
                                self$lasting_comment <- TRUE
                                self$current_lowest_tag <- H
                              }
                              xml_add_child(H, gsub('(\\<?\\!--|--\\>)', '', B))
                            } else {
                              xml_add_child(self$current_lowest_tag, B)
                            }
                          } else if (D == '#') {
                            C <- xml_add_child(self$current_lowest_div, "div")
                            I <- xml_add_child(C, "head", str_trim(gsub('#', '', B)))
                            C[a_A] <- self$get_div_level(B)
                            ###
                           # print(C)
                            #print(self$current_lowest_div[a_A])
                            #print(self$get_div_level(B))
                            print(C[a_A])
                            gr<-self$current_lowest_div[a_A]
                            #print(factor(gr))
                            print(as.double(C[a_A]) > as.double(gr))
                            print("wtf")
                            if (as.double(C[a_A]) > as.double(self$current_lowest_div[a_A])) {
                              self$current_lowest_div <- append(self$current_lowest_div, C)
                            } else if (as.double(C[a_A]) == as.double(self$current_lowest_div[a_A])) {
                                {print(self$current_lowest_div)
                                  xml_add_child(self$current_lowest_div, C)}
                              
                            #    xml_add_child(self$current_lowest_div$parent, C)}
                            } else {
                                xml_add_child(self$current_lowest_div$parent$parent, C)
                            }
                            self$current_lowest_div <- C
                            self$current_lowest_tag <- C
                          }
                        },
                        
                        add_spaces_inline_stages = function(tree_as_string) {
                          A <- tree_as_string
                          A <- gsub('</stage>([^\\s<>])', '</stage> \\1', A)
                          A <- gsub('([^\\s<>])<stage>', '\\1 <stage>', A)
                          return(A)
                        },
                        
                        get_div_level = function(line) {
                          A <- 1
                          for (B in strsplit(line, "")[[1]]) {
                            if (B == '#') {
                              A <- A + 1
                            } else {
                              break
                            }
                          }
                          return(A)
                        },
                        
                        post_process = function() {
                          D <- character()
                          self$add_cast_items()
                          cat("253\n")
                          m<-print(xml_find_first(self$tree_root, "//body")[[a_A]])
                          print(length(m))
                          if(length(m)>0)
                             xml_remove(xml_find_first(self$tree_root, "//body")[[a_A]])
                          for (C in xml_find_all(self$tree_root, "//sp")) {
                            self$post_process_sp(C)
                            if (a_J %in% xml_attrs(C)) {
                              D <- c(D, list(c(xml_attr(C, a_J), xml_text(xml_find_first(C, "speaker")))))
                            }
                          }
                          for (A in xml_find_all(self$tree_root, "//div")) {
                            print(A)
                            if (length(A[a_A]) == 0) {
                              xml_set_attr(A, "attrs", NULL)
                            } else if (length(A[a_A]) == 1) {
                              xml_set_attr(A, "attrs", NULL)
                              xml_set_attr(A, a_B, 'act')
                            } else if (length(A[a_A]) == 2) {
                              xml_set_attr(A, "attrs", NULL)
                              xml_set_attr(A, a_B, 'scene')
                            } else if (length(A[a_A]) == 3) {
                              xml_set_attr(A, "attrs", NULL)
                              xml_set_attr(A, a_B, 'subscene')
                            }
                          }
                          self$add_particdesc_to_header(D)
                          self$add_rev_desc()
                        },
                        
                        add_cast_items = function() {
                          A <- xml_find_first(self$tree_root, a_L)
                          if (!is.null(A)) {
                            F_m <- xml_text(A)
                            B <- strsplit(F_m, a_H)[[1]]
                            xml_remove(A)
                            C <- xml_add_child(A, "head", B[1])
                            for (G in B[-1]) {
                              D <- xml_add_child(A, "castItem", G)
                            }
                          }
                        },
                        
                        add_rev_desc = function() {
                          B <- sprintf('
        <revisionDesc>
             <listChange>
            <change when="%s">DESCRIBE CHANGE</change>
            </listChange>
        </revisionDesc>', format(Sys.Date(), "%Y-%m-%d"))
                          C <- read_xml(B)
                          xml_add_child(xml_find_all(self$tree_root,"teiHeader"), C)
                        },
                        
                        add_particdesc_to_header = function(set_of_char_pairs) {
                          C <- xml_add_child(xml_find_all(self$tree_root,"teiHeader"), "profileDesc")
                          D <- xml_add_child(xml_find_all(self$tree_root,"//profileDesc"), "particDesc")
                          E <- xml_add_child(xml_find_all(self$tree_root,"//particDesc"), "listPerson")
                          for (F_m in set_of_char_pairs) {
                            A <- xml_add_child(xml_find_all(self$tree_root,"//listPerson"), "person")
                            xml_set_attr(A, a_I, str_trim(gsub('#', '', F_m[1])))
                            xml_set_attr(A, "sex", self$guess_gender_stupid(xml_attr(A, a_I)))
                            G <- xml_add_child(A, "persName", F_m[2])
                          }
                        },
                        
                        handle_speaker_in_sp = function(sp, first_line) {
                          D <- first_line
                          A <- xml_add_child(sp, "speaker")
                          B <- str_match(D, '([^()]+)(\\(.+?\\))([.,:!;])?')
                          if (!is.na(B) && self$bracketstages) {
                            xml_add_child(A, str_trim(B[1]))
                            E <- xml_add_child(sp, a_F)
                            xml_add_child(E, str_trim(B[2]))
                            if (!is.na(B[3])) {
                              xml_add_child(A, str_trim(B[3]))
                            }
                          } else {
                            xml_add_child(A, str_trim(D))
                          }
                          self$transliterate_speaker_ids(sp, A)
                        },
                        
                        transliterate_speaker_ids = function(sp, speaker) {
                          B <- xml_text(speaker)
                          if (grepl('[йцукенгшщзхъфывапролджэячсмитью]', tolower(B))) {
                            A <- tolower(gsub('і', 'i', gsub('ї', 'i', gsub('є', 'e', B))))
                            A <- str_trim(A)
                          } else if (grepl('[אאַאָבבֿגדהוװוּױזחטייִײײַככּךלמםנןסעפּפֿףצץקרששׂתּת]', tolower(B))) {
                            A <- yiddish::transliterate(B)
                            A <- gsub('[\\u0591-\\u05BD\\u05C1\\u05C2\\\\u05C7]', ' ', A)
                          } else {
                            A <- tolower(gsub('і', 'i', gsub('ї', 'i', gsub('є', 'e', B))))
                            A <- str_trim(A)
                          }
                          sp[a_J] <- paste0("#", A)
                        },
                        
                        fix_starting_w_number = function(clean_who) {
                          B <- clean_who
                          A <- str_match(B, '(\\d+.*?)(_)(.+)')
                          if (!is.na(A)) {
                            B <- paste0(A[3], A[2], A[1])
                          }
                          return(B)
                        },
                        
                        clean_after_translit = function(line) {
                          B <- 'i'
                          A <- gsub('і', B, gsub('ї', B, gsub('є', 'e', gsub('ы', 'y', gsub("'", '', gsub('’', '', gsub('«', '', gsub('»', '', gsub('′', '', gsub(' ', '_', line))))))))))
                          return(A)
                        },
                        
                        handle_line_with_brackets = function(speechtext, check_inline_brackets) {
                          B <- speechtext
                          for (A in check_inline_brackets) {
                            if (nchar(A[1]) > 0) {
                              B <- append(B, A[1])
                            }
                            C <- xml_add_child(B, a_F)
                            xml_set_attr(C, a_B, 'inline')
                            xml_add_child(C, str_trim(A[2]))
                            B <- append(B, C)
                            if (nchar(A[3]) > 0) {
                              B <- append(B, A[3])
                            }
                          }
                        },
                        
                        guess_gender_stupid = function(someid) {
                          if (endsWith(someid, 'a')) {
                            return('FEMALE')
                          }
                          return('MALE')
                        },
                        
                        add_line_to_speech = function(line, sp, line_is_prose) {
                          B <- line
                          if (line_is_prose) {
                            A <- xml_add_child(sp, "p")
                          } else {
                            A <- xml_add_child(sp, "l")
                          }
                          if (nchar(B) > 0) {
                            D <- str_match_all(B, '([^()]*)(\\(.+?\\)[.,:!;]?)([^()]*)')
                            if (length(D) > 0 && self$bracketstages) {
                              self$handle_line_with_brackets(A, D)
                            } else {
                              xml_add_child(A, B)
                            }
                            xml_add_child(sp, A)
                          }
                        },
                        
                        handle_speech_in_sp = function(sp, text_split_in_lines) {
                          B <- self$is_prose
                          for (A in text_split_in_lines[-1]) {
                            if (startsWith(A, '%')) {
                              D <- xml_add_child(sp, a_F)
                              xml_add_child(D, str_trim(gsub('%', '', A)))
                            } else if (startsWith(A, '~')) {
                              B <- !B
                              A <- str_trim(gsub('~', '', A))
                              self$add_line_to_speech(A, sp, B)
                            } else {
                              self$add_line_to_speech(A, sp, B)
                            }
                          }
                        },
                        
                        post_process_sp = function(sp) {
                          C <- xml_text(sp)
                          xml_remove(sp)
                          B <- strsplit(C, a_H)[[1]]
                          D <- B[1]
                          self$handle_speaker_in_sp(sp, D)
                          self$handle_speech_in_sp(sp, B)
                        },
                        
                        indent_dracor_style = function() {
                          C <- '\\1\\2'
                          #A <- xml_pretty(self$tree_root)
                          A <- self$tree_root
                          
                          A <- gsub('(<[^/]+?>)\\n\\s+([^<>\\s])', C, A)
                          A <- gsub('([^<>\\s])\\n\\s+(</.+?>)', C, A)
                          A <- gsub('(<speaker>)([^<>]+)\\s*\\n\\s*([^<>]+)(</speaker>)', '\\1\\2\\3\\4', A)
                          A <- gsub('([\\n\\s]+)(<stage type="inline">)([^<>]+)(</stage>)([\\n\\s]+)', '<stage>\\3\\4', A)
                          B <- list()
                          for (E in strsplit(A, a_H)[[1]]) {
                            F_m <- gsub('^( +)', '\\1\\1', E)
                            B <- append(B, F_m)
                          }
                          A <- paste(B, collapse = a_H)
                          AAA<-read_xml(A) # ohne
                          return(AAA) # A
                        },
                        
                        output_to_file = function(newfilepath) {
                          B <- newfilepath
                          writeLines(self$tree_to_write, B)
                          self$outputname <- B
                        }
                      )
)

parser <- Parser$new()
parser$process_file('sample.txt')
#parser$output_to_file("sampleR.xml")

#writeLines(parser$tree_to_write,"sampleR.xml")

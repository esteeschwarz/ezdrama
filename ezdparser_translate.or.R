library(xml2)
library(stringr)
library(rvest)

_L <- 'castList'
_K <- '-->\\s*$'
_J <- 'who'
_I <- 'xml:id'
_H <- '\n'
_G <- '.,:!; '
_F <- 'stage'
_E <- 'titleStmt'
_D <- TRUE
_C <- 'xml'
_B <- 'type'
_A <- 'level'

Parser <- R6::R6Class("Parser",
                      public = list(
                        tree_root = NULL,
                        is_prose = NULL,
                        current_lowest_tag = NULL,
                        current_lowest_div = NULL,
                        lasting_comment = NULL,
                        special_symb_list = NULL,
                        bracketstages = NULL,
                        
                        initialize = function(bracketstages = .D, is_prose = .D, dracor_id = 'insert_id', dracor_lang = 'insert_lang') {
                          self$tree_root <- xml_new_root("TEI", ns = "http://www.tei-c.org/ns/1.0")
                          xml_set_attr(self$tree_root, .I, dracor_id)
                          xml_set_attr(self$tree_root, "xml:lang", dracor_lang)
                          self$create_and_add_header()
                          self$add_standoff()
                          B <- xml_add_child(self$tree_root, "text")
                          D <- xml_add_child(B, "front")
                          C <- xml_add_child(B, "body")
                          self$is_prose <- is_prose
                          xml_add_child(B, D)
                          xml_add_child(B, C)
                          self$current_lowest_tag <- C
                          self$current_lowest_div <- C
                          xml_set_attr(self$current_lowest_div, .A, 0)
                          self$special_symb_list <- '@$^#<'
                          self$bracketstages <- bracketstages
                        },
                        
                        create_and_add_header = function() {
                          C <- xml_add_child(self$tree_root, "teiHeader")
                          A <- xml_add_child(C, "fileDesc")
                          D <- xml_add_child(A, .E)
                          self$add_pbstmt(A)
                          self$add_sourcedesc(A)
                          xml_add_child(C, A)
                          xml_add_child(self$tree_root, C)
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
                          C <- xml_find_first(B, "//publicationStmt")
                          xml_add_child(filedesc, C)
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
                          C <- xml_find_first(B, "//sourceDesc")
                          xml_add_child(filedesc, C)
                        },
                        
                        add_title_to_header = function(header, line) {
                          B <- xml_find_first(header, .E)
                          A <- xml_add_child(B, "title")
                          xml_set_attr(A, .B, 'main')
                          xml_add_child(A, str_trim(substr(line, 7, nchar(line))))
                        },
                        
                        add_author_to_header = function(header, line) {
                          B <- xml_find_first(header, .E)
                          A <- xml_add_child(B, "author")
                          xml_add_child(A, str_trim(substr(line, 8, nchar(line))))
                        },
                        
                        add_subtitle_to_header = function(header, line) {
                          B <- xml_find_first(header, .E)
                          A <- xml_add_child(B, "title")
                          xml_set_attr(A, .B, 'sub')
                          xml_add_child(A, str_trim(substr(line, 10, nchar(line))))
                        },
                        
                        parse_lines = function(ezdramalines) {
                          self$lasting_comment <- FALSE
                          for (B in ezdramalines) {
                            if (startsWith(B, '@author')) {
                              self$add_author_to_header(self$tree_root$teiHeader, str_trim(B))
                            } else if (startsWith(B, '@title')) {
                              self$add_title_to_header(self$tree_root$teiHeader, str_trim(B))
                            } else if (startsWith(B, '@subtitle')) {
                              self$add_subtitle_to_header(self$tree_root$teiHeader, str_trim(B))
                            } else {
                              C <- substr(B, 1, 1)
                              E <- substr(B, 2, nchar(B))
                              if (C %in% strsplit(self$special_symb_list, "")[[1]]) {
                                self$handle_line_with_markup(C, E)
                              } else if (self$lasting_comment && grepl(.K, B)) {
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
                          B <- self$indent_dracor_style()
                          self$tree_to_write <- self$add_spaces_inline_stages(B)
                        },
                        
                        handle_line_with_markup = function(first_character, rest_of_line) {
                          D <- first_character
                          B <- rest_of_line
                          if (D == '$') {
                            E <- xml_add_child(self$current_lowest_div, "stage")
                            xml_add_child(E, str_trim(B))
                            self$current_lowest_tag <- E
                          } else if (D == '@') {
                            F <- xml_add_child(self$current_lowest_div, "sp")
                            xml_add_child(F, B)
                            self$current_lowest_tag <- F
                          } else if (D == '^') {
                            G <- xml_add_child(self$tree_root$front, .L)
                            xml_add_child(G, B)
                            self$current_lowest_tag <- G
                          } else if (D == '<') {
                            if (startsWith(B, '!--')) {
                              H <- xml_add_child(self$current_lowest_div, "comment")
                              if (!grepl(.K, B)) {
                                self$lasting_comment <- TRUE
                                self$current_lowest_tag <- H
                              }
                              xml_add_child(H, gsub('(\\<?\\!--|--\\>)', '', B))
                            } else {
                              xml_add_child(self$current_lowest_tag, B)
                            }
                          } else if (D == '#') {
                            C <- xml_add_child(self$current_lowest_div, "div")
                            I <- xml_add_child(C, "head")
                            xml_add_child(I, str_trim(substring(B, 2)))
                            xml_set_attr(C, .A, self$get_div_level(B))
                            if (xml_attr(C, .A) > xml_attr(self$current_lowest_div, .A)) {
                              xml_add_child(self$current_lowest_div, C)
                            } else if (xml_attr(C, .A) == xml_attr(self$current_lowest_div, .A)) {
                              xml_add_child(xml_parent(self$current_lowest_div), C)
                            } else {
                              xml_add_child(xml_parent(xml_parent(self$current_lowest_div)), C)
                            }
                            self$current_lowest_div <- C
                            self$current_lowest_tag <- C
                          }
                        },
                        
                        add_spaces_inline_stages = function(tree_as_string) {
                          A <- gsub('</stage>([^\\s<>])', '</stage> \\1', tree_as_string)
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
                          D <- set()
                          self$add_cast_items()
                          xml_remove(xml_find_first(self$tree_root, "//body")[[.A]])
                          for (C in xml_find_all(self$tree_root, "//sp")) {
                            self$post_process_sp(C)
                            if (.J %in% xml_attrs(C)) {
                              D <- union(D, list(c(xml_attr(C, .J), str_trim(xml_text(xml_find_first(C, "speaker"))))))
                            }
                          }
                          for (A in xml_find_all(self$tree_root, "//div")) {
                            if (xml_attr(A, .A) == 0) {
                              xml_set_attr(A, .A, NULL)
                            } else if (xml_attr(A, .A) == 1) {
                              xml_set_attr(A, .A, NULL)
                              xml_set_attr(A, .B, 'act')
                            } else if (xml_attr(A, .A) == 2) {
                              xml_set_attr(A, .A, NULL)
                              xml_set_attr(A, .B, 'scene')
                            } else if (xml_attr(A, .A) == 3) {
                              xml_set_attr(A, .A, NULL)
                              xml_set_attr(A, .B, 'subscene')
                            }
                          }
                          self$add_particdesc_to_header(D)
                          self$add_rev_desc()
                        },
                        
                        add_cast_items = function() {
                          A <- xml_find_first(self$tree_root, .L)
                          if (!is.null(A)) {
                            F <- xml_text(A)
                            B <- strsplit(F, .H)[[1]]
                            xml_remove(A)
                            C <- xml_add_child(A, "head")
                            xml_add_child(C, B[1])
                            for (G in B[-1]) {
                              D <- xml_add_child(A, "castItem")
                              xml_add_child(D, G)
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
                          D <- xml_find_first(C, "//revisionDesc")
                          xml_add_child(self$tree_root$teiHeader, D)
                        },
                        
                        add_particdesc_to_header = function(set_of_char_pairs) {
                          C <- xml_add_child(self$tree_root$teiHeader, "profileDesc")
                          D <- xml_add_child(C, "particDesc")
                          E <- xml_add_child(D, "listPerson")
                          for (F in set_of_char_pairs) {
                            A <- xml_add_child(E, "person")
                            xml_set_attr(A, .I, str_trim(substring(F[1], 2)))
                            xml_set_attr(A, "sex", self$guess_gender_stupid(xml_attr(A, .I)))
                            G <- xml_add_child(A, "persName")
                            xml_add_child(G, F[2])
                          }
                          H <- self$tree_root$teiHeader
                          xml_add_child(H, C)
                        },
                        
                        handle_speaker_in_sp = function(sp, first_line) {
                          D <- first_line
                          A <- xml_add_child(sp, "speaker")
                          B <- str_match(D, '([^()]+)(\\(.+?\\))([.,:!;])?')
                          if (!is.na(B) && self$bracketstages) {
                            xml_add_child(A, str_trim(B[1]))
                            E <- xml_add_child(sp, "stage")
                            xml_add_child(E, str_trim(B[2]))
                            xml_add_child(A, B[3])
                          } else {
                            xml_add_child(A, str_trim(D))
                          }
                          self$transliterate_speaker_ids(sp, A)
                        },
                        
                        transliterate_speaker_ids = function(sp, speaker) {
                          B <- xml_text(speaker)
                          if (grepl('[йцукенгшщзхъфывапролджэячсмитью]', tolower(B))) {
                            A <- tolower(CleanAfterTranslit(translit(B, 'uk', reversed = .D)))
                            A <- str_trim(A)
                          } else if (grepl('[אאַאָבבֿגדהוװוּױזחטייִײײַככּךלמםנןסעפּפֿףצץקרששׂתּת]', tolower(B))) {
                            A <- yiddish::transliterate(B)
                            A <- gsub('[\\u0591-\\u05BD\\u05C1\\u05C2\\\\u05C7]', ' ', A)
                          } else {
                            A <- tolower(str_trim(B))
                            A <- CleanAfterTranslit(A)
                          }
                          xml_set_attr(sp, .J, paste0("#", A))
                        },
                        
                        fix_starting_w_number = function(clean_who) {
                          B <- clean_who
                          A <- str_match(B, '(\\d+.*?)(_)(.+)')
                          if (!is.na(A)) {
                            B <- paste0(A[3], A[2], A[1])
                          }
                          return(B)
                        },
                        
                        CleanAfterTranslit = function(line) {
                          B <- 'i'
                          A <- line
                          A <- gsub('і', B, A)
                          A <- gsub('ї', B, A)
                          A <- gsub('і', B, A)
                          A <- gsub('є', 'e', A)
                          A <- gsub('є', 'e', A)
                          A <- gsub('ы', 'y', A)
                          A <- gsub("'", '', A)
                          A <- gsub('’', '', A)
                          A <- gsub('«', '', A)
                          A <- gsub('»', '', A)
                          A <- gsub('′', '', A)
                          A <- gsub(' ', '_', A)
                          return(A)
                        },
                        
                        handle_line_with_brackets = function(speechtext, check_inline_brackets) {
                          B <- speechtext
                          for (A in check_inline_brackets) {
                            if (nchar(A[1]) > 0) {
                              B <- c(B, A[1])
                            }
                            C <- xml_add_child(B, "stage")
                            xml_set_attr(C, .B, 'inline')
                            xml_add_child(C, str_trim(A[2]))
                            B <- c(B, C)
                            if (nchar(A[3]) > 0) {
                              B <- c(B, A[3])
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
                              D <- xml_add_child(sp, "stage")
                              xml_add_child(D, str_trim(substring(A, 2)))
                            } else if (startsWith(A, '~')) {
                              B <- !B
                              A <- str_trim(substring(A, 2))
                              self$add_line_to_speech(A, sp, B)
                            } else {
                              self$add_line_to_speech(A, sp, B)
                            }
                          }
                        },
                        
                        post_process_sp = function(sp) {
                          C <- xml_text(sp)
                          xml_remove(sp)
                          B <- strsplit(C, .H)[[1]]
                          D <- B[1]
                          self$handle_speaker_in_sp(sp, D)
                          self$handle_speech_in_sp(sp, B)
                        },
                        
                        indent_dracor_style = function() {
                          C <- '\\1\\2'
                          A <- xml_pretty(self$tree_root)
                          A <- gsub('(<[^/]+?>)\\n\\s+([^<>\\s])', C, A)
                          A <- gsub('([^<>\\s])\\n\\s+(</.+?>)', C, A)
                          A <- gsub('(<speaker>)([^<>]+)\\s*\\n\\s*([^<>]+)(</speaker>)', '\\1\\2\\3\\4', A)
                          A <- gsub('([\\n\\s]+)(<stage type="inline">)([^<>]+)(</stage>)([\\n\\s]+)', '<stage>\\3\\4', A)
                          B <- list()
                          for (E in strsplit(A, .H)[[1]]) {
                            F <- gsub('^( +)', '\\1\\1', E)
                            B <- c(B, F)
                          }
                          A <- paste(B, collapse = .H)
                          read_xml(A)
                          return(A)
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



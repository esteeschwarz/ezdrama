extern crate regex;
extern crate chrono;
extern crate yiddish;
extern crate soup;

use regex::Regex;
use chrono::prelude::*;
use soup::{Tag, Node};

struct Parser {
    tree_root: Tag,
    is_prose: bool,
    current_lowest_tag: Tag,
    current_lowest_div: Tag,
    lasting_comment: bool,
    special_symb_list: String,
    bracketstages: bool,
}

impl Parser {
    fn new(bracketstages: bool, is_prose: bool, dracor_id: &str, dracor_lang: &str) -> Self {
        let mut tree_root = Tag::new("TEI");
        tree_root.set_attr("xmlns", "http://www.tei-c.org/ns/1.0");
        tree_root.set_attr("xml:id", dracor_id);
        tree_root.set_attr("xml:lang", dracor_lang);
        Self::create_and_add_header(&mut tree_root);
        Self::add_standoff(&mut tree_root);
        let mut text = Tag::new("text");
        let front = Tag::new("front");
        let body = Tag::new("body");
        text.append(front.clone());
        text.append(body.clone());
        tree_root.append(text);
        Self {
            tree_root,
            is_prose,
            current_lowest_tag: body,
            current_lowest_div: body,
            lasting_comment: false,
            special_symb_list: String::from("@$^#<"),
            bracketstages,
        }
    }

    fn create_and_add_header(tree_root: &mut Tag) {
        let mut tei_header = Tag::new("teiHeader");
        let mut file_desc = Tag::new("fileDesc");
        let title_stmt = Tag::new("titleStmt");
        file_desc.append(title_stmt);
        Self::add_pbstmt(&mut file_desc);
        Self::add_sourcedesc(&mut file_desc);
        tei_header.append(file_desc);
        tree_root.append(tei_header);
    }

    fn add_standoff(tree_root: &mut Tag) {
        let year = Utc::now().format("%Y").to_string();
        let standoff = format!(r#"
        <standOff>
            <listEvent>
            <event type="print" when="{}">
            <desc/>
            </event>
            <event type="premiere" when="{}">
            <desc/>
            </event>
            <event type="written" when="{}">
            <desc/>
            </event>
            </listEvent>
            <listRelation>
            <relation name="wikidata" active="INSERT" passive="INSERT"/>
            </listRelation>
        </standOff>
        "#, year, year, year);
        let soup = soup::parse(&standoff);
        let stand_off = soup.find("standOff").unwrap();
        tree_root.append(stand_off);
    }

    fn add_pbstmt(file_desc: &mut Tag) {
        let publication_stmt = r#"
          <publicationStmt>
            <publisher xml:id="dracor">DraCor</publisher>
            <idno type="URL">https://dracor.org</idno>
            <availability>
              <licence>
                <ab>CC0 1.0</ab>
                <ref target="https://creativecommons.org/publicdomain/zero/1.0/">Licence</ref>
              </licence>
            </availability>
          </publicationStmt>
        "#;
        let soup = soup::parse(publication_stmt);
        let pub_stmt = soup.find("publicationStmt").unwrap();
        file_desc.append(pub_stmt);
    }

    fn add_sourcedesc(file_desc: &mut Tag) {
        let source_desc = r#"
          <sourceDesc>
            <bibl type="digitalSource">
              <name>ENTER SOURCE NAME HERE</name>
              <idno type="URL">ENTER SOURCE URL HERE</idno>
              <availability status="free">
                <p>In the public domain.</p>
              </availability>
            </bibl>
          </sourceDesc>
        "#;
        let soup = soup::parse(source_desc);
        let src_desc = soup.find("sourceDesc").unwrap();
        file_desc.append(src_desc);
    }

    fn parse_lines(&mut self, ezdramalines: Vec<String>) {
        self.lasting_comment = false;
        for line in ezdramalines {
            if line.starts_with("@author") {
                self.add_author_to_header(&line);
            } else if line.starts_with("@title") {
                self.add_title_to_header(&line);
            } else if line.starts_with("@subtitle") {
                self.add_subtitle_to_header(&line);
            } else {
                let first_char = line.chars().next().unwrap();
                let rest_of_line = &line[1..];
                if self.special_symb_list.contains(first_char) {
                    self.handle_line_with_markup(first_char, rest_of_line);
                } else if self.lasting_comment && Regex::new(r"-->\\s*$").unwrap().is_match(&line) {
                    let cleaned_line = Regex::new(r"(\\<\\!--|--\\>)").unwrap().replace_all(&line, "").to_string();
                    self.current_lowest_tag.append(cleaned_line);
                    self.current_lowest_tag = self.current_lowest_div.clone();
                    self.lasting_comment = false;
                } else {
                    self.current_lowest_tag.append(line);
                }
            }
        }
    }

    fn process_file(&mut self, path_to_file: &str) {
        let lines = std::fs::read_to_string(path_to_file).expect("Unable to read file");
        let ezdramalines: Vec<String> = lines.lines().map(|s| s.to_string()).collect();
        self.parse_lines_to_xml(ezdramalines);
        self.output_to_file(&path_to_file.replace(".txt", ".xml"));
    }

    fn parse_lines_to_xml(&mut self, ezdramalines: Vec<String>) {
        self.parse_lines(ezdramalines);
        self.post_process();
        let indented = self.indent_dracor_style();
        self.tree_to_write = self.add_spaces_inline_stages(indented);
    }

    fn handle_line_with_markup(&mut self, first_character: char, rest_of_line: &str) {
        match first_character {
            '$' => {
                let mut stage = Tag::new("stage");
                stage.append(rest_of_line.trim());
                self.current_lowest_div.append(stage);
                self.current_lowest_tag = stage;
            }
            '@' => {
                let mut sp = Tag::new("sp");
                sp.append(rest_of_line);
                self.current_lowest_div.append(sp);
                self.current_lowest_tag = sp;
            }
            '^' => {
                let mut cast_list = Tag::new("castList");
                cast_list.append(rest_of_line);
                self.tree_root.find("front").unwrap().append(cast_list);
                self.current_lowest_tag = cast_list;
            }
            '<' => {
                if rest_of_line.starts_with("!--") {
                    let mut comment = Tag::new("comment");
                    self.current_lowest_div.append(comment);
                    if !Regex::new(r"-->\\s*$").unwrap().is_match(rest_of_line) {
                        self.lasting_comment = true;
                        self.current_lowest_tag = comment;
                    }
                    comment.append(Regex::new(r"(\\<?\\!--|--\\>)").unwrap().replace_all(rest_of_line, "").to_string());
                } else {
                    self.current_lowest_tag.append(rest_of_line);
                }
            }
            '#' => {
                let mut div = Tag::new("div");
                let mut head = Tag::new("head");
                head.append(rest_of_line.trim_start_matches('#'));
                div.set_attr("level", &self.get_div_level(rest_of_line));
                div.append(head);
                if div.get_attr("level").unwrap() > self.current_lowest_div.get_attr("level").unwrap() {
                    self.current_lowest_div.append(div);
                } else if div.get_attr("level").unwrap() == self.current_lowest_div.get_attr("level").unwrap() {
                    self.current_lowest_div.parent().unwrap().append(div);
                } else {
                    self.current_lowest_div.parent().unwrap().parent().unwrap().append(div);
                }
                self.current_lowest_div = div;
                self.current_lowest_tag = div;
            }
            _ => {}
        }
    }

    fn add_spaces_inline_stages(&self, tree_as_string: String) -> String {
        let mut result = Regex::new(r"</stage>([^\\s<>])").unwrap().replace_all(&tree_as_string, "</stage> $1").to_string();
        result = Regex::new(r"([^\\s<>])<stage>").unwrap().replace_all(&result, "$1 <stage>").to_string();
        result
    }

    fn get_div_level(&self, line: &str) -> usize {
        let mut level = 1;
        for ch in line.chars() {
            if ch == '#' {
                level += 1;
            } else {
                break;
            }
        }
        level
    }

    fn post_process(&mut self) {
        let mut set = std::collections::HashSet::new();
        self.add_cast_items();
        self.tree_root.find("body").unwrap().remove_attr("level");
        for sp in self.tree_root.find_all("sp") {
            self.post_process_sp(sp);
            if let Some(speaker) = sp.get_attr("who") {
                set.insert((speaker, sp.find("speaker").unwrap().text().trim().to_string()));
            }
        }
        for div in self.tree_root.find_all("div") {
            match div.get_attr("level").unwrap().parse::<usize>().unwrap() {
                0 => div.remove_attr("level"),
                1 => {
                    div.remove_attr("level");
                    div.set_attr("type", "act");
                }
                2 => {
                    div.remove_attr("level");
                    div.set_attr("type", "scene");
                }
                3 => {
                    div.remove_attr("level");
                    div.set_attr("type", "subscene");
                }
                _ => {}
            }
        }
        self.add_particdesc_to_header(set);
        self.add_rev_desc();
    }

    fn add_cast_items(&mut self) {
        if let Some(cast_list) = self.tree_root.find("castList") {
            let text = cast_list.text();
            let items: Vec<&str> = text.split('\n').collect();
            cast_list.clear();
            let mut head = Tag::new("head");
            head.append(items[0]);
            cast_list.append(head);
            for item in &items[1..] {
                let mut cast_item = Tag::new("castItem");
                cast_item.append(item);
                cast_list.append(cast_item);
            }
        }
    }

    fn add_rev_desc(&mut self) {
        let revision_desc = format!(r#"
        <revisionDesc>
             <listChange>
            <change when="{}">DESCRIBE CHANGE</change>
            </listChange>
        </revisionDesc>"#, Utc::now().format("%Y-%m-%d"));
        let soup = soup::parse(&revision_desc);
        let rev_desc = soup.find("revisionDesc").unwrap();
        self.tree_root.find("teiHeader").unwrap().append(rev_desc);
    }

    fn add_particdesc_to_header(&mut self, set_of_char_pairs: std::collections::HashSet<(String, String)>) {
        let mut profile_desc = Tag::new("profileDesc");
        let mut partic_desc = Tag::new("particDesc");
        profile_desc.append(partic_desc);
        let mut list_person = Tag::new("listPerson");
        partic_desc.append(list_person);
        for (id, name) in set_of_char_pairs {
            let mut person = Tag::new("person");
            person.set_attr("xml:id", id.trim_start_matches('#'));
            person.set_attr("sex", self.guess_gender_stupid(&person));
            let mut pers_name = Tag::new("persName");
            pers_name.append(name);
            person.append(pers_name);
            list_person.append(person);
        }
        self.tree_root.find("teiHeader").unwrap().append(profile_desc);
    }

    fn handle_speaker_in_sp(&mut self, sp: &mut Tag, first_line: &str) {
        let mut speaker = Tag::new("speaker");
        sp.append(speaker);
        let re = Regex::new(r"([^()]+)(\\(.+?\\))([.,:!;])?").unwrap();
        if let Some(caps) = re.captures(first_line) {
            speaker.append(caps[1].trim());
            let mut stage = Tag::new("stage");
            stage.append(caps[2].trim());
            sp.append(stage);
            if let Some(punct) = caps.get(4) {
                speaker.append(punct.as_str().trim());
            }
        } else {
            speaker.append(first_line.trim());
        }
        self.transliterate_speaker_ids(sp, speaker);
    }

    fn transliterate_speaker_ids(&self, sp: &mut Tag, speaker: Tag) {
        let text = speaker.text();
        let mut transliterated = String::new();
        if Regex::new(r"[йцукенгшщзхъфывапролджэячсмитью]").unwrap().is_match(&text.to_lowercase()) {
            transliterated = self.clean_after_translit(translit(&text.trim_end_matches('.'), "uk", true)).to_lowercase();
        } else if Regex::new(r"[אאַאָבבֿגדהוװוּױזחטייִײײַככּךלמםנןסעפּפֿףצץקרששׂתּת]").unwrap().is_match(&text.to_lowercase()) {
            transliterated = yiddish::transliterate(&text.trim());
            transliterated = Regex::new(r"[\\u0591-\\u05BD\\u05C1\\u05C2\\\\u05C7]").unwrap().replace_all(&transliterated, " ").to_string();
        } else {
            transliterated = text.trim().to_lowercase();
        }
        transliterated = self.fix_starting_w_number(transliterated);
        sp.set_attr("who", format!("#{}", transliterated));
    }

    fn fix_starting_w_number(&self, clean_who: String) -> String {
        let re = Regex::new(r"(\d+.*?)(_)(.+)").unwrap();
        if let Some(caps) = re.captures(&clean_who) {
            format!("{}{}{}", &caps[3], &caps[2], &caps[1])
        } else {
            clean_who
        }
    }

    fn clean_after_translit(&self, line: String) -> String {
        let mut cleaned = line;
        cleaned = cleaned.replace('і', 'i');
        cleaned = cleaned.replace('ї', 'i');
        cleaned = cleaned.replace('є', 'e');
        cleaned = cleaned.replace('ы', 'y');
        cleaned = cleaned.replace("'", "");
        cleaned = cleaned.replace('’', "");
        cleaned = cleaned.replace('«', "");
        cleaned = cleaned.replace('»', "");
        cleaned = cleaned.replace('′', "");
        cleaned = cleaned.replace(' ', "_");
        cleaned
    }

    fn handle_line_with_brackets(&mut self, speechtext: &mut Vec<Tag>, check_inline_brackets: Vec<(String, String, String)>) {
        let mut speech = speechtext.clone();
        for (before, content, after) in check_inline_brackets {
            if !before.is_empty() {
                speech.push(Tag::new(before));
            }
            let mut inline = Tag::new("stage");
            inline.set_attr("type", "inline");
            inline.append(content.trim());
            speech.push(inline);
            if !after.is_empty() {
                speech.push(Tag::new(after));
            }
        }
    }

    fn guess_gender_stupid(&self, someid: &str) -> String {
        if someid.ends_with('a') {
            "FEMALE".to_string()
        } else {
            "MALE".to_string()
        }
    }

    fn add_line_to_speech(&mut self, line: &str, sp: &mut Tag, line_is_prose: bool) {
        let mut line_tag = if line_is_prose {
            Tag::new("p")
        } else {
            Tag::new("l")
        };
        if !line.is_empty() {
            let re = Regex::new(r"([^()]*)(\\(.+?\\)[.,:!;]?)([^()]*)").unwrap();
            if let Some(caps) = re.captures(line) {
                self.handle_line_with_brackets(&mut line_tag, vec![(caps[1].to_string(), caps[2].to_string(), caps[4].to_string())]);
            } else {
                line_tag.append(line);
            }
            sp.append(line_tag);
        }
    }

    fn handle_speech_in_sp(&mut self, sp: &mut Tag, text_split_in_lines: Vec<String>) {
        let mut is_prose = self.is_prose;
        for line in &text_split_in_lines[1..] {
            if line.starts_with('%') {
                let mut stage = Tag::new("stage");
                stage.append(line.trim_start_matches('%'));
                sp.append(stage);
            } else if line.starts_with('~') {
                is_prose = !is_prose;
                let line = line.trim_start_matches('~');
                self.add_line_to_speech(line, sp, is_prose);
            } else {
                self.add_line_to_speech(line, sp, is_prose);
            }
        }
    }

    fn post_process_sp(&mut self, sp: &mut Tag) {
        let text = sp.text();
        sp.clear();
        let lines: Vec<&str> = text.split('\n').collect();
        let first_line = lines[0];
        self.handle_speaker_in_sp(sp, first_line);
        self.handle_speech_in_sp(sp, lines);
    }

    fn indent_dracor_style(&self) -> String {
        let mut result = self.tree_root.prettify();
        result = Regex::new(r"(<[^/]+?>)\\n\\s+([^<>\\s])").unwrap().replace_all(&result, "$1$2").to_string();
        result = Regex::new(r"([^<>\\s])\\n\\s+(</.+?>)").unwrap().replace_all(&result, "$1$2").to_string();
        result
    }

    fn output_to_file(&self, newfilepath: &str) {
        std::fs::write(newfilepath, self.tree_to_write.clone()).expect("Unable to write file");
    }
}

fn main() {
    let mut parser = Parser::new(true, true, "insert_id", "insert_lang");
    parser.process_file("sample.txt");
}



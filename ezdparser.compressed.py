'\nThis file contains the Parser engine that can parse the EzDrama format to TEI/XML\nSee https://github.com/dracor-org/ezdrama for more details\nUsage example in the ezparser.ipynb notebook: \nhttps://github.com/dracor-org/ezdrama/blob/main/ezdramaparser.ipynb\n'
a_L='castList'
a_K='-->\\s*$'
a_J='who'
a_I='xml:id'
a_H='\n'
a_G='.,:!; '
a_F='stage'
a_E='titleStmt'
a_D=True
a_C='xml'
a_B='type'
a_A='level'
import re
from datetime import datetime
from transliterate import translit
import yiddish
from bs4 import BeautifulSoup,Tag
class Parser:
	"This is the main class, the EzDrama to TEI/XML parser\n    It generates an empty TEI/XML tree upon initalization\n    And then using the '.parse_file' method one can parse a txt file \n    (providing the path to file as argument)\n\n    Or using the lower-level '.parse_lines_to_xml' method one can parse \n    a list of ezdrama lines (providing the list of strings as argument)"
	def __init__(A,bracketstages=a_D,is_prose=a_D,dracor_id='insert_id',dracor_lang='insert_lang'):A.tree_root=Tag(name='TEI');A.tree_root['xmlns']='http://www.tei-c.org/ns/1.0';A.tree_root[a_I]=dracor_id;A.tree_root['xml:lang']=dracor_lang;A.__create_and_add_header();A.__add_standoff();B=Tag(name='text');D=Tag(name='front');C=Tag(name='body');B.append(D);B.append(C);A.is_prose=is_prose;A.tree_root.append(B);A.current_lowest_tag=C;A.current_lowest_div=C;A.current_lowest_div[a_A]=0;A.special_symb_list='@$^#<';A.bracketstages=bracketstages
	def __create_and_add_header(B):C=Tag(name='teiHeader');A=Tag(name='fileDesc');D=Tag(name=a_E);A.append(D);B.__add_pbstmt(A);B.__add_sourcedesc(A);C.append(A);B.tree_root.append(C)
	def __add_standoff(B):A=datetime.today().strftime('%Y');C=f'''
        <standOff>
            <listEvent>
            <event type="print" when="{A}">
            <desc/>
            </event>
            <event type="premiere" when="{A}">
            <desc/>
            </event>
            <event type="written" when="{A}">
            <desc/>
            </event>
            </listEvent>
            <listRelation>
            <relation name="wikidata" active="INSERT" passive="INSERT"/>
            </listRelation>
        </standOff>
        ''';D=BeautifulSoup(C,a_C);E=D.standOff;B.tree_root.append(E)
	def __add_pbstmt(D,filedesc):A='\n          <publicationStmt>\n            <publisher xml:id="dracor">DraCor</publisher>\n            <idno type="URL">https://dracor.org</idno>\n            <availability>\n              <licence>\n                <ab>CC0 1.0</ab>\n                <ref target="https://creativecommons.org/publicdomain/zero/1.0/">Licence</ref>\n              </licence>\n            </availability>\n          </publicationStmt>\n        ';B=BeautifulSoup(A,a_C);C=B.publicationStmt;filedesc.append(C)
	def __add_sourcedesc(D,filedesc):A='\n          <sourceDesc>\n            <bibl type="digitalSource">\n              <name>ENTER SOURCE NAME HERE</name>\n              <idno type="URL">ENTER SOURCE URL HERE</idno>\n              <availability status="free">\n                <p>In the public domain.</p>\n              </availability>\n            </bibl>\n          </sourceDesc>\n        ';B=BeautifulSoup(A,a_C);C=B.sourceDesc;filedesc.append(C)
	def __add_title_to_header(C,header,line):B=header.find(a_E);A=Tag(name='title');A[a_B]='main';A.append(line[6:].strip());B.append(A)
	def __add_author_to_header(C,header,line):B=header.find(a_E);A=Tag(name='author');A.append(line[7:].strip());B.append(A)
	def __add_subtitle_to_header(C,header,line):B=header.find(a_E);A=Tag(name='title');A[a_B]='sub';A.append(line[9:].strip());B.append(A)
	def __parse_lines(A,ezdramalines):
		D=False;A.lasting_comment=D
		for B in ezdramalines:
			if B.startswith('@author'):A.__add_author_to_header(A.tree_root.teiHeader,B.strip())
			elif B.startswith('@title'):A.__add_title_to_header(A.tree_root.teiHeader,B.strip())
			elif B.startswith('@subtitle'):A.__add_subtitle_to_header(A.tree_root.teiHeader,B.strip())
			else:
				C=B[:1];E=B[1:]
				if C in A.special_symb_list:A.__handle_line_with_markup(C,E)
				elif A.lasting_comment and re.search(a_K,B):B=re.sub('(\\<\\!--|--\\>)','',B);A.current_lowest_tag.append(B);A.current_lowest_tag=A.current_lowest_div;A.lasting_comment=D
				else:A.current_lowest_tag.append(B)
	def process_file(A,path_to_file):
		B=path_to_file
		with open(B)as C:D=C.readlines()
		A.parse_lines_to_xml(D);A.output_to_file(B.replace('.txt','.xml'))
	def parse_lines_to_xml(A,ezdramalines):'this method takes list of lines \n        containing a whole play \n        in ezdrama format (see sample \n        in the README: https://github.com/dracor-org/ezdrama)';A.__parse_lines(ezdramalines);A.__post_process();B=A.__indent_dracor_style();A.tree_to_write=A.__add_spaces_inline_stages(B)
	def __handle_line_with_markup(A,first_character,rest_of_line):
		' processes a line with specific ezdrama markup symbol at the start\n        writes it into current lowest tag or current lowest div\n        updates current lowest tag/div';D=first_character;B=rest_of_line
		if D=='$':E=Tag(name=a_F);E.append(B.strip());A.current_lowest_div.append(E);A.current_lowest_tag=E
		elif D=='@':F=Tag(name='sp');F.append(B);A.current_lowest_div.append(F);A.current_lowest_tag=F
		elif D=='^':G=Tag(name=a_L);G.append(B);A.tree_root.front.append(G);A.current_lowest_tag=G
		elif D=='<':
			if B.startswith('!--'):
				H=Tag(name='comment');A.current_lowest_div.append(H)
				if not re.search(a_K,B):A.lasting_comment=a_D;A.current_lowest_tag=H
				H.append(re.sub('(\\<?\\!--|--\\>)','',B))
			else:A.current_lowest_tag.append(B)
		elif D=='#':
			C=Tag(name='div');I=Tag(name='head');I.append(B.strip('#'));C[a_A]=A.__get_div_level(B);C.append(I)
			if C[a_A]>A.current_lowest_div[a_A]:A.current_lowest_div.append(C)
			elif C[a_A]==A.current_lowest_div[a_A]:A.current_lowest_div.parent.append(C)
			else:A.current_lowest_div.parent.parent.append(C)
			A.current_lowest_div=C;A.current_lowest_tag=C
	def __add_spaces_inline_stages(B,tree_as_string):'some technical fix which was at some point \n        asked for by the draCor maintainter AFAIR';A=tree_as_string;A=re.sub('</stage>([^\\s<>])','</stage> \\1',A);A=re.sub('([^\\s<>])<stage>','\\1 <stage>',A);return A
	def __get_div_level(C,line):
		A=1
		for B in line:
			if B=='#':A+=1
			else:break
		return A
	def __post_process(B):
		D=set();B.__add_cast_items();del B.tree_root.find('body')[a_A]
		for C in B.tree_root.find_all('sp'):
			B.__post_process_sp(C)
			if a_J in C.attrs:D.add((C[a_J],C.speaker.text.strip(a_G)))
		for A in B.tree_root.find_all('div'):
			if A[a_A]==0:A.attrs={}
			elif A[a_A]==1:A.attrs={};A[a_B]='act'
			elif A[a_A]==2:A.attrs={};A[a_B]='scene'
			elif A[a_A]==3:A.attrs={};A[a_B]='subscene'
		B.__add_particdesc_to_header(D);B.__add_rev_desc()
	def __add_cast_items(E):
		A=E.tree_root.find(a_L)
		if A:
			F=A.text;B=F.split(a_H);A.clear();C=Tag(name='head');C.append(B[0]);A.append(C)
			for G in B[1:]:D=Tag(name='castItem');D.append(G);A.append(D)
	def __add_rev_desc(A):B=f'''
        <revisionDesc>
             <listChange>
            <change when="{datetime.today().strftime("%Y-%m-%d")}">DESCRIBE CHANGE</change>
            </listChange>
        </revisionDesc>''';C=BeautifulSoup(B,a_C);D=C.revisionDesc;A.tree_root.teiHeader.append(D)
	def __add_particdesc_to_header(B,set_of_char_pairs):
		C=Tag(name='profileDesc');D=Tag(name='particDesc');C.append(D);E=Tag(name='listPerson');D.append(E)
		for F in set_of_char_pairs:A=Tag(name='person');A[a_I]=F[0].strip('#');A['sex']=B.__guess_gender_stupid(A[a_I]);G=Tag(name='persName');A.append(G);G.append(F[1]);E.append(A)
		H=B.tree_root.teiHeader;H.append(C)
	def __handle_speaker_in_sp(C,sp,first_line):
		D=first_line;A=Tag(name='speaker');sp.append(A);B=re.search('([^()]+)(\\(.+?\\))([.,:!;])?',D)
		if B and C.bracketstages:
			A.append(B.group(1).strip());E=Tag(name=a_F);E.append(B.group(2).strip());sp.append(E);F=B.group(3)
			if F is not None:A.append(F.strip())
		else:A.append(D.strip())
		C.__transliterate_speaker_ids(sp,A)
	def __transliterate_speaker_ids(C,sp,speaker):
		B=speaker
		if re.search('[йцукенгшщзхъфывапролджэячсмитью]',B.text.lower()):A=C.__clean_after_translit(translit(B.text.strip('. '),'uk',reversed=a_D)).lower();A=A.strip(a_G)
		elif re.search('[אאַאָבבֿגדהוװוּױזחטייִײײַככּךלמםנןסעפּפֿףצץקרששׂתּת]',B.text.lower()):A=yiddish.transliterate(B.text.strip(a_G));A=re.sub('[\\u0591-\\u05BD\\u05C1\\u05C2\\\\u05C7]',' ',A)
		else:A=B.text.strip(a_G).lower();A=C.__clean_after_translit(A)
		A=C.__fix_starting_w_number(A);sp[a_J]=f"#{A}"
	def __fix_starting_w_number(C,clean_who):
		B=clean_who;A=re.match('(\\d+.*?)(_)(.+)',B)
		if A is not None:B=f"{A.group(3)}{A.group(2)}{A.group(1)}"
		return B
	def __clean_after_translit(C,line):B='i';A=line;A=A.replace('і',B);A=A.replace('ї',B);A=A.replace('і',B);A=A.replace('є','e');A=A.replace('є','e');A=A.replace('ы','y');A=A.replace("'",'');A=A.replace('’','');A=A.replace('«','');A=A.replace('»','');A=A.replace('′','');A=A.replace(' ','_');return A
	def __handle_line_with_brackets(D,speechtext,check_inline_brackets):
		B=speechtext
		for A in check_inline_brackets:
			if len(A[0])>0:B.append(A[0])
			C=Tag(name=a_F);C[a_B]='inline';C.append(A[1].strip());B.append(C)
			if len(A[2])>0:B.append(A[2])
	def __guess_gender_stupid(A,someid):
		if someid.endswith('a'):return'FEMALE'
		return'MALE'
	def __add_line_to_speech(C,line,sp,line_is_prose):
		B=line
		if line_is_prose:A=Tag(name='p')
		else:A=Tag(name='l')
		if len(B)>0:
			D=re.findall('([^()]*)(\\(.+?\\)[.,:!;]?)([^()]*)',B)
			if D and C.bracketstages:C.__handle_line_with_brackets(A,D)
			else:A.append(B)
			sp.append(A)
	def __handle_speech_in_sp(C,sp,text_split_in_lines):
		B=C.is_prose
		for A in text_split_in_lines[1:]:
			if A.startswith('%'):D=Tag(name=a_F);D.append(A.strip('%'));sp.append(D)
			elif A.startswith('~'):B=not B;A=A.strip('~');C.__add_line_to_speech(A,sp,B)
			else:C.__add_line_to_speech(A,sp,B)
	def __post_process_sp(A,sp):C=sp.text;sp.clear();B=C.split(a_H);D=B[0];A.__handle_speaker_in_sp(sp,D);A.__handle_speech_in_sp(sp,B)
	def __indent_dracor_style(D):
		C='\\1\\2';A=D.tree_root.prettify();A=re.sub('(<[^/]+?>)\\n\\s+([^<>\\s])',C,A);A=re.sub('([^<>\\s])\\n\\s+(</.+?>)',C,A);A=re.sub('(<speaker>)([^<>]+)\\s*\\n\\s*([^<>]+)(</speaker>)','\\1\\2\\3\\4',A);A=re.sub('([\\n\\s]+)(<stage type="inline">)([^<>]+)(</stage>)([\\n\\s]+)','<stage>\\3\\4',A);B=[]
		for E in A.split(a_H):F=re.sub('^( +)','\\1'*2,E);B.append(F)
		A=a_H.join(B);BeautifulSoup(A,a_C);return A
	def output_to_file(A,newfilepath):
		B=newfilepath
		with open(B,'w')as C:C.write(A.tree_to_write);A.outputname=B
if __name__=='__main__':parser=Parser();parser.process_file('sample.txt')

#noenv
#SingleInstance,force

VerDate := "2016-01-28"
bDebug := 0

DownDir := "C:\etc"
IfNotExist, %DownDir%
	DownDir := A_scriptdir

	; ����PATH������������ú�������
	EnvGet, Paths, PATH
	EnvSet, PATH, C:\bin\bin32`;D:\bin\bin32`;%A_scriptdir%\bin32`;%A_scriptdir%`;%Paths%

ArgA = %1% ; ����
ArgB = %2% ; ��������
if ( ArgA != "" ) {
	DefName := ArgA
	bAuto := true
} else {
	DefName = %clipboard%
	bAuto := false
}
if ( ArgB = "" ) {
	typeN := 9
} else {
	typeN := ArgB
}

if ( bDebug ) {
	DefName := "ԭʼս��"
	typeN := 6
}

SE_ListT=
(join|
S:��������ֻ�
S:׷������
S:���
S:����
S:Baidu
S:SoGou
S:Soso
----------
E:Bing
E:SouGou
E:Yahoo
E:GotoHell
E:Soso
E:ZhongSou
E:youdao
E:360
E:AOL
)

ZSSQ_Agent := "ZhuiShuShenQi/2.20"

GuiInit:
	Gui,Add,DropDownList,x4 y10 w120 vSE_Type R20 choose%typeN%, %SE_ListT%
	Gui,Add,ComboBox,x134 y10 w170 h20 R10 vSE_Name choose1, %DefName%|ĩ�վ���Ժ|����|���� site:69zw.com
	Gui,Add,Button,x314 y10 w70 h20 vSE_Go gSE_Go,��(&S)
	Gui,Add, Checkbox,x404 y10 w100 h20 cBlue checked  vDelHTML, ɾ��HTML(&D)
;	Gui,Add,ComboBox,x404 y10 w470 R10 hidden vSE_Add

	Gui,Add,ListView,x4 y40 w870 h310 NoSortHdr vFoxLV gClickLV, T|Name|URL
	LV_ModifyCol(1, 70)
	LV_ModifyCol(2, 270)
	LV_ModifyCol(3, 500)
	Gui, Add, StatusBar, , ����:������֮��  �汾: %VerDate%  ��ʾ:  F1: �����������IDתΪ��URL
	Gui,Show, w881 h370 , Search
	GuiControl, Focus, SE_Name

	if bAuto
		gosub, SE_Go
return

SE_Go: ; ��ʼ����
	Gui, submit, nohide
	if instr(SE_Type, "E:")
	{ ; ��������
		if (SE_Type = "E:SouGou")
			URL := "http://www.sogou.com/web?query=" . SE_Name . "&num=50"
		if (SE_Type = "E:Bing")
			URL := "http://cn.bing.com/search?q=" . CN_2_UTF8_URL(SE_Name)
		if (SE_Type = "E:Yahoo")
			URL := "http://search.yahoo.com/search?n=40&p=" . CN_2_UTF8_URL(SE_Name)
		if (SE_Type = "E:Soso")
			URL := "http://www.soso.com/q?w=" . SE_Name
		if ( SE_Type = "E:ZhongSou" )
			URL := "http://www.zhongsou.com/third.cgi?w=" . CN_2_UTF8_URL(SE_Name) . "&kid=&y=5&stag=1&dt=0&pt=0&utf=1"
		if ( SE_Type = "E:youdao" )
			URL := "http://www.youdao.com/search?q=" . CN_2_UTF8_URL(SE_Name) . "&ue=utf8&keyfrom=web.index"
		if ( SE_Type = "E:360" )
			URL := "http://www.haosou.com/s?ie=utf-8&shb=1&src=360sou_newhome&q=" . CN_2_UTF8_URL(SE_Name)
		if ( SE_Type = "E:GotoHell" )
			URL := "http://devilfinder.com/search.php?q=" . CN_2_UTF8_URL(SE_Name)
		if ( SE_Type = "E:AOL" ) {
			URL := "http://search.aol.com/aol/search?count_override=20&q=" . CN_2_UTF8_URL(SE_Name)
			savePath := "AOL_" . SE_Name . ".html"
			IfNotExist, %savePath%
				runwait, curl "%URL%" -o "%savePath%" -A "ZhuiShuShenQi/2.18" -H "Connection: Keep-Alive" -H "Accept-Encoding: gzip" --compressed, %DownDir%, Min
			fileread, html, *P65001 %DownDir%\%savePath%
			GuiControlGet, DelHTML
			if ( DelHTML )
				FileDelete, %DownDir%%savePath%
			LV_Delete()
			SE_getHrefList(html, SE_Name)
			return
		}

		StringReplace, newtt, SE_Type, E:, , A
		html := wget(URL, newtt . "_" . SE_Name . ".html")
		LV_Delete()
		SE_getHrefList(html, SE_Name)
	}
	if ( SE_Type = "S:��������ֻ�" ) {
		StrName := CN_2_UTF8_URL(SE_Name) ; UTF-8�����encode
		sURL := qidian_getSearchURL_Mobile(StrName)
		sJSON := DownJson(sURL)
		j := JSON.parse(sJSON)
		LV_Delete()
		loop, % j.Data.ListSearchBooks.MaxIndex()
		{
			if ( j.Data.ListSearchBooks[A_index].VipStatus )
				LV_Add("", "�������", j.Data.ListSearchBooks[A_index].BookName . "__" . j.Data.ListSearchBooks[A_index].NewVipChapterName
			, qidian_getIndexURL_Mobile(j.Data.ListSearchBooks[A_index].BookId))
			else 
				LV_Add("", "�������", j.Data.ListSearchBooks[A_index].BookName . "__" . j.Data.ListSearchBooks[A_index].NewChapterName
			, qidian_getIndexURL_Mobile(j.Data.ListSearchBooks[A_index].BookId))
		}
	}
	if ( SE_Type = "S:׷������" ) {
		StrName :=CN_2_UTF8_URL(SE_Name) ; UTF-8�����encode
		sURL := "http://api.zhuishushenqi.com/book?view=search&query=" . StrName
		runwait, wget -U "%ZSSQ_Agent%" -O "zs_search.json" "%sURL%", %DownDir%, Min
		fileread, sJson, *P65001 %DownDir%\zs_search.json
		filedelete, %DownDir%\zs_search.json
		j := JSON.parse(sJSON)
		LV_Delete()
		loop, % j.MaxIndex()
		{
			LV_Add("", "׷������"
			, j[A_Index].title . "__" . j[A_Index].lastChapter
			,j[A_Index]._id)
		}
	}
	if ( SE_Type = "S:���" ) {
		LV_Delete()
		LV_Add("", "�������", SE_Name, qreader_Search(SE_Name))
	}
	if ( SE_Type = "S:����" ) {
		StrName := CN_2_UTF8_URL(SE_Name) ; UTF-8�����encode
		sURL := "http://api.easou.com/api/bookapp/search.m?word=" . StrName . "&type=0&page_id=1&count=20&sort_type=0&cid=eef_easou_book"
		j := JSON.parse(DownJson(sURL))
		sURL := "http://api.easou.com/api/bookapp/search_chapterrel.m?gid=" . j.items[1].gid . "&nid=" . j.items[1].nid . "&chapter_name=" . CN_2_UTF8_URL(j.items[1].lastChapterName) . "&cid=eef_easou_book"
		j := JSON.parse(DownJson(sURL))
		LV_Delete()
		loop, % j.items.MaxIndex()
		{  ; chapterCount
			LV_Add("", "����վ��"
			, j.items[A_Index].site . "__" . j.items[A_Index].last_chapter_name
			, "http://api.easou.com/api/bookapp/chapter_list.m?gid=" . j.items[A_Index].gid . "&nid=" . j.items[A_Index].nid . "&page_id=1&size=2147483647&cid=eef_easou_book")
		}
	}
	if ( SE_Type = "S:Soso" ) {
		StrName := CN_2_UTF8_URL(SE_Name) ; UTF-8�����encode
		sURL := "http://book.soso.com/ajax?m=list_book&start=1&resourcename=" . StrName
		sJSON := DownJson(sURL . """ -e ""http://book.soso.com/")
		j := JSON.parse(sJSON)
		LV_Delete()
		loop, % j.rows.MaxIndex()
		{	; from
			LV_Add("", "��������"
			, j.rows[A_index].lastserialid . "__" . j.rows[A_index].lastserialname  . "__" . j.rows[A_Index].resourcename
			, "http://book.soso.com/ajax?m=list_charpter&sort=asc&resourceid=" . j.rows[A_index].resourceid . "&serialnum=" . j.rows[A_index].serialnum)
;			, "http://book.soso.com/ajax?m=show_bookcatalog&sort=asc&resourceid=" . j.rows[A_index].resourceid . "&serialid=" . j.rows[A_index].serialnum)
		}
	}
	if ( SE_Type = "S:Baidu" ) {
		StrName := CN_2_UTF8_URL(SE_Name) ; UTF-8�����encode
		sURL := "http://dushu.baidu.com/ajax/searchresult?word=" . StrName
		j := JSON.parse(DownJson(sURL))
		LV_Delete()
		loop, % j.list.MaxIndex()
		{
			LV_Add("", "�ٶ�����"
			, j.list[A_Index].book_name . "__" . j.list[A_index].author
			, "http://m.baidu.com/tc?srd=1&appui=alaxs&ajax=1&pageType=list&dir=1&src=" . j.list[A_Index].src . "&gid=" . j.list[A_Index].book_id . "&time=&skey=&id=wisenovel")
		}
	}
	if ( SE_Type = "S:sogou" ) {
		sURL := "http://novel.mse.sogou.com/http_interface/getSerRs.php?keyword=" . CN_2_UTF8_URL(SE_Name) . "&p=1"
		j := JSON.parse(DownJson(sURL))
		LV_Delete()
		loop, % j.list.MaxIndex()
		{
			LV_Add("", "�ѹ�����"
			, j.list[A_Index].bookname . "_by_" . j.list[A_index].author . "__" . j.list[A_index].bookid
			, "http://novel.mse.sogou.com/http_interface/getDirData.php?md=" . j.list[A_Index].md)
		}
	}
return

ClickLV: ; ���LV
	nRow := A_EventInfo
	if ( A_GuiEvent = "DoubleClick" ) {
		LV_GetText(NowID, nRow, 1)
		LV_GetText(NowName, nRow, 2)
		LV_GetText(NowURL, nRow, 3)
		if ( nRow < 1 ) { ; ����
			return
		}
		if (NowID = "�ѹ�����") {
			j := JSON.parse(DownJson(NowURL))
			LV_Delete()
			nowMD := j.book.md  ; id
			loop, % j.chapter.MaxIndex()
				LV_Add("", "�ѹ�����", j.chapter[A_index].name, "http://novel.mse.sogou.com/http_interface/getContData.php?md=" . nowMD . "&url=" . j.chapter[A_index].url)  ; cmd
		}
		if (NowID = "�ѹ�����") {
			j := JSON.parse(DownJson(NowURL))
			nowBody := j.content[1].block
			StringReplace, nowBody, nowBody, \n, `n, A
			StringReplace, nowBody, nowBody, ����, , A
			showContent(j.book.chapter . "`n`n" . nowBody)
		}
		if (NowID = "�ٶ�����") {
			j := JSON.parse(DownJson(NowURL))
			LV_Delete()
			nowGID := j.data.gid
			loop, % j.data.group.MaxIndex()
				LV_Add("", "�ٶ�����", j.data.group[A_index].text, "http://m.baidu.com/tc?srd=1&appui=alaxs&ajax=1&gid=" . nowGID . "&pageType=undefined&src=" . j.data.group[A_index].href . "&time=&skey=&id=wisenovel")  ; cid
; http://m.baidu.com/tc?srd=1&appui=alaxs&ajax=1&gid=4283999291&pageType=undefined&src=http%3A%2F%2Fwww.freexs.cn%2Fnovel%2F112%2F112789%2F20967540.html&time=&skey=&id=wisenovel
		}
		if (NowID = "�ٶ�����") {
			j := JSON.parse(DownJson(NowURL))
			showContent(j.data.title . "`n`n" . FoxNovel_getPageText(j.data.content))
		}
		if (NowID = "�������") {
			fsldk_1 := ""
			RegExMatch(NowURL, "i)BookId=([0-9]+)", fsldk_)
			LV_Delete()
			SB_SetText("����json�У����ܺ�ʱ�ܳ���ľ�취����Ҳ��ʹ��������ʽ�Ǹ��ð취")
			j := JSON.parse(DownJson(NowURL))
			qdtxtHead := "http://files.qidian.com/Author" . ( 1 + mod(fsldk_1, 8) ) . "/" . fsldk_1 . "/"
			loop, % j.Chapters.MaxIndex()
			{
				if ( j.Chapters[A_index].v )
					LV_Add("", "�������", j.Chapters[A_index].n, "http://VIP/")
				else
					LV_Add("", "�������", j.Chapters[A_index].n, qdtxtHead . j.Chapters[A_index].c . ".txt")
			}
		}
		if (NowID = "�������") {
			runwait, wget -O xxxx.js "%NowURL%", %DownDir%, Min
			fileread, sJS, %DownDir%\xxxx.js
			showContent(qidian_getTextFromPageJS(sJS))
			filedelete, %DownDir%\xxxx.js
		}
		if (NowID = "׷������") {
			sURL := "http://api.zhuishushenqi.com/toc?view=summary&book=" . NowURL
			runwait, wget -U "%ZSSQ_Agent%" -O "zs_sitelist.json" "%sURL%", %DownDir%, Min
			fileread, sJson, *P65001 %DownDir%\zs_sitelist.json
			filedelete, %DownDir%\zs_sitelist.json

			LV_Delete()
			j := JSON.parse(sJSON)
			loop, % j.MaxIndex()
			{
				LV_Add("", "׷��վ��"
				, j[A_Index].lastChapter . "__" . j[A_Index].name
				, "http://api.zhuishushenqi.com/toc/" . j[A_Index]._id . "?view=chapters&bid=" . NowURL)
			}
			; http://api.zhuishushenqi.com/toc/539e02ae66e0dbc55e3f8a60?view=chapters&bid=52e13475c09f68641700068d
		}
		if (NowID = "׷��վ��") {
			runwait, wget -U "%ZSSQ_Agent%" -O "zs_chapter_list.json" "%NowURL%", %DownDir%, Min
			fileread, sJson, *P65001 %DownDir%\zs_chapter_list.json
			filedelete, %DownDir%\zs_chapter_list.json
			LV_Delete()
			SB_SetText("����json�У����ܺ�ʱ�ܳ���ľ�취����Ҳ��ʹ��������ʽ�Ǹ��ð취")
			j := JSON.parse(sJSON)
			loop, % j.chapters.MaxIndex()
			{
				LV_Add("", "׷������"
				, j.chapters[A_index].title
				, "http://chapter.zhuishushenqi.com/chapter/" . GeneralW_UTF8_UrlEncode(j.chapters[A_index].link))
			}
		}
		if (NowID = "׷������") {
			runwait, wget -U "%ZSSQ_Agent%" -O "zs_chapter.json" "%NowURL%", %DownDir%, Min
			fileread, sJson, *P65001 %DownDir%\zs_chapter.json
			filedelete, %DownDir%\zs_chapter.json
			j := JSON.parse(sJSON)
			nowTitle := j.chapter.title
			nowBody := j.chapter.body
			StringReplace, nowBody, nowBody, \n, `n, A
			StringReplace, nowBody, nowBody, ����, , A
			showContent(nowTitle . "`n`n" . nowBody)
		}
		if (NowID = "�������") {
			LV_Delete()
			un := qreader_GetIndex(NowURL)
			loop, % un.MaxIndex()
				LV_Add("", "�������", un[A_index,2], NowURL . un[A_index,1])
		}
		if (NowID = "�������") {
			showContent(qreader_GetContent(NowURL))
		}
		if (NowID = "����վ��") {
			SB_SetText("����json�У����ܺ�ʱ�ܳ���ľ�취����Ҳ��ʹ��������ʽ�Ǹ��ð취")
			j := JSON.parse(DownJson(NowURL))
			LV_Delete()
			idd_1 := "" , idd_2 := ""
			RegExMatch(NowURL, "i)gid=([0-9]+).*nid=([0-9]+)", idd_)
			loop, % j.items.MaxIndex()
			{ ; nid  ctype
				LV_Add("", "��������", j.items[A_index].chapter_name
				, "http://api.easou.com/api/bookapp/batch_chapter.m?a=1&cid=eef_easou_book&gsort=0&sequence=0&gid=" . idd_1 . "&nid=" . idd_2 . "&sort=" . j.items[A_index].sort . "&chapter_name=" . CN_2_UTF8_URL(j.items[A_index].chapter_name) )
			}
		}
		if (NowID = "��������") {
			j := JSON.parse(DownJson(NowURL))
			showContent(j.items[1].content)
		}
		if (NowID = "��������") {
			fsldk_1 := ""
			RegExMatch(NowURL, "i)resourceid=([0-9]+)&", fsldk_)
			LV_Delete()
			j := JSON.parse(DownJson(NowURL . """ -e ""http://book.soso.com/"))
			loop, % j.rows.MaxIndex()
			{
				LV_Add("", "��������", j.rows[A_index].serialname
				, "http://book.soso.com/ajax?m=show_bookdetail&encrypt=1&readSerialid=1&resourceid=" . fsldk_1 . "&serialid=" . j.rows[A_index].serialid)
			}
		}
		if (NowID = "��������") {
			j := JSON.parse(DownJson(NowURL . """ -e ""http://book.soso.com/"))
			cc := soso_decContent2(j.rows[1][1].serialcontent)
			StringReplace, cc, cc, <br>, `n,A
			StringReplace, cc, cc, <br/>, `n,A
			StringReplace, cc, cc, `n`n, `n,A
			showContent(j.rows[1][1].serialname . "`n`n" . cc)
		}
		if ( NowID = "�������" ) {
			Clipboard = %nowURL%
			sTime := A_TickCount
			iHTML := wget(NowURL)
			eTime := A_TickCount - sTime

			stringreplace, iHTML, iHTML, `r, , A
			stringreplace, iHTML, iHTML, `n, , A
			iHTML := RegExReplace(iHTML, "Ui)<!--[^>]+-->", "") ; ɾ��Ŀ¼�е�ע�� ��� niepo
			iHTML := RegExReplace(iHTML, "Ui)<span[^>]+>", "") ; ɾ�� span��ǩ qidian
			stringreplace, iHTML, iHTML, </span>, , A

			stringreplace, iHTML, iHTML, <a, `n<a, A
			stringreplace, iHTML, iHTML, </a>, </a>`n, A
			stringreplace, iHTML, iHTML, ����, %A_space%%A_space%%A_space%%A_space%, A

			kk := FoxNovel_getHrefList(iHTML)
			nlaststart := kk.MaxIndex() - 20 
			outlist := ""
			LV_Delete()
			loop, % kk.maxindex()
			{
				if ( A_index < nlaststart )
					continue
				LV_Add("", "�½��б�", kk[A_Index,2], GetFullURL(kk[A_index,1], NowURL))
;				outlist .= kk[A_index, 1] . "`t" . kk[A_index,2] . "`n"
			}
			SB_settext("���غ�ʱ(ms): " . eTime)
		}
		if ( NowID = "�½��б�" ) {
			sTime := A_TickCount
			iHTML := wget(NowURL)
			eTime := A_TickCount - sTime
			showContent(FoxNovel_getPageText(iHTML))
		}
	}
	if ( A_GuiEvent = "R" ) {
		LV_GetText(NowID, nRow, 1)
		LV_GetText(NowName, nRow, 2)
		LV_GetText(NowURL, nRow, 3)

		Clipboard = %nowURL%
		if (NowID = "�������") {
			html := wget(nowURL)
			LV_Delete()
			SE_getHrefList(html, nowURL)
			return
		}
		IfWinExist, �༭���� ahk_class AutoHotkeyGUI
		{
			ControlSetText, Edit4, %nowURL%, �༭���� ahk_class AutoHotkeyGUI
			TrayTip, ���Ƶ�FoxBook��ַ��:, %nowURL%
		}
		TrayTip, ������:, % nowURL
	}
return

GuiClose:
GuiEscape:
	ExitApp
return

!1::CopyInfo2Clip(1)
!2::CopyInfo2Clip(2)
!3::CopyInfo2Clip(3)
!4::CopyInfo2Clip(4)
!5::CopyInfo2Clip(5)
!6::CopyInfo2Clip(6)
!7::CopyInfo2Clip(7)
!8::CopyInfo2Clip(8)
!9::CopyInfo2Clip(9)

; 2015-9-14:���URL����仯�����������е�ID�����ID
F1::
	xx := QD_bookID_to_newBookID(Clipboard)
	TrayTip, %clipboard%:, %xx%
;	clipboard = %xx%
	clipboard = http://read.qidian.com/BookReader/%xx%.aspx
return

QD_bookID_to_newBookID(oldBookID="1939238")
{
	infoURL := "http://www.qidian.com/Book/" . oldBookID . ".aspx"
	tmpHTML := "qd_" . A_now . ".qd"
	runwait, wget -O "%tmpHTML%" "%infoURL%", %DownDir%, min
	fileread, html, %DownDir%\%tmpHTML%
	FileDelete, %DownDir%\%tmpHTML%

	RegExMatch(html, "BookIdDes:""([^""]+)""", xx_)
	return, xx_1
}

#include <JSON_Class>

CopyInfo2Clip(Num=1) {
	LV_GetText(NowVar, LV_GetNext(0), Num)
	Clipboard = %NowVar%
	TrayTip, ������:, %NowVar%
}

DownJson(inURL="", TmpName="xxx.json", bDelete=1) ; ����json����ȡ
{
	global DownDir
	IfNotExist, %DownDir%\%TmpName%
		runwait, curl -o "%TmpName%" --compressed "%inURL%", %DownDir%, Min
	fileread, sjson, *P65001 %DownDir%\%TmpName%
	if bDelete
		FileDelete, %DownDir%\%TmpName%
	return, sjson
}

; book.soso.com  ���ݽ���
soso_decContent2(cc) ; 10594   12625 15000   ms/1000��
{
	bb := ""

	loop, parse, cc
	{
		if ( 0 = mod(A_index, 2) )
			bb .= A_loopfield . c1
		else
			c1 := A_loopfield
	}

	if ( 1 = mod(strlen(cc), 2) )
		bb .= c1

	return bb
}

wget(URL, SaveName="", AddParamet="") {
	global DownDir
	if ( SaveName = "" )
		SaveName := "Wget_" . A_now
	IfNotExist, %DownDir%\%SaveName%
	{
		loop 9 { ; ���أ�ֱ���������
			runwait, wget -c -T 5 -O "%SaveName%" %AddParamet% "%URL%", %DownDir%, Min UseErrorLevel
			If ( ErrorLevel = 0 )
				break
			else
				SB_settext("���ش���: ���Ե�ַ: " . URL)
		}
	}

	html := ReadHTML(DownDir . "\" . SaveName)
	GuiControlGet, DelHTML
	if ( DelHTML )
		FileDelete, %DownDir%\%SaveName%
	return  html
}

SE_getHrefList(html, KeyWord="����ũ����") ; KeyWord�а���http��ʾ����ַ�������ϳ�������ַ
{
	if (instr(KeyWord, "http")) {
		isSearchEngine := false
	} else {
		isSearchEngine := true
	}
;	stringreplace, html,html, %A_space%%A_space%%A_space%, %A_space%, A
	stringreplace, html,html, `t, , A
	stringreplace, html,html, `r, , A
	stringreplace, html,html, `n, , A

	html := RegExReplace(html, "smUi)<!--[^>]+-->", "")
	html := RegExReplace(html, "smUi)<span[^>]*>", "")
	stringreplace, html,html, </span>, , A
	stringreplace, html,html, <em>, , A
	stringreplace, html,html, </em>, , A
	stringreplace, html,html, <b>, , A
	stringreplace, html,html, </b>, , A
	stringreplace, html,html, <strong>, , A
	stringreplace, html,html, </strong>, , A

	stringreplace, html,html, <a, `n<a, A
	stringreplace, html,html, </a>, </a>`n, A

	loop, parse, html, `n, `r
	{
		if ! instr(A_LoopField, "</a>")
			continue
		xx_1 := "" , xx_2 := ""
		regexmatch(A_LoopField, "i)href *= *[""']?([^>""']+)[""']?[^>]*> *(.*)</a>", xx_)
		if ( strlen(xx_1) < 5 )
			continue
		if ( isSearchEngine ) {
			if ! instr(xx_1, "http:")
				continue
			if instr(xx_1, "http://www.sogou.com/web?query=")
				continue
			if ! instr(xx_2, KeyWord)
				continue
			LV_Add("", "�������", xx_2, xx_1)
		} else {
			LV_Add("", "�������", xx_2, GetFullURL(xx_1, KeyWord))
		}
	}
	return, list
}

GetFullURL(ShortURL="xxx.html", ListURL="http://www.xxx.com/45456/238/list.html")
{	; ��ȡ����URL
	If Instr(ShortURL, "http://")
		return, ShortURL
	Stringleft, ttt, ShortURL, 1
	SplitPath, ListURL, OutFileName, OutDir, OutExtension, OutNameNoExt, OutDrive
	If ( ttt = "/" )
		return, OutDrive . ShortURL
	else
		return, OutDir . "/" . ShortURL
}


CN_2_UTF8_URL(iName)
{
	return GeneralW_UTF8_UrlEncode(GeneralW_StrToUTF8(iName))
}

showContent(NR="������")
{
	if ! instr(NR, "`r`n")
		StringReplace, nr, NR, `n, `r`n, A
	ListVars
	winwait, ahk_class AutoHotkey, Global Variables, 3
	ControlSetText, Edit1, %NR%, ahk_class AutoHotkey, Global Variables
}

ReadHTML(HtmlPath) ; �Զ���ȡhtml�ļ����Զ��ֱ�charset
{
	FileRead, html, *P65001 %HtmlPath%
	regexmatch(html, "Ui)<meta[^>]+charset([^>]+)>", Encode_)
	If ( ! instr(Encode_1, "UTF-8") )
		FileRead, html, %HtmlPath%
	return, html
}


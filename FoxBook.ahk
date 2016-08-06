; 2016-08-06 �޸�

; ��û������䣬�ᵼ����1.1.8.0����SQLite����
#NoEnv
	; ����PATH��������������runֻʹ��exe����
	EnvGet, Paths, PATH
	EnvSet, PATH, C:\bin\bin32`;D:\bin\bin32`;%A_scriptdir%\bin32`;%A_scriptdir%`;%Paths%

	EnvGet, DBPath, DB3PATH ; �ӻ�������DB3PATH�л�ȡ�������ݿ�·��
	if ( "" = DBPath )
		DBPath :=  A_scriptdir . "\FoxBook.db3"

	; �ж��Ƿ���RamOS�Ծ�����ʱĿ¼�����Ŀ¼
	Ifexist, %A_windir%\system32\drivers\firadisk.sys
		FoxSet := { "TmpDir": "C:\tmp" , "OutDir": "C:\etc" }
	else
		FoxSet := { "TmpDir": A_scriptdir . "\tmp" , "OutDir": A_scriptdir }
	FoxSet["PicDir"] := A_scriptdir . "\FoxPic"
	nowDBnum := 1 ; �л����ݿ���

	IfNotExist, % FoxSet["TmpDir"]
		FileCreateDir, % FoxSet["TmpDir"]
	FoxSet["MyPID"] := DllCall("GetCurrentProcessId") ; ������PID

	bMemDB := true ; ʹ���ڴ����ݿ�

	bOutEbookPreWithAll := true  ; ����ļ���Ϊall_xxxxx.xxx

ObjectInit:
	; ���������ظ� select * from book where name in(select name from book group by name having count(name)>1) order by name,url,id
	oDB := new SQLiteDB
	if ( bMemDB ) {
		oDB.OpenDB(":memory:")
		FoxMemDB(oDB, DBPath, "File2Mem")
	} else {
		oDB.OpenDB(DBPath)
	}
	FileGetSize, dbfilesize, %DBPath% ; ���ݿ��СΪ0�½�
	if ( 0 = dbfilesize)
		CreateNewDB(oDB)

	CheckAndFixDB(oDB) ; ��ѯ ��ṹ������Ƿ�ȱ�������ֶΣ��޸���

	oBook := New Book(oDB, FoxSet, 0)

	FoxCompSiteType := getCompSiteType(oDB)

	; ��������=0����GUI���������������
	iArgCount = %0%
	if ( iArgCount = 0 )
		gosub, GuiInit
	else
		gosub, CommandProcess
return
; �Զ�������


; { Init
CommandProcess:                ; ִ���ⲿ������������
	iAction = %1%
	iArgA = %2%
	If ( iAction = "" )
		return
	else
		print() ; ��ʼ�� �����б�׼���
	If ( iAction = "-h" or iAction = "h" or iAction = "help" or iAction = "--help" ) {
cmdstr =
(join`n
FoxBook�������÷�: FoxBook [ѡ��] [����]

  up		���������鼮
  ls [b|.p|l|a]	��ʾ�鼮�½��б�/�½�����
  rm [b|.p]	���ָ���鼮�����½�
  sort [a|d]	�����鼮
  sp		����ҳ��

  toM		ת��ΪMobi������
  toU		ת��ΪUMD������
  toE		ת��ΪEpub������
  toC		ת��ΪCHM������
  toT		ת��ΪTxt������
  toP		ת��ΪPDF������

  vac		����ѹ�����ݿ�
  [-]h		������

)
		print(cmdstr)
	}
	If ( iAction = "up" ) {
		print("��ʼ���������鼮`n")
		NowInCMD := "UpdateAll"
		gosub, BookMenuAct
		print("�Ѹ��������鼮`n")
	}
	If ( iAction = "ls" ) {
		if iArgA is alpha
			SQLstr := "select id, charcount, name from page where bookid = " . alpha2integer(iArgA)
		if ( iArgA = "" )
			SQLstr := "select book.id,count(page.id) cc,book.name from Book left join page on book.id=page.bookid group by book.id order by cc"
		if ( iArgA = "a" )
			SQLstr := "select page.id, book.name, page.name from book, page where page.bookid = book.id order by page.Bookid Desc,page.id "
		if ( iArgA = "l" )
			SQLstr := "select page.id, book.name, page.name from book, page where page.bookid = book.id order by page.DownTime Desc,page.id Desc limit 20"
		if iArgA is integer
			SQLstr := "select id, charcount, name from page where bookid = " . iArgA
		if instr(iArgA, ".")
		{
			StringReplace, argtwo, iArgA, ., , A
			if argtwo is alpha
				SQLstr := "select charcount, name, Content from page where id = " . alpha2integer(argtwo)
			if argtwo is integer
				SQLstr := "select charcount, name, Content from page where id = " . argtwo
		}
		oDB.GetTable(SQLstr, oRS)
		outNR := ""
		loop, % oRS.rowcount
			outNR .= oRS.rows[A_index][1] . "`t" . oRS.rows[A_index][2] . "`t" . oRS.rows[A_index][3] . "`n"
		print(outNR)
	}
	If ( iAction = "rm" ) {
		If ( iArgCount < 2 ) {
			print("����½ں���ȱ��bookid`n")
			gosub, FoxExitApp
		}
		if iArgA is alpha
			SQLstr := "select id from page where bookid = " . alpha2integer(iArgA)
		if iArgA is integer
			SQLstr := "select id from page where bookid = " . iArgA
		if instr(iArgA, ".")
		{
			StringReplace, argtwo, iArgA, ., , A
			if argtwo is alpha
				SQLstr := "select id from page where id = " . alpha2integer(argtwo)
			if argtwo is integer
				SQLstr := "select id from page where id = " . argtwo
		}
		oDB.GetTable(SQLstr, oIDlist)
		iIDList := []
		loop, % oIDlist.rowcount
			iIDList[A_index] := oIDlist.rows[A_index][1]
		oBook.DeletePages(iIDList) ; ɾ���½���Ŀ
		if instr(iArgA, ".")
			print("��ɾ��ָ���½�: " . argtwo . "`n")
		else
			print("������鼮 " . iArgA . " �е������½�`n")
	}
	If iAction in toM,toE,toU,toC,toT,toP
	{
		if ( iAction = "toM" )
			TmpMod := "mobi"
		if ( iAction = "toE" )
			TmpMod := "epub"
		if ( iAction = "toU" )
			TmpMod := "umd"
		if ( iAction = "toC" )
			TmpMod := "chm"
		if ( iAction = "toT" )
			TmpMod := "txt"
		if ( iAction = "toP" )
			TmpMod := "pdf"
		print("��ʼת������ҳ�浽" . TmpMod . "��ʽ`n" )
		oDB.GetTable("select ID from Page order by bookid,ID", oIDlist)
		aPageIDList := []
		loop, % oIDlist.rowcount
			aPageIDList[A_index] := oIDlist.rows[A_index][1]
		If bOutEbookPreWithAll
			SavePath := FoxSet["OutDir"] . "\all_" . FoxCompSiteType . "." . TmpMod
		else
			SavePath := FoxSet["OutDir"] . "\" . oBook.book["name"] . "." . TmpMod
		If iAction in toM,toE,toU,toC,toT
			oBook.Pages2MobiorUMD(aPageIDList, SavePath, FoxCompSiteType)
		if ( iAction = "toP" )
			oBook.Pages2PDF(aPageIDList, SavePath)
		print("��ת������ҳ�浽" . TmpMod . "��ʽ`n" )
	}
	If ( iAction = "sort" ) {
		if ( iArgA = "" or iArgA = "a" or iArgA = "d" ) {
			oBook.ReGenBookID("Desc", "select ID From Book order by ID Desc")
			if ( iArgA = "d" )
				sPar := "desc" , smm := "����"
			else
				sPar := "asc" , smm := "˳��"
			oBook.ReGenBookID("Asc", "select book.ID from Book left join page on book.id=page.bookid group by book.id order by count(page.id) " . sPar . ",book.isEnd,book.ID")
			oDB.Exec("update Book set Disorder=ID")
			print("���鼮ҳ��" . smm . "���� �� �����鼮ID���`n")
		} else {
			print("������Ϊ a �� d`n")
		}
	}
	If ( iAction = "sp" ) {
		print("��ʼ����ҳ��ID`n")
		oBook.ReGenPageID("Desc")
		oBook.ReGenPageID("Asc")
		print("ҳ��ID�������`n")
	}
	If ( iAction = "vac" ) {
		NowInCMD := "SaveAndCompress"
		gosub, DBMenuAct
		print("�հ��ļ���ɾ�����, " . TmpSBText . "�ͷŴ�С(K): " . ( StartSize - EndSize ) . "   ���ڴ�С(K): " . EndSize . "`n")
	}
	NowInCMD := ""
	gosub, FoxExitApp
return

alpha2integer(inST="") ; ʹ��qwertyuiop��ʾ1234567890
{
	kk := "qwertyuio"
	loop, parse, kk
		StringReplace, inST, inST, %A_LoopField%, %A_index%, A
	StringReplace, inST, inST, p, 0, A
	return, inST
}


GuiInit:
	bNoSwitchLV := 0  ; ״̬: �����л�LV

	; GUI�������Ӧϵͳ�仯
	if A_OSVersion in WIN_XP,WIN_2003
		gw := 775
	else
		gw := 783
	Gui, +HWNDhMain ; +Resize
	Gosub, MenuInit
	Gui, Add, ListView, x6 y10 w205 h400 +HwndhLVBook vLVBook gListViewClick AltSubmit, ����|ҳ��|ID|URL
		LV_ModifyCol(1, 100), LV_ModifyCol(2, 40) , LV_ModifyCol(3, 30), LV_ModifyCol(4, 10)
	Gui, Add, ListView, x216 y10 w550 h400 +HwndhLVPage vLVPage gListViewClick AltSubmit, ����|����|URL|ID
		LV_ModifyCol(1, 300), LV_ModifyCol(2, 50), LV_ModifyCol(3, 130), LV_ModifyCol(4, 40)

	Gui, Add, StatusBar, , ��ӭʹ�ù�
	; Generated using SmartGUI Creator 4.0
	Gui, Show, w%gw% h435, FoxBook
	OnMessage(0x4a, "Receive_WM_COPYDATA")  ; ������һ���ű��������ַ���
	onmessage(0x100, "FoxInput")  ; ������ؼ��������ⰴ���ķ�Ӧ
	LV_Colors.OnMessage() ; LV��ɫ


	oBook.hLVBook := hLVBook
	oBook.hLVPage := hLVPage

	oLVBook := new FoxLV("LVBook")
	oLVBook.FieldSet := [[100,"����"],[40,"ҳ��"],[30,"ID"],[10,"URL"]] ; Book

	oLVPage := new FoxLV("LVPage")
	oLVPage.FieldSet := [[300,"����"],[50,"����"],[130,"URL"],[40,"ID"]] ; Page

	oLVDown := new FoxLV("LVPage")
	oLVDown.FieldSet := [[300,"�½�"],[50,"����"],[130,"����"],[40,"ID"]] ; Down

	oLVComp := new FoxLV("LVPage")
	oLVComp.FieldSet := [[200,"�����½�"],[200,"��վ�½�"],[95,"����"],[40,"ID"],[9, "URL"]] ; �Ƚ�

	gosub, SettingMenuCheck

	sTime := A_TickCount
	BookCount := oBook.ShowBookList(oLVBook)
	SB_settext(bMemDB . " ��ѯ��ʱ: " . ( A_TickCount - sTime) . " ms  �鼮��: " . BookCount . "  In: " . DBPath)

	gosub, CommandProcess ; ִ���ⲿ������������
	WinSet, ReDraw, , A  ; �ػ洰��
return


; --------
BookGUICreate:
	Gui, Book:New, +Resize
	Gui, Book:Add, GroupBox, x6 y10 w350 h80 cBlue, BookID | BookName | QidianID | URL
	Gui, Book:Add, Edit, x16 y30 w40 h20 disabled vBookID, %BookID%
	Gui, Book:Add, Edit, x66 y30 w130 h20 vBookName, %BookName%
	Gui, Book:Add, Button, x200 y30 w20 h20 gEditBookInfo vSearchNovel, &D
	Gui, Book:Add, Edit, x224 y30 w70 h20 vQidianID, %QidianID%
	Gui, Book:Add, Button, x294 y30 w50 h20 gEditBookInfo vGetQidianID, &QD_ID
	Gui, Book:Add, Edit, x16 y60 w330 h20 vURL, %URL%

	Gui, Book:Add, Edit, x6 y95 w616 h230 0x40000 -Wrap vDelList hwndhDelListEdit, %DelList%

	Gui, Book:Add, Button, x454 y60 w170 h30 gEditBookInfo vCleanLastModified, ���������ʱ��(&T)
	Gui, Book:Add, Button, x524 y20 w100 h30 gEditBookInfo vShortAndSave, ���ʲ�����(&E)
	Gui, Book:Add, Button, x363 y19 w80 h30 gEditBookInfo vShortingStr, ����(&F)
	Gui, Book:Add, Button, x364 y60 w80 h30 gEditBookInfo vCleanDelList, ���(&C)
	Gui, Book:Add, Button, x453 y19 w65 h30 gEditBookInfo vSaveBookInfo, ����(&S)
	Gui, Book:show, w630 h330, �༭����

	EditJump2End(hDelListEdit) ; ��ת��Edit���

	Guicontrol, Book:Focus, URL
return

EditJump2End(hEdit)  ; ��ת��Edit���
{
	SendMessage 0xBA,0,0,,ahk_id %hEdit%
	LineCount := ErrorLevel
	SendMessage 0xB6,0,LineCount,,ahk_id %hEdit%
}

SimplifyDelList(DelList, nLastItem=9) ; ������ɾ���б�
{
	StringReplace, DelList, DelList, `r, , A
	StringReplace, DelList, DelList, `n`n, `n, A
	StringReplace, tmpss, DelList, `n, , UseErrorLevel
	linenum := ErrorLevel , tmpss := ""
	if ( linenum < ( nLastItem + 2 ) )
		return, DelList
	
	MaxLineCount := linenum - nLastItem
	NewList := ""
	recCount := 0
	loop, parse, DelList, `n, %A_space%
	{
		if ( instr(A_LoopField, "|") ) {
			++recCount
			if ( recCount > MaxLineCount ) {
				NewList .= A_loopfield . "`n"
			}
		}
	}
	return, NewList
}

EditBookInfo:
	If ( A_GuiControl = "SearchNovel" ) {
		guicontrolget, BookName
		guicontrolget, URL
		TypeCC := ""
		if instr(URL, ".qidian.")
			TypeCC := 1
		ifExist, D:\bin\autohotkey\fox_scripts\novel\BookSearch.ahkl
			run, "D:\bin\autohotkey\fox_scripts\novel\BookSearch.ahkL" %BookName% %TypeCC%
		else
			run, BookSearch.exe BookSearch.ahk %BookName% %TypeCC%
	}
	If ( A_GuiControl = "CleanDelList" ) {
		guicontrol, , DelList
	}
	If ( A_GuiControl = "ShortingStr" or A_GuiControl = "ShortAndSave" ) {
		guicontrolget, DelList
		NewDelList := SimplifyDelList(DelList) ; ������ɾ���б�
		guicontrol, , DelList, %NewDelList%
		NewDelList := "" , DelList := ""
		EditJump2End(hDelListEdit) ; ��ת��Edit���
	}
	If ( A_GuiControl = "GetQidianID" ) {
		guicontrolget, QidianID
		if ( QidianID = "" ) {
			if ( instr(Clipboard, ".qidian.") ) {
				QidianID = %Clipboard%
			} else {
				guicontrolget, BookName
				iJson := oBook.DownURL(qidian_getSearchURL_Mobile(GeneralW_UTF8_UrlEncode(GeneralW_StrToUTF8(bookname))), "", "<useUTF8>")
				qdid_1 := ""
				regexmatch(iJson, "Ui)""ListSearchBooks"":\[{""BookId"":([0-9]+),""BookName"":""" . bookname . """", qdid_)
				guicontrol, , QidianID, %qdid_1%
			}
		}
		if instr(QidianID, ".qidian.")
			guicontrol, , QidianID, % qidian_getBookID_FromURL(QidianID)
	}
	If ( A_GuiControl = "SaveBookInfo" or A_GuiControl = "ShortAndSave" ) {
		Gui, Book:Submit
		Gui, Book:Destroy
		oDB.EscapeStr(DelList)
		if BookID is integer
			oDB.Exec("update Book set Name='" . BookName . "' , URL='" . URL . "' , QiDianID='" . QiDianID . "' , DelURL=" . DelList . " , LastModified='' where ID = " . BookID)
	}
	If ( A_GuiControl = "CleanLastModified" ) {
		guicontrolget, BookID
		if BookID is integer
			oDB.Exec("update Book set LastModified='' where ID = " . BookID)
	}
return

BookGuiClose:
BookGuiEscape:
	Gui, Book:Destroy
return

; --------
PageMenuBarAct:
	if ( A_ThisMenuItem = "���ڸ���(&C)" )
		gosub, CopyWinInfo
	if ( A_ThisMenuItem = "��ȡ�б�(&I)" )
		gosub, GetTmpIndex
	if ( A_ThisMenuItem = "��ȡ����(&N)" )
		gosub, GetTmpNR
	if ( A_ThisMenuItem = "��������(&R)" )
		gosub, ProcTmpNR
return

TmpSiteCheck:
	Menu, TmpSite, Uncheck, �ٶ�����`tAlt+1
	Menu, TmpSite, Uncheck, ������`tAlt+2
	if ( A_ThisMenuItem = "�ٶ�����`tAlt+1" ) {
		Menu, TmpSite, check, �ٶ�����`tAlt+1
		NowSite := "tieba"
	}
	if ( A_ThisMenuItem = "������`tAlt+2" ) {
		Menu, TmpSite, check, ������`tAlt+2
		NowSite := "8shu"
	}
return

PageGUICreate:
	Gui, Page:New, +HwndhPage
	Menu, PageMenuBar, Add, ���ڸ���(&C), PageMenuBarAct
	Menu, PageMenuBar, Add, ��������, PageMenuBarAct

	Menu, TmpSite, Add, �ٶ�����`tAlt+1, TmpSiteCheck
	if ( NowSite = "" )
		NowSite := "tieba"
	Menu, TmpSite, Add, ������`tAlt+2, TmpSiteCheck
	Menu, PageMenuBar, Add, ��վ����(&T), :TmpSite

	Menu, PageMenuBar, Add, ������, PageMenuBarAct
	Menu, PageMenuBar, Add, ��ȡ�б�(&I), PageMenuBarAct
	Menu, PageMenuBar, Add, ��ȡ����(&N), PageMenuBarAct
	Menu, PageMenuBar, Add, ����, PageMenuBarAct
	Menu, PageMenuBar, Add, ��������(&R), PageMenuBarAct
	Gui, Page:Menu, PageMenuBar

	Gui, Page:Add, GroupBox, x6 y10 w620 h80 cBlue, PageID | BookID | Name | URL | CharCount | Mark || TmpURL | PageFilter || Content
	Gui, Page:Add, Button, x536 y3 w80 h20 gCopyWinInfo vBtnCopyWinInfo, ���ڸ���(&C)
	Gui, Page:Add, Edit, x16 y30 w40 h20 disabled vPageID, %PageID%
	Gui, Page:Add, Edit, x56 y30 w40 h20 vBookID, %BookID%
	Gui, Page:Add, Edit, x96 y30 w210 h20 vPageName, %PageName%
	Gui, Page:Add, Edit, x306 y30 w140 h20 vPageURL, %PageURL%
	Gui, Page:Add, Edit, x446 y30 w40 h20 vCharCount, %CharCount%
	Gui, Page:Add, Edit, x486 y30 w40 h20 vPageMark, %Mark%

	Gui, Page:Add, Button, x536 y30 w80 h50 gSavePageInfo vSavePageInfo, ����(&S)

	Gui, Page:Add, checkbox, x16 y60 w40 h20 vCKbGood +checked0, ��&H
	Gui, Page:Add, Checkbox, x54 y60 w40 h20 vCKPage2, &P2
	Gui, Page:Add, Button, x94 y60 w20 h20 gGetTmpIndex vBtnTmpIndex, I
	Gui, Page:Add, ComboBox, x114 y60 w210 R10 vTmpURL choose1, %NowIndexURL%
	Gui, Page:Add, ComboBox, x354 y60 w120 R10 vPageFilter
	Gui, Page:Add, Button, x324 y60 w20 h20 gGetTmpNR vBtnTmpNR, N
	Gui, Page:Add, Button, x484 y60 w50 h20 gProcTmpNR vContProc, R

	Gui, Page:Add, ListView, x6 y100 w620 h270 vTieBaLV gSelectTieZi, Name|URL
	LV_ModifyCol(1, 350), LV_ModifyCol(2, 240)
	Gui, Page:Font, s12 , Fixedsys
	Gui, Page:Add, Edit, x6 y100 w620 h270 vContent , %Content%
	Gui, Page:Font
	; Generated using SmartGUI Creator 4.0
	GuiControl, Hide, TieBaLV
	Gui, Page:Show, h380 w630, �޸��½���Ϣ

	WinGet, TmpList, List, �޸��½���Ϣ ahk_class AutoHotkeyGUI
	if ( TmpList = 2 )
		GuiControl, Focus, BtnCopyWinInfo
	else
		GuiControl, Focus, BtnTmpIndex
Return


CopyWinInfo: ; ������һ��������Ϣ
	WinGet, TmpList, List, �޸��½���Ϣ ahk_class AutoHotkeyGUI
	if ( TmpList != 2 ) {
		TrayTip, ��ʾ, ������������`n����: %TmpList%
		return
	}
	if ( hPage = TmpList1 )
		hOtherPage := TmpList2
	else
		hOtherPage := TmpList1
	ControlGetText, TmpTitle, Edit3, ahk_id %hOtherPage%
	ControlGetText, TmpNR, Edit9, ahk_id %hOtherPage%
	Guicontrol, , PageName, %TmpTitle%
	Guicontrol, , Content, %TmpNR%
	TmpNR := "" , TmpTitle := ""
return

GetTmpIndex:  ; ��ȡ�����б�
	Gui, Page:submit, nohide
	oBook.GetBookInfo(BookID)
	NowBookName := oBook.Book["Name"]

	if ( NowSite = "tieba" or NowSite = "8shu" ) {
		if ( NowSite = "tieba" ) {
		stringreplace, NowBookName, NowBookName, ̨��, , A
		if ( CKbGood = 1 ) {
			NowIndexURL := "http://tieba.baidu.com/f?kw=" . NowBookName . "&ie=utf-8&tab=good"
			tmphtml := FoxSet["Tmpdir"] . "\good_" . NowBookName . ".bdlist"
		} else {
			NowIndexURL := "http://tieba.baidu.com/f?kw=" . NowBookName . "&ie=utf-8"
			tmphtml := FoxSet["Tmpdir"] . "\tieba_" . NowBookName . ".bdlist"
		}

		IfNotExist, %tmphtml%
			runwait, wget.exe "%NowIndexURL%" -O %tmphtml%, %A_scriptdir%\bin32
		FileRead, html, *P65001 %tmphtml%
		if ! instr(html, "</html>") ; δ��������ɾ��
			FileDelete, %tmphtml%
		oIndex := getTieBaList(html)
		}
		if ( NowSite = "8shu" ) {
			NowIndexURL := "http://www.8shu.net/search.php?w=" . GeneralW_UTF8_UrlEncode(GeneralW_StrToUTF8(NowBookName))
			tmphtml := FoxSet["Tmpdir"] . "\8shu_" . NowBookName . ".bdlist"
			IfNotExist, %tmphtml%
				runwait, wget.exe "%NowIndexURL%" -O %tmphtml%, %A_scriptdir%\bin32
			FileRead, html, *P65001 %tmphtml%
			if ! instr(html, "</html>") ; δ��������ɾ��
				FileDelete, %tmphtml%
			oIndex := get8shuList(html)
		}
	}

	Guicontrol, text, TmpURL, %NowIndexURL%
	Guicontrol, , TmpURL, %NowIndexURL%
	Guicontrol, Hide, Content
	Guicontrol, Show, TieBaLV
	
	loop, % oIndex.MaxIndex()
		LV_Add("", oIndex[A_index,2], oIndex[A_index,1])
	LV_ModifyCol(2, "SortDesc")

	if ( PageName = "" )
		GuiControl, Focus, TieBaLV
	else {
		GuiControl, , PageFilter, %PageName%
		TmpNamexkd := GetTitleKeyWord(PageName, 1)
		if ( TmpNamexkd != "" )
			GuiControl, text, PageFilter, %TmpNamexkd% ; �����ı�Ϊ��һ�ֶΣ�һ��Ϊxxx��
		GuiControl, Focus, PageFilter
	}
return

SelectTiezi:
	if ( A_GuiEvent = "DoubleClick" ) { ; ˫����Ŀ����ȡ������ַ
		NowRowNum := A_EventInfo
		LV_GetText(NowTitle, NowRowNum, 1)
		LV_GetText(NowURL, NowRowNum, 2)
		Guicontrol, hide, TieBaLV
		Guicontrol, show, Content
		NowFullURL := GetFullURL(NowURL, NowIndexURL)
		Guicontrol, text, TmpURL, %NowFullURL%
		Guicontrol, , PageName, %NowTitle%
		GuiControl, Focus, BtnTmpNR
	}
return


FilterTmpList: ; �����б�
	GuiControlGet, PageFilter
	LV_Delete()
	loop, % oIndex.MaxIndex()
	{
		if instr(oIndex[A_index,1], PageFilter)
		{
			LV_Add("", oIndex[A_index,1], oIndex[A_index,2])
		} else {
			if ( PageFilter = "" )
				LV_Add("", oIndex[A_index,1], oIndex[A_index,2])
		}
	}
	GuiControl, Focus, TieBaLV
return

GetTmpNR:  ; ��ȡ����
	Gui, Page:submit, nohide
	if instr(TmpURL, ".baidu.")
	{
		tmphtml := FoxSet["Tmpdir"] . "\TieBa_" . A_TickCount . ".html"
		runwait, wget.exe -O %tmphtml% %TmpURL%, %A_scriptdir%\bin32
		FileRead, html, *P65001 %tmphtml%
		FileDelete, %tmphtml%
		GuiControl, , Content, % tiezi_process(html)
		GuiControl, Focus, Content
	}
	if instr(TmpURL, ".8shu.") {
		tmphtml := FoxSet["Tmpdir"] . "\8shu_" . A_TickCount . ".html"
		runwait, wget.exe -O %tmphtml% %TmpURL%, %A_scriptdir%\bin32
		FileRead, html, *P65001 %tmphtml%
		FileDelete, %tmphtml%
		GuiControl, , Content, % pro8shu(html)
		GuiControl, Focus, Content
	}
return

ProcTmpNR: ; �����ı�
	GuiControlGet, NowContent, , Content
	GuiControl, , Content, % ProcTxtNR(NowContent)
return

ProcTxtNR(SrcTxt="")
{
	stringreplace, SrcTxt, SrcTxt, `r, , A
	stringreplace, SrcTxt, SrcTxt, `n`n, `n, A
	stringreplace, SrcTxt, SrcTxt, ��, , A
	stringreplace, SrcTxt, SrcTxt, `n%A_space%, `n, A
	NewContent := ""
	loop, parse, SrcTxt, `n, `r
		NewContent .= RegExReplace(A_loopfield, "i)^[""�� ��]*") . "`n"
	stringreplace, NewContent, NewContent, `n`n, `n, A
	loop, 5 {  ; ȥ��ͷ���س���
		stringleft, HeadChar, NewContent, 1
		if ( HeadChar= "`n" or HeadChar = "`r" )
			StringTrimLeft, NewContent, NewContent, 1
	}
	return, NewContent
}

SavePageInfo:  ; �������ݵ����ݿ�
	Gui, Page:Submit
	Gui, Page:Destroy
	CharCount := strlen(Content) ; �������ݳ���
	if ( PageMark = "" or PageMark = "text" or PageMark = "image" ) {  ; С˵ʱ �²��½�����
		if ( PageMark = "image" )
			DelOldImage := 1
		If instr(Content, ".gif|")
		{
			PageMark := "image"
		} else {
			PageMark := "text"
			if Content contains html>,<body,<br>,<p>,<div>
				PageMark := "html"
		}
	}
	If ( PageMark != "image" and DelOldImage = 1 )
		FileDelete, % oBook.PicDir . "\" . BookID . "\" . PageID . "_*" ; ���±���ʱ��ɾ�����ܴ��ڵ�ͼƬ�ļ�
	
	oDB.EscapeStr(Content)
	if PageID is integer
		oDB.Exec("update Page set BookID=" . BookID . ", Name='" . PageName . "', URL='" . PageURL . "', CharCount=" . CharCount . ", Mark='" . PageMark . "', Content=" . Content . " where ID = " . PageID)
return

get8shuList(html)
{
	LV_Delete()
	oIndex := []   ; ����,URL
	oIndexCount := 0

	xx_1 := ""
	regexmatch(html, "smUi)id=""Tbs""[^>]*>(.*)</table>", xx_)
	loop, parse, xx_1, `n, `r
	{
		xx_1 := "" , xx_2 := "", xx_3 := ""
		regexmatch(A_loopfield, "Ui)<tr><td>.*</td>.*<td>.*<a[^>]*>([^<]*)<.*</td>.*<td>.*href=""([^""]*)"".*</td>.*<td><[^>]*>(.*)<[^>]*>.*</td>.*<td>.*</td>.*<td>.*</td></tr>", xx_)
		if ( xx_1 != "" ) {
			++oIndexCount
			oIndex[oIndexCount,1] := "http://www.8shu.net" . xx_2
			oIndex[oIndexCount,2] := xx_1 . A_space . xx_3
		}
	}
	return, oIndex
}

GetTieBaList(html)
{
	stringreplace, html, html, `r, , A
	stringreplace, html, html, `n, , A
	stringreplace, html, html, <a, `n<a, A
	LV_Delete()
	oIndex := []   ; ����,URL
	oIndexCount := 0
	loop, parse, html, `n, `r
	{
		if ! instr(A_loopfield, "class=""j_th_tit")
			continue
		FF_1 := "" , FF_2 := ""
		RegExMatch(A_loopfield, "Ui)<a href=""([^""]+)"".*""j_th_tit[ ]*"">([^<]+)</a>", FF_)
		if ( FF_2 != "" ) {
			++oIndexCount
			oIndex[oIndexCount,1] := "http://tieba.baidu.com" . FF_1
			oIndex[oIndexCount,2] := FF_2
		}
	}
	return, oIndex
}

pro8shu(html) { ; 8shu���մ���
	stringreplace, html, html, `n, , A
	stringreplace, html, html, `r, , A
	stringreplace, html, html, <br/>, `n, A
	stringreplace, html, html, &nbsp`;, , A
	stringreplace, html, html, `n`n, `n, A
	regexmatch(html, "smUi)id=""kz_content"">(.*)</div></td>", xx_)
	return, xx_1
}
tiezi_process(html) { ; �ٶ��������Ӵ���
	StringReplace, html, html, `r, , A
	StringReplace, html, html, `n, , A
	StringReplace, html, html, <div class="louzhubiaoshi_wrap">, `n<div class="louzhubiaoshi_wrap">, A
	NewContent := ""
	loop, parse, html, `n, `r
	{
		if ! instr(A_loopfield, "<div class=""louzhubiaoshi_wrap"">")   ; ���˷�¥���ķ���
			continue
		XX_1 := ""
		RegExMatch(A_loopfield, "Ui)<cc>(.*)</cc>", XX_)
		NewContent .= XX_1 . "`n�����������������������������`n"
	}
	StringReplace, NewContent, NewContent, <br><br><br>, `n, A
	StringReplace, NewContent, NewContent, <br><br>, `n, A
	StringReplace, NewContent, NewContent, <br>, `n, A
	NewContent := RegExReplace(NewContent, "Ui)<[^>]+>", "") ; ɾ�� html��ǩ

	regexmatch(NewContent, "si)^(.*[\-\=_��]{5,})[^\-\=]*", adHead_)
	regexmatch(NewContent, "si)([\(��]?δ�����.*)$", adFoot_)
	aa := strlen(adHead_1)
	bb := strlen(adfoot_1)
	if ( ( aa > 0 and aa < 800 ) or ( bb > 0 and bb < 800 ) ) {
		if (aa > 800)
			adHead_1 := "ͷ������800�ַ�"
		if (bb > 800)
			adfoot_1 := "β������800�ַ�"
		msgbox, 4, �Զ�������, ��Ҫ�Զ��������������ַ���ô`n<%adHead_1%>`n<%adfoot_1%>
		ifmsgbox, yes
		{
			stringreplace, NewContent, NewContent, %adHead_1%, , A
			stringreplace, NewContent, NewContent, %adFoot_1%, , A
		}
	}
	return, NewContent
}

PageGuiClose:
PageGuiEscape:
	Gui, Page:Destroy
return

; --------
FaRGUICreate:
	Gui, FaR:New
	Gui, FaR:Add, ComboBox, x106 y10 w150 h20 Simple R9 vFindStr, ��|С˵|�ִ�|����|�ٶ�|Сʱ|com|��|��|��|xing
	Gui, FaR:Add, Button, x6 y10 w90 h30 vFindPageStr gFaRPageStr Default, ����(&F)
	Gui, FaR:Add, Button, x6 y50 w90 h30 vReplacePageStr gFaRPageStr, �滻(&R)
	Gui, FaR:Add, Edit, x6 y90 w90 h50 vReplaceStr
	; Generated using SmartGUI Creator 4.0
	Gui, FaR:Show, h152 w265, �����ֶ� ���� / �滻
Return

FaRPageStr:
	Gui, FaR:Submit
	LastControl := A_GuiControl
	Gui, FaR:Destroy
	Gui, 1:Default
	oLVDown.Switch()
	oLVDown.ReGenTitle()
	oLVDown.Clean()
	oDB.GetTable("select page.name, page.CharCount, book.name, page.ID from book,Page where book.id=page.bookid and page.content like '%" . FindStr . "%' order by page.ID ", oTable)
	oLVDown.Switch()
	If ( LastControl = "FindPageStr" ) {
		loop, % oTable.rowcount
			LV_Add("",oTable.Rows[A_index][1],oTable.Rows[A_index][2],oTable.Rows[A_index][3],oTable.Rows[A_index][4])
	}
	If ( LastControl = "ReplacePageStr" ) {
		odb.Exec("BEGIN;")
		loop, % oTable.rowcount
		{
			SB_SetText("�滻�ַ���: (" . FindStr  . " -> " . ReplaceStr . ")  ����: " . A_index . " / " . oTable.rowcount)
			LV_Add("",oTable.Rows[A_index][1],oTable.Rows[A_index][2],oTable.Rows[A_index][3],oTable.Rows[A_index][4])
			NowPageID := oTable.Rows[A_index][4]
			oDB.GetTable("select Content from page where ID =" . NowPageID, oXX)
			NowContent := oXX.rows[1,1]
			stringreplace, NowContent, NowContent, %FindStr%, %ReplaceStr%, A
			odb.EscapeStr(NowContent)
			odb.Exec("update page set Content = " . NowContent . " where id=" . NowPageID)
		}
		odb.Exec("COMMIT;")
	}
	oLVDown.Switch()
	LV_Modify(LV_GetCount(), "Vis") ; Jump2Last
return

FaRGuiClose:
FaRGuiEscape:
	Gui, FaR:Destroy
return
; --------
CfgGUICreate:
	Gui, Cfg:New
	Gui, Cfg:Add, GroupBox, x6 y10 w240 h50 cBlue, ID|URL
	Gui, Cfg:Add, Edit, x16 y30 w40 h20 disabled vCfgID, 0
	Gui, Cfg:Add, Edit, x56 y30 w180 h20 vCFGURL, biquge

	Gui, Cfg:Add, Button, x256 y20 w80 h30 vCFGSave gEditCfgInfo, ����(&S)

	Gui, Cfg:Add, GroupBox, x6 y70 w160 h160 cBlue, Index RE|DelStr
	Gui, Cfg:Add, Edit, x16 y90 w140 h20 vIndexRE
	Gui, Cfg:Add, Edit, x16 y120 w140 h100 vIndexDelStr
	Gui, Cfg:Add, GroupBox, x176 y70 w160 h160 cBlue, Page RE|DelStr
	Gui, Cfg:Add, Edit, x186 y90 w140 h20 vPageRE
	Gui, Cfg:Add, Edit, x186 y120 w140 h100 vPageDelStr
	Gui, Cfg:Add, GroupBox, x6 y240 w330 h120 cBlue, Cookie
	Gui, Cfg:Add, Edit, x16 y260 w310 h90 vConfigCookie
	; Generated using SmartGUI Creator 4.0
	Gui, Cfg:Show, h372 w349, ��վ��������
;	GuiControl, Cfg:Focus, CFGURL
Return

EditCfgInfo:
	Gui, Cfg:Submit
	oDB.EscapeStr(IndexRE)
	oDB.EscapeStr(IndexDelStr)
	oDB.EscapeStr(PageRE)
	oDB.EscapeStr(PageDelStr)
	oDB.EscapeStr(ConfigCookie)
	oDB.Exec("update config set ListRangeRE=" . IndexRE . " , ListDelStrList=" . IndexDelStr . " , PageRangeRE=" . PageRE . " , PageDelStrList=" . PageDelStr 
	. " , cookie=" . ConfigCookie
	. " where ID = " . CfgID)
	Gui, Cfg:Destroy
return

CfgGuiClose:
CfgGuiEscape:
	Gui, Cfg:Destroy
return
; --------
IEGUICreate:
	if ( General_getOSVersion() > 6.1 ) {
		yPos := 90
		IEHeight := A_ScreenHeight - 100
	} else {
		yPos := 26
		IEHeight := A_ScreenHeight - 30
	}
	Gui, IE:New, +HWNDhIE
	GUi, IE:+Resize ; +HWNDWinIE; ���� GUI
	Gui, IE:Add, ActiveX, x0 y0 w%A_ScreenWidth% h%IEHeight% vPWeb hwndPCTN, Shell.Explorer
	pWeb.Navigate("about:blank")
	Gui, IE:Show, y%yPos%, FoxIE L
return

IEGuiSize:
	guicontrol, move, PWeb, w%A_GuiWidth% h%A_GuiHeight%
return

IEGuiClose:
IEGuiEscape:
	Gui, IE:Destroy
return
; --------

GuiClose:
GuiEscape:
FoxExitApp:
	if bMemDB
	{
		Gui, Destroy
		FoxMemDB(oDB, DBPath, "Mem2File") ; Mem -> DB
	}
	oDB.CloseDB()
	filedelete, % FoxSet["Tmpdir"] . "\*.bdlist" ; �ٶ������б�
	WinGet, TmpList, List, FoxBook ahk_class AutoHotkeyGUI
	if ( TmpList = 0 ) { ; ���0�ֽ��ļ����հ�Ŀ¼
		loop, % FoxSet["Tmpdir"] . "\*", 0, 1
			if ( A_LoopFileSize = 0 )
				FileDelete, %A_LoopFileFullPath%
		loop, % FoxSet["Tmpdir"] . "\*", 2, 1
			FileRemoveDir, %A_LoopFileFullPath%
		FileRemoveDir, % FoxSet["Tmpdir"]
	}
	ExitApp
return

FoxReload:
	if bMemDB
	{
		Gui, Destroy
		FoxMemDB(oDB, DBPath, "Mem2File") ; Mem -> DB
	}
	oDB.CloseDB()
	reload
return

FoxSwitchDB:  ; �л����ݿ�
	if bMemDB
		FoxMemDB(oDB, DBPath, "Mem2File") ; Mem -> DB
	oDB.CloseDB()

	dbList := getDBList(A_Scriptdir)
	countDBs := dbList.MaxIndex()
    ++nowDBnum
	if ( nowDBnum > countDBs )
		nowDBnum := 1
	DBPath := dbList[nowDBnum]

	if bMemDB
	{
		oDB.OpenDB(":memory:")
		FoxMemDB(oDB, DBPath, "File2Mem")
	} else
		oDB.OpenDB(DBPath)
	SB_settext("�л�Ϊ: " . DBPath)

	FoxCompSiteType := getCompSiteType(oDB)
	oBook.ShowBookList(oLVBook)
return

getDBList(DBDir="") ; ��ȡ���ݿ��б�
{
	DBList := []
	DBList[1] := DBDir . "\FoxBook.db3" ; Ĭ��·��
	cDB := 1
	loop, %DBDir%\*.db3
	{
		if ( A_LoopFileName != "FoxBook.db3" ) {
			++cDB
			DBList[cDB] := A_LoopFileFullPath
		}
	}
	return, DBList
}

MenuInit: ; �˵���
; -- �˵�: �鼮
	aSTran := Array("ѡ���鼮����PDF" , "ѡ���鼮����Mobi" , "ѡ���鼮����Epub" , "ѡ���鼮����CHM" , "ѡ���鼮����UMD" , "ѡ���鼮����Txt")
	MenuInit_tpl(aSTran, "TransBookMenu", "BookMenuAct")
	Menu, BookMenu, Add, ѡ���鼮ת����ʽ, :TransBookMenu

	aSSearch := Array("�����鼮_���" , "�����鼮_PaiTXT" , "�����鼮_��Ҷ�")
	MenuInit_tpl(aSSearch, "SearchBookMenu", "BookMenuAct")
	Menu, BookMenu, Add, �����鼮, :SearchBookMenu

	aBM := Array("-", "ˢ����ʾ�б�" , "д�뵱ǰ��ʾ˳��" , "-" , "���LastModified" , "�����ɾ���б�" , "��ʾ��ɾ���б�(&D)" , "-"
	, "��������Ŀ¼" , "��������" , "ֹͣ(&S)" , "-"
	, "���±���(&G)" , "���±���Ŀ¼(&T)", "����������鼮`tAlt+D" , "��ʾ��������б�(&Q)" , "-"
	, "�����鼮(&N)", "�༭������Ϣ(&E)", "ɾ������", "-", "��ӿհ��½�(&C)", "�������TXT", "-", "���: ��������", "���: ���ٸ���", "���: ����")
	MenuInit_tpl(aBM, "BookMenu", "BookMenuAct")

	Menu, MyMenuBar, Add, �鼮(&B), :BookMenu
; -- �˵�: ҳ��
	aPTran := Array("ѡ���½�����PDF" , "ѡ���½�����Mobi" , "ѡ���½�����Epub" , "ѡ���½�����CHM" , "ѡ���½�����UMD" , "ѡ���½�����Txt")
	MenuInit_tpl(aPTran, "TransPageMenu", "PageMenuAct")
	Menu, PageMenu, Add, ѡ���½�ת����ʽ, :TransPageMenu

	aPMain := Array("-", "ɾ��ѡ���½�[д���Ѷ��б�](&D)", "ɾ��ѡ���½�[��д���Ѷ��б�](&B)", "-", "������ѡ���½�ID(&W)", "-", "��Ǳ��½�����Ϊtext", "��Ǳ��½�����Ϊimage", "��Ǳ��½�����Ϊhtml", "-", "���±�������(&G)", "�༭������Ϣ(&E)", "-", "�����������½�(&C)", "���ͱ������ݵ���һ����(&S)")
	MenuInit_tpl(aPMain, "PageMenu", "PageMenuAct")
	Menu, MyMenuBar, Add, ҳ��(&X), :PageMenu
; -- �˵�: ����
	aSMain := Array("PDFͼƬ(����):�и�Ϊ�ֻ�:285*380", "PDFͼƬ(����):�и�ΪK3:530*700", "PDFͼƬ(����):ת��", "-"
	, "ͼƬ(�ļ�):�и�:270*360(�ֻ�)", "ͼƬ(�ļ�):�и�:530*665(K3_Mobi)", "ͼƬ(�ļ�):�и�:580*750(K3_Epub)", "-"
	, "�Ƚ�:���", "�Ƚ�:��Ҷ�", "�Ƚ�:PaiTxt", "�Ƚ�:13xs", "�Ƚ�:��Ȥ��", "-"
	, "������:����", "������:wget", "������:curl", "-" , "����:Sqlite", "����:INI", "-"
	, "�鿴��:IE�ؼ�", "�鿴��:IE", "�鿴��:AHK_Edit")
	MenuInit_tpl(aSMain, "dMenu", "SetMenuAct")
	Menu, MyMenuBar, Add, ����(&Y), :dMenu
; -- �˵�: ���ݿ�
	aDBMain := Array("���鼮ҳ����������", "���鼮ҳ��˳������", "��������ҳ��ID", "���������鼮ID", "��������DelList", "-"
	, "�༭������Ϣ(&E)", "����Ҫִ�е�SQL", "-"
	, "��ʾ����ĸ��¼�¼", "��ʾ�����½ڼ�¼`tAlt+A", "��ʾ����image�½�`tAlt+G", "��ʾ����text�½�`tAlt+T", "��ʾ����ͬURL�½�`tCtrl+U", "-"
	, "�����ݿ�`tAlt+O", "�������ݿ�", "�л����ݿ�`tAlt+S", "-", "�����鼮�б�������", "����QidianID��SQL��������", "-", "��ݵ���`tAlt+E", "���˳��`tAlt+W")
	MenuInit_tpl(aDBMain, "DbMenu", "DBMenuAct")
	Menu, MyMenuBar, Add, ���ݿ�(&Z), :DbMenu

; -- �˵�: ������Ŀ
	Menu, MyMenuBar, Add, ��, DBMenuAct
	Menu, MyMenuBar, Add, ˳��(&W), DBMenuAct
	Menu, MyMenuBar, Add, ����(&E), DBMenuAct
;	Menu, MyMenuBar, Add, ����(&L), DBMenuAct
	Menu, MyMenuBar, Add, �л�(&S), QuickMenuAct
	Menu, MyMenuBar, Add, ����, DBMenuAct
	Menu, MyMenuBar, Add, �Ƚ�(&C), QuickMenuAct
	Menu, MyMenuBar, Add, �Ƚϲ�����, BookMenuAct
	Menu, MyMenuBar, Add, ������, DBMenuAct
	Menu, MyMenuBar, Add, &Mobi(K3), QuickMenuAct
	Menu, MyMenuBar, Add, &UMD(�ֻ�), QuickMenuAct
	Gui, Menu, MyMenuBar
return
MenuInit_tpl(inArray, menuName, menuActName)
{
	Loop % inArray.MaxIndex()
	{
		if ( "-" = inArray[A_index])
			Menu, %menuName%, Add
		else
			Menu, %menuName%, Add, % inArray[A_index], %menuActName%
	}
}


QuickMenuAct:
	if ( A_ThisMenuItem = "�л�(&S)" )
		gosub, FoxSwitchDB
;	if ( A_ThisMenuItem = "����(&W)" ) gosub, FoxReload
	If ( A_ThisMenuItem = "�Ƚ�(&C)" or NowInCMD = "CompareAndDown" ) {
		bNoSwitchLV := 1
		oLVComp.ReGenTitle(1)
		oLVComp.Clean()

		if (FoxCompSiteType = "qidian") {
			oDB.gettable("select ID, Name, QidianID from book where ( isEnd isnull or isEnd <> 1 ) and URL not like '%qidian%' order by DisOrder", oOldBookList)
			oCOMInfo := []
			oldDownMode := oBook.DownMode
			oBook.DownMode := "curl"
			loop, % oOldBookList.RowCount
			{
				oCOMInfo[A_index,1] := oOldBookList.rows[A_index][2]
				NowURL := qidian_getIndexURL_Desk(oOldBookList.rows[A_index][3])
				SavePath := FoxSet["Tmpdir"] . "\QD_" . A_TickCount . ".gif" ; ����ɾ����Ҫ��ȡUTF-8
				SB_settext("�Ƚ����: ����: " . A_index . " / " . oOldBookList.RowCount . " : " . oCOMInfo[A_index,1] . "  : " . NowURL)
				oBook.DownURL(NowURL, SavePath, "-r -7000") ; ����URL, ����ֵΪ����
				Fileread, html, *P65001 %SavePath%
				FileDelete, %SavePath%
				FF_1 := "" , FF_2 := ""
				regexmatch(html, "smi)href=""(.*)""[^>]*>([^<]*)<.*<div class=""book_opt"">", FF_)
				oCOMInfo[A_index,2] := FF_2
			}
			oBook.DownMode := OldDownMode
		} else {
			oCOMInfo := oBook.GetSiteBookList(FoxCompSiteType) ; ��ȡ��վ�����Ϣ
		}
		oDB.gettable("select ID, Name from book where ( isEnd isnull or isEnd <> 1 ) order by DisOrder", oOldBookList) ; and URL not like '%qidian%' 
		LV_Colors.Detach(hLVPage)
		LV_Colors.Attach(hLVPage, 0, 0)
		loop, % oOldBookList.RowCount
		{
			NowBookID := oOldBookList.rows[A_index][1] , NowBookName := oOldBookList.rows[A_index][2]
			oDB.GetTable("select ID,Name from page where BookID=" . NowBookID " order by ID DESC limit 1", oTmpPage)
			if ( oTmpPage.rowcount = 0 ) {
				NowPageID := "�Ѷ�"
				oBook.GetBookInfo(NowBookID)
				NowBookDelList := oBook.Book["DelList"]
				stringreplace, NowBookDelList, NowBookDelList, `n`n, `n, A
				loop, parse, NowBookDelList, `n, `r
				{
					if ( A_loopfield = "" )
						continue
					tmpLastLine = %A_loopfield%
				}
				FF_1 := ""
				stringsplit, FF_, tmpLastLine, |
				NowOldPageName := FF_2
			} else {
				NowPageID := oTmpPage.rows[1][1] , NowOldPageName := oTmpPage.rows[1][2]
			}
			NowNewPageName := ""
			loop, % oCOMInfo.MaxIndex()
			{
				if ( oCOMInfo[A_index,1] = NowBookName ) {
					NowNewPageName := oCOMInfo[A_index,2]
					NowNewPageURL := oCOMInfo[A_index,3]
					break
				}
			}
			if ( NowNewPageName = "" )
				NowNewPageName := "��"
			if ( NowInCMD != "CompareAndDown" )
				LV_Add("", NowOldPageName, NowNewPageName, NowBookName, NowPageID, NowNewPageURL)
			stringreplace, XXOldPageName, NowOldPageName, %A_space%, , A
			stringreplace, XXOldPageName, XXOldPageName, T, , A
			stringreplace, XXOldPageName, XXOldPageName, ., , A
			stringreplace, XXOldPageName, XXOldPageName, ��, , A
			stringreplace, XXNewPageName, NowNewPageName, %A_space%, , A
			stringreplace, XXNewPageName, XXNewPageName, T, , A
			stringreplace, XXNewPageName, XXNewPageName, ., , A
			stringreplace, XXNewPageName, XXNewPageName, ��, , A
			if ( XXOldPageName != XXNewPageName ) {
				if ( NowInCMD = "CompareAndDown" ) {
					oBook.MainMode := "reader"
					oBook.SBMSG := ""
					oBook.UpdateBook(NowBookID, oLVBook, oLVPage, oLVDown, -9)
				} else {
					LV_Colors.Row(hLVPage, A_index, "", 0x0000FF) ; ��ɫ:�½�����ͬ
				}
			}
		}
		bNoSwitchLV := 0
		SB_settext("�Ƚ����[����]���!")
	}
	If A_ThisMenuItem in &Epub(K3),&UMD(�ֻ�),PDF(�ֻ�),&Mobi(K3),&PDF(K3)
	{
		NowInCMD := "ShowAll"  ; ��ʾ�����½ڣ���ȫѡ
		gosub, DBMenuAct
		Gui, ListView, LVPage
		LV_Modify(0, "Select")

		If ( A_ThisMenuItem = "&Epub(K3)" ) {
			oBook.ScreenWidth := 580 , oBook.ScreenHeight := 750  ; K3 Epub �и�ߴ�
			NowInCMD := "PageToEpub" ; ҳ������Epub
		}
		If ( A_ThisMenuItem = "PDF(�ֻ�)" ) {
			oBook.PDFGIFMode := "SplitPhone" ; PDFͼƬ:�и�Ϊ�ֻ�
			NowInCMD := "PageToPDF" ; ҳ������PDF
		}
		If ( A_ThisMenuItem = "&UMD(�ֻ�)" )
			NowInCMD := "PageToUMD" ; ҳ������UMD
		If ( A_ThisMenuItem = "&Mobi(K3)" ) {
			oBook.ScreenWidth := 530 , oBook.ScreenHeight := 665   ; K3 Mobi �и�ߴ�
			NowInCMD := "PageToMobi" ; ҳ������PDF
		}
		If ( A_ThisMenuItem = "&PDF(K3)" ) {
			oBook.PDFGIFMode := "SplitK3" ; PDFͼƬ:�и�ΪK3
			NowInCMD := "PageToPDF" ; ҳ������PDF
		}
		gosub, PageMenuAct
	}

	NowInCMD := ""
return

SettingMenuCheck:
	xx := Object("qidian", "�Ƚ�:���" , "dajiadu", "�Ƚ�:��Ҷ�" , "paiTxt", "�Ƚ�:PaiTxt" , "13xs", "�Ƚ�:13xs", "biquge", "�Ƚ�:��Ȥ��")
	SettingMenuCheck_tpl(xx, FoxCompSiteType, "dMenu")
	; ---
	xx := Object("270", "ͼƬ(�ļ�):�и�:270*360(�ֻ�)" , "530", "ͼƬ(�ļ�):�и�:530*665(K3_Mobi)" , "580", "ͼƬ(�ļ�):�и�:580*750(K3_Epub)")
	SettingMenuCheck_tpl(xx, oBook.ScreenWidth, "dMenu")
	; ---
	xx := Object("normal", "PDFͼƬ(����):ת��" , "SplitK3", "PDFͼƬ(����):�и�ΪK3:530*700" , "SplitPhone", "PDFͼƬ(����):�и�Ϊ�ֻ�:285*380")
	SettingMenuCheck_tpl(xx, oBook.PDFGIFMode, "dMenu")
	; ---
	xx := Object("BuildIn", "������:����" , "wget", "������:WGET" , "curl", "������:CURL")
	SettingMenuCheck_tpl(xx, oBook.DownMode, "dMenu")
	; ---
	xx := Object("IEControl", "�鿴��:IE�ؼ�" , "IE", "�鿴��:IE" , "BuildIn", "�鿴��:AHK_Edit")
	SettingMenuCheck_tpl(xx, oBook.ShowContentMode, "dMenu")
	; ---
	xx := Object("sqlite", "����:Sqlite" , "ini", "����:INI")
	SettingMenuCheck_tpl(xx, oBook.CFGMode, "dMenu")
return
SettingMenuCheck_tpl(hashmap, compareVar, menuName="dMenu")
{
	For sk, sv in hashmap {
		if ( compareVar = sk )
			Menu, %menuName%, check, %sv%
		else
			Menu, %menuName%, Uncheck, %sv%
	}
}

; }

; {
BookMenuAct:
	If ( A_ThisMenuItem = "����������鼮`tAlt+D" or A_ThisMenuItem = "�Ƚϲ�����" ) {
		NowInCMD := "CompareAndDown"
		gosub, QuickMenuAct
	}
	If ( A_ThisMenuItem = "���±���Ŀ¼(&T)" or A_ThisMenuItem = "���±���(&G)" ) {
		oLVBook.LastRowNum := oLVBook.GetOneSelect()
		NowBookID := oLVBook.GetOneSelect(3)
		If ( A_ThisMenuItem = "���±���Ŀ¼(&T)" )
			oBook.MainMode := "update"
		If ( A_ThisMenuItem = "���±���(&G)" )
			oBook.MainMode := "reader"
		oBook.SBMSG := ""
		bNoSwitchLV := 1
		oBook.UpdateBook(NowBookID, oLVBook, oLVPage, oLVDown, -9)
		bNoSwitchLV := 0
	}
	If ( A_ThisMenuItem = "��������" or A_ThisMenuItem = "��������Ŀ¼" or NowInCMD = "UpdateAll" ) {
		OldMainMode := oBook.MainMode
		If ( A_ThisMenuItem = "��������" or NowInCMD = "UpdateAll" )
			oBook.MainMode := "reader" ; ��������, Ӱ��������ģʽ
		If ( A_ThisMenuItem = "��������Ŀ¼" )
			oBook.MainMode := "update"
		oDB.gettable("select ID, Name from book where isEnd isnull or isEnd <> 1 order by DisOrder", oUpdateList)
		UpdateCount := oUpdateList.rowcount
		sTime := A_TickCount
		oLVDown.Clean()
		bNoSwitchLV := 1
		loop, %UpdateCount% {
			oBook.SBMSG := "��ǰ: " . A_index . " / " . UpdateCount . " : "
			oBook.UpdateBook(oUpdateList.rows[A_index][1], oLVBook, oLVPage, oLVDown, -9)
			If ( oBook.isStop = 1 )
				Break
		}
		bNoSwitchLV := 0
		oBook.isStop := 0
		eTime := A_TickCount - sTime
		SB_settext("������������鼮 : �� " . UpdateCount . " ������ʱ: " . eTime . " ms")
		oBook.MainMode := OldMainMode
	}
	If ( A_ThisMenuItem = "ֹͣ(&S)" )
		oBook.isStop := 1
	If ( A_ThisMenuItem = "��ʾ��������б�(&Q)" ) {
		NowBookID := oLVBook.GetOneSelect(3)
		oBook.GetBookInfo(NowBookID)
		NowListURL := qidian_getIndexURL_Desk(oBook.book["QiDianID"])
		oLVDown.Clean()
		oLVDown.focus()
		bNoSwitchLV := 1
		oBook.UpdateBook(NowBookID, oLVBook, oLVPage, oLVDown, NowListURL)
		bNoSwitchLV := 0
	}
	If ( A_ThisMenuItem = "ɾ������" ) {
		BookID := oLVBook.GetOneSelect(3)
		oBook.GetBookInfo(BookID)
		BookName := oBook.Book["Name"]
		msgbox, 4, ɾ��ȷ��, ID: %BookID%  ����: %BookName%`n`nȷ��Ҫɾ�����飿
		Ifmsgbox, no
			return
		if (BookID = "" or BookID = 0) {
			SB_SetText("ɾ��ʧ��: BookID������ѡ��һ�����ѡ��˵�ɾ��")
			return
		}
		; ��ɾ���½ڼ�¼������еĻ�
		PicDir := oBook.PicDir
		FileRemoveDir, %PicDir%\%BookID%, 1
		oDB.Exec("Delete From Page where BookID = " . BookID)
		oDB.Exec("Delete From Book where ID = " . BookID)
		SB_SetText("ɾ�����: " . BookName)
	}
	If ( A_ThisMenuItem = "�������TXT" ) {
		FileSelectFile, QiDianTxtPath, 3, %A_Desktop%, ѡ�����Txt�ļ�, ���Txt(*.txt)
		if ( QiDianTxtPath = "" )
			return
		QDXML := qidian_txt2xml(QiDianTxtPath, true, false) ; qidian txt -> FoxMark 

		; ��ȡ��Ϣ�������鼮
		NowQDBookName := qidian_getPart(QDXML, "BookName")
		NowQDPageCount := qidian_getPart(QDXML, "PartCount")
		NowQidianID := qidian_getPart(QDXML, "QidianID")
		NowSiteURL := qidian_getIndexURL_Mobile(NowQidianID)

		oDB.exec("insert into book (Name, URL, QidianID) values ('" . NowQDBookName . "', '" . NowSiteURL . "', '" . NowQidianID . "')")
		oDB.LastInsertRowID(BookID)
		; �����½�
		oDB.Exec("BEGIN;")
		loop, %NowQDPageCount%
		{
			NowQDPageTitle := qidian_getPart(QDXML, "Title" . A_index)
			NowQDPageContent := qidian_getPart(QDXML, "Part" . A_index)
			NowQDPageContent := ProcTxtNR(NowQDPageContent)  ; ��������
			NowContSize := strlen(NowQDPageContent)
			SB_SetText("���: " . A_index . " / " . NowQDPageCount . " : " . NowQDPageTitle)
			odb.EscapeStr(NowQDPageTitle)
			odb.EscapeStr(NowQDPageContent)
			oDB.exec("insert into page(BookID, Mark, CharCount, Name, Content) values(" . BookID . ", 'text', " . NowContSize . ", " . NowQDPageTitle . ", " . NowQDPageContent . ");")
		}
		oDB.Exec("COMMIT;")
		QDXML := ""
		SB_SetText("�Ѽ������Txt: " . NowQDBookName . "  �½���: " . NowQDPageCount)
	}
	If ( A_ThisMenuItem = "�����鼮(&N)" or A_ThisMenuItem = "�༭������Ϣ(&E)" ) {
		If ( A_ThisMenuItem = "�����鼮(&N)" ) {
			oDB.exec("insert into book (Name, URL) values ('BookName', 'http://XXXXXXXXX')")
			oDB.LastInsertRowID(BookID)
		}
		If ( A_ThisMenuItem = "�༭������Ϣ(&E)" )
			BookID := oLVBook.GetOneSelect(3)
		if BookID is not integer
			return
		oBook.GetBookInfo(BookID)
		BookName := oBook.Book["Name"]
		QidianID := oBook.Book["QidianID"]
		URL := oBook.Book["URL"]
		DelList := oBook.Book["DelList"]
		gosub, BookGUICreate
	}
	if ( instr(A_ThisMenuItem, "�����鼮_") ) {
		NowName := oLVBook.GetOneSelect(1)
		inputbox, NowBookName, �����鼮, ����������:, , 500, 130, , , , , %NowName%
		If ( A_ThisMenuItem = "�����鼮_���" ) {
			iJson := oBook.DownURL(qidian_getSearchURL_Mobile(GeneralW_UTF8_UrlEncode(GeneralW_StrToUTF8(NowBookName))), "", "<useUTF8>")
			qdid_1 := ""
			regexmatch(iJson, "Ui)""ListSearchBooks"":\[{""BookId"":([0-9]+),""BookName"":""" . NowBookName . """", qdid_)
			if ( qdid_1 != "" ) {
				NowURL := qidian_getIndexURL_Desk(qdid_1)
			} else {
				NowURL := -1
				fileappend, %iJson%, C:\%NowBookName%.json
			}
		}
		If ( A_ThisMenuItem = "�����鼮_PaiTXT" )
			NowURL := oBook.Search_paitxt(NowBookName)
		If ( A_ThisMenuItem = "�����鼮_��Ҷ�" )
			NowURL := oBook.Search_dajiadu(NowBookName)
		Clipboard = %NowURL%
		SB_SetText("����: " . NowBookName . "  Ŀ¼��ַ: " . NowURL)
	}
	If ( A_ThisMenuItem = "ˢ����ʾ�б�" ) {
		sTime := A_TickCount
		BookCount := oBook.ShowBookList(oLVBook)
		SB_settext(bMemDB . " ��ѯ��ʱ: " . ( A_TickCount - sTime) . " ms  �鼮��: " . BookCount)
	}
	If ( A_ThisMenuItem = "д�뵱ǰ��ʾ˳��" ) {
		oLVBook.focus()
		oDB.Exec("BEGIN;")
		Loop % LV_GetCount()
		{
			LV_GetText(NowBookID, A_Index, 3)
			oDB.Exec("update book set DisOrder = " . A_index . " where ID = " . NowBookID)
		}
		oDB.Exec("COMMIT;")
		SB_SetText("��ǰ��ʾ˳���Ѿ�д�����ݿ�")
	}
	If ( A_ThisMenuItem = "���: ���ٸ���" )
		oBook.MarkBook(oLVBook.GetOneSelect(3), "���ٸ���")
	If ( A_ThisMenuItem = "���: ��������" )
		oBook.MarkBook(oLVBook.GetOneSelect(3), "��������")
	If ( A_ThisMenuItem = "���: ����" )
		oBook.MarkBook(oLVBook.GetOneSelect(3), "����")

	If ( A_ThisMenuItem = "��ӿհ��½�(&C)" ) {
		NowBookID := oLVBook.GetOneSelect(3)
		NowBookName := oLVBook.GetOneSelect(1)
		oDB.Exec("insert into page (BookID, Name, URL, DownTime) Values (" . NowBookID . ", '" . NowBookName . "', 'FoxAdd.html', " . A_now . ")")
		oDB.LastInsertRowID(LastInsrtRowID)
		SB_SetText("��ӿհ��½����, PageID: " . LastInsrtRowID)
	}
	If ( A_ThisMenuItem = "�����ɾ���б�" ) {
		NowBookID := oLVBook.GetOneSelect(3)
		msgbox, 260, ȷ��,��ȷ��Ҫ��ո�����ɾ���б�
		Ifmsgbox, yes
			oDB.Exec("update Book set DelURL=null where ID = " . NowBookID)
		SB_SetText("�������ɾ���б�: " . NowBookID)
	}
	If ( A_ThisMenuItem = "���LastModified" ) {
		NowBookID := oLVBook.GetOneSelect(3)
		oDB.Exec("update Book set LastModified=null where ID = " . NowBookID)
		SB_SetText("�����LastModified: " . NowBookID)
	}
	If ( A_ThisMenuItem = "��ʾ��ɾ���б�(&D)" ) {
		NowBookID := oLVBook.GetOneSelect(3)
		oBook.GetBookInfo(NowBookID)
		oLVPage.ReGenTitle()
		oLVPage.Clean()
		DeleteList := oBook.book["DelList"]
		stringreplace, sjdfkfs, DeleteList, `n, , UseErrorLevel
		lastNum := ErrorLevel - 10
		loop, parse, DeleteList, `n, `r
		{
			If ( A_loopfield = "" )
				continue
			Stringsplit, FF_, A_LoopField, |, %A_space%
			if (A_index > lastNum)
				LV_Add("",FF_2, 0, FF_1, 0)
		}
		LV_Modify(LV_GetCount(), "Vis") ; Jump2Last
		SB_SetText("��¼����: " . oTable.RowCount)
	}

	If ( instr(A_ThisMenuItem, "ѡ���鼮����") ) {
		If ( A_ThisMenuItem = "ѡ���鼮����PDF" )
			NowTransMode := "pdf"
		If ( A_ThisMenuItem = "ѡ���鼮����Mobi" )
			NowTransMode := "mobi"
		If ( A_ThisMenuItem = "ѡ���鼮����Epub" )
			NowTransMode := "epub"
		If ( A_ThisMenuItem = "ѡ���鼮����CHM" )
			NowTransMode := "chm"
		If ( A_ThisMenuItem = "ѡ���鼮����UMD" )
			NowTransMode := "umd"
		If ( A_ThisMenuItem = "ѡ���鼮����Txt" )
			NowTransMode := "txt"
		sTime := A_TickCount
		aIDList := oLVBook.GetSelectList(3)
		NowSelectCount := aIDList.MaxIndex()
		If ( NowSelectCount = "" )
			return
		oBook.SBMSG := ""
		loop, %NowSelectCount% {
			NowID := aIDList[A_index]
			oBook.SBMSG := "ת������: " . A_index . " / " . NowSelectCount . " : "
			If ( NowTransMode = "PDF" )
				oBook.Book2PDF(NowID)
			else
				oBook.Book2MOBIorUMD(NowID, NowTransMode)
		}
		eTime := A_TickCount - sTime
		SB_SetText("ת " . NowTransMode . " �������, ��ʱ: " . eTime)
	}
	BookCount := oBook.ShowBookList(oLVBook) ; ˢ�������б�
	NowInCMD := ""
return
; }
PageMenuAct:
	If ( instr(A_ThisMenuItem, "ѡ���½�����") or instr(NowInCMD , "PageTo") )
	{
		If ( A_ThisMenuItem = "ѡ���½�����PDF" or NowInCMD = "PageToPDF" )
			TmpMod := "pdf"
		If ( A_ThisMenuItem = "ѡ���½�����Mobi" or NowInCMD = "PageToMobi")
			TmpMod := "mobi"
		If ( A_ThisMenuItem = "ѡ���½�����Epub" or NowInCMD = "PageToEpub" )
			TmpMod := "epub"
		If ( A_ThisMenuItem = "ѡ���½�����CHM" )
			TmpMod := "chm"
		If ( A_ThisMenuItem = "ѡ���½�����UMD" or NowInCMD = "PageToUMD" )
			TmpMod := "umd"
		If ( A_ThisMenuItem = "ѡ���½�����Txt" )
			TmpMod := "txt"
		aPageIDList := oLVPage.GetSelectList(4)
		PageCount := aPageIDList.MaxIndex()
		If ( PageCount = "" or PageCount = 0 )
			return
		; ����·��
		oBook.GetPageInfo(aPageIDList[1])
		oBook.GetBookInfo(oBook.page["BookID"])
		If bOutEbookPreWithAll
			SavePath := FoxSet["OutDir"] . "\all_" . FoxCompSiteType . "." . TmpMod
		else
			SavePath := FoxSet["OutDir"] . "\" . oBook.book["name"] . "." . TmpMod
		sTime := A_TickCount
		oBook.SBMSG := "����: ѡ���½��б�ת" . TmpMod . ": " . oBook.Book["Name"] . " : "
		If ( TmpMod = "PDF" )
			oBook.Pages2PDF(aPageIDList, SavePath)
		If TmpMod in Mobi,epub,CHM,UMD,Txt
			oBook.Pages2MobiorUMD(aPageIDList, SavePath, FoxCompSiteType)
		SB_SetText(oBook.SBMSG . "��ϲ��ת�����  ��ʱ: " . (A_TickCount - sTime))
	}
	If ( A_ThisMenuItem = "�����������½�(&C)" ){
		NewPageName := oLVComp.GetOneSelect(2)
		NowBookName := oLVComp.GetOneSelect(3)
		NowPageURL := oLVComp.GetOneSelect(5)
		if ( "" = NowPageURL )
			return
		oDB.GetTable("select ID from Book where Name='" . NowBookName . "'", tID)
		oDB.Exec("insert into page (BookID, Name, URL, DownTime) Values (" . tID.Rows[1,1] . ", '" . NewPageName . "', '" . NowPageURL . "', " . A_now . ")")
		oDB.LastInsertRowID(LastInsrtRowID)
		SB_SetText("��ӿհ��½����, PageID: " . LastInsrtRowID . "  Name: " . NewPageName . "  URL: " . NowPageURL)
	}
	If ( A_ThisMenuItem = "ɾ��ѡ���½�[д���Ѷ��б�](&D)" )
		gosub, DeleteselectedPages
	If ( A_ThisMenuItem = "ɾ��ѡ���½�[��д���Ѷ��б�](&B)" ) {
		bNotAddintoDelList := 1
		gosub, DeleteselectedPages
	}
	If ( A_ThisMenuItem = "���±�������(&G)" ) {
		oLVPage.LastRowNum := oLVPage.GetOneSelect()
		NowPageID := oLVPage.GetOneSelect(4)
		oBook.UpdatePage(NowPageID)
	}
	If ( A_ThisMenuItem = "�༭������Ϣ(&E)" ) {
		PageID := oLVPage.GetOneSelect(4)
		oBook.GetPageInfo(PageID)
		BookID := oBook.Page["BookID"]
		PageName := oBook.Page["Name"]
		PageURL := oBook.Page["URL"]
		CharCount := oBook.Page["CharCount"]
		Content := oBook.Page["Content"]
		Mark := oBook.Page["Mark"]
		gosub, PageGUICreate
	}
	If ( A_ThisMenuItem = "������ѡ���½�ID(&W)" ) {
		tmpBigPageID := "96969696"
		tIDList := oLVPage.GetSelectList(4)
		NowSelectCount := tIDList.MaxIndex()
		if ( NowSelectCount != 2 ) {
			SB_SetText("����: ѡ��ID������ȷ " . NowSelectCount)
			return
		}
		ida := tIDList[1]
		idb := tIDList[2]
		oBook.GetPageInfo(ida)
		bookida := oBook.Page["bookid"]
		oBook.GetPageInfo(idb)
		bookidb := oBook.Page["bookid"]
		if ( bookida != bookidb ) {
			SB_SetText("����: ѡ����ID��BookID��ͬ " . bookida . " != " . bookidb)
			return
		}
		SB_SetText("��ʼ����ID: " . ida . " <=> " . idb)
		ChangePageID(ida, tmpBigPageID)
		ChangePageID(idb, ida)
		ChangePageID(tmpBigPageID, idb)
		SB_SetText("ID�������: " . ida . " <=> " . idb . "  ��ˢ���б��Բ鿴Ч��")
	}
	If instr(A_ThisMenuItem, "��Ǳ��½�����Ϊ" )
	{
		mmPageID := oLVPage.GetOneSelect(4)
		if ( A_ThisMenuItem = "��Ǳ��½�����Ϊtext" )
			NowMark := "text"
		if ( A_ThisMenuItem = "��Ǳ��½�����Ϊimage" )
			NowMark := "image"
		if ( A_ThisMenuItem = "��Ǳ��½�����Ϊhtml" )
			NowMark := "html"
		oDB.Exec("update Page set Mark='" . NowMark . "' where ID = " . mmPageID)
		SB_SetText("���޸��½�: " . mmPageID . " ������Ϊ: " . NowMark )
		mmPageID := "" , NowMark := ""
	}
	If ( A_ThisMenuItem = "���ͱ������ݵ���һ����(&S)" ) {
		msgPageID := oLVPage.GetOneSelect(4)

		WinGet, TmpList, List, FoxBook ahk_class AutoHotkeyGUI
		if ( TmpList != 2 ) {
			TrayTip, ��ʾ, ��������������`n����: %TmpList%
			NowInCMD := ""
			return
		}
		if ( hMain = TmpList1 )
			hOtherMain := TmpList2
		else
			hOtherMain := TmpList1

		msgxml := "<MsgType>FoxBook_onePage</MsgType>`n"
		msgxml .= "<ScriptDir>" . A_Scriptdir . "</ScriptDir>`n"
		msgxml .= "<SenderHWND>" . hMain . "</SenderHWND>`n"
		oBook.GetPageInfo(msgPageID)
		oBook.GetBookInfo(oBook.Page["BookID"])
		msgxml .= "<BookName>" . oBook.Book["Name"] . "</BookName>`n"
		msgxml .= "<QidianID>" . oBook.Book["QidianID"] . "</QidianID>`n"
		msgxml .= "<PageName>" . oBook.Page["Name"] . "</PageName>`n"
		msgxml .= "<PageContent>" . oBook.Page["Content"] . "</PageContent>`n"
		msgxml .= "<PageMark>" . oBook.Page["Mark"] . "</PageMark>`n"
		
		TargetScriptTitle := "ahk_id " . hOtherMain
		Send_WM_COPYDATA(msgxml, TargetScriptTitle)
		SB_SetText(A_now . "  �ѷ��͵�����: " . hOtherMain . "  " . ErrorLevel)
	}
	NowInCMD := ""
return

IGotAPage:  ; �����յ��ĵ��½�
	awScriptdir := qidian_getPart(gFoxMsg, "ScriptDir")
	awSenderHWND := qidian_getPart(gFoxMsg, "SenderHWND")
	awBookName := qidian_getPart(gFoxMsg, "BookName")
	awQidianID := qidian_getPart(gFoxMsg, "QidianID")
	awPageName := qidian_getPart(gFoxMsg, "PageName")
	awPageContent := qidian_getPart(gFoxMsg, "PageContent")
	awPageMark := qidian_getPart(gFoxMsg, "PageMark")
	gFoxMsg := ""

	awPageCharCount := StrLen(awPageContent)
	SB_SetText("�յ����� " . awSenderHWND . " �������½�: " . awBookName . " - " . awPageName . "  ����:" . awPageCharCount . "  ���: " . awPageMark)
	BAKawPageName := awPageName ; ���� URL������Ҫ

	; ���뵽page��
	odb.EscapeStr(awPageName)
	odb.EscapeStr(awPageContent)
	oDB.Exec("insert into page (Name,CharCount,Content,Mark) values(" . awPageName . ", " . awPageCharCount . ", " . awPageContent . ", '" . awPageMark . "')")
	oDB.LastInsertRowID(NewPageID)

	; ��ȡ���½ڿ������ڵ��鼮��Ϣ �������bookID
	oDB.GetTable("select ID,Name,QidianID From book where Name like '%" . awBookName . "%' or QidianID ='" . awQidianID . "'", oNBI)
	if ( oNBI.rowcount = 1 ) { ;����ǰƥ����һ���鼮
		NewPagesBookID := oNBI.Rows[1][1]
		oDB.Exec("update Page set BookID = " . NewPagesBookID . " where ID = " . NewPageID)
		NewPagesBookName := oNBI.Rows[1][2]
		TrayTip, ����½�<%NewPageID%>��:, BookID: %NewPagesBookID%`nBookName: %NewPagesBookName%
	} else {
		tmpStr := ""
		loop, % oNBI.rowcount
			tmpStr .= oNBI.Rows[A_index][1] . "`t" . oNBI.Rows[A_index][2] . "`t" . oNBI.Rows[A_index][3] . "`n" 
		inputbox, NewPagesBookID, �������BookID, BookID`tBookName`tQidianID`n%tmpStr%, , 400, 222
		if ( NewPagesBookID = "" or NewPagesBookID = " " )
			return
		oDB.Exec("update Page set BookID = " . NewPagesBookID . " where ID = " . NewPageID)
		TrayTip, �˹�����½���:, BookID: %NewPagesBookID%
	}

	; ��ȡ���½ڿ������ڵ��½� �������URL
	odb.GetTable("select URL,ID,Name from Page where bookid=" . NewPagesBookID . " and ID <> " . NewPageID . " and Name like '%" . GetTitleKeyWord(BAKawPageName, 1) . "%'", oCXtmp)
	if ( oCXtmp.rowcount = 1 ) {
		oDB.Exec("update Page set URL = '" . oCXtmp.Rows[1][1] . "' where ID = " . NewPageID)
	} else {
		if ( oCXtmp.rowcount > 1 ) { ; ���������1����¼ʱ��ʹ�������������
			odb.GetTable("select URL,ID,Name from Page where bookid=" . NewPagesBookID . " and ID <> " . NewPageID . " and Name like '%" . BAKawPageName . "%'", oCXtemp)
			if ( oCXtemp.rowcount = 1 ) { ; ���ֻ��һ�������ʹ�øý��
				oCXtmp := oCXtemp
				oDB.Exec("update Page set URL = '" . oCXtmp.Rows[1][1] . "' where ID = " . NewPageID)
				return
			}
		}

		tmpStr := ""
		loop, % oCXtmp.rowcount
			tmpStr .= oCXtmp.Rows[A_index][2] . "`t" . oCXtmp.Rows[A_index][3] . "`t" . oCXtmp.Rows[A_index][1] . "`n" 
		inputbox, NewPageLikeID, ����ͱ�����ͬURL��ID, PageID`tPageName`tURL`n%tmpStr%, , 400, 222
		if ( NewPageLikeID = "" or NewPageLikeID = " " )
			return
		NewPageURL := ""
		loop, % oCXtmp.rowcount
			if ( oCXtmp.Rows[A_index][2] = NewPageLikeID )
				NewPageURL := oCXtmp.Rows[A_index][1]
		if ( NewPageURL = "" ) { ; ��û�ҵ�URLʱ
			oDB.GetTable("select URL from page where id = " . NewPageLikeID, osswi)
			NewPageURL := osswi.Rows[1][1]
		}
		oDB.Exec("update Page set URL = '" . NewPageURL . "' where ID = " . NewPageID)
		if ( NewPageURL != "" )
			TrayTip, ҳ�� %NewPageID% ��URL:, %NewPageURL%
	}
return

ChangePageID(PageIDA="", PageIDB="")  ; ��PageIDa(����) ��Ϊ PageIDb(������) , BookID����
{
	global oBook, oDB

	oBook.GetPageInfo(PageIDA)
	bookdir := oBook.PicDir . "\" . oBook.Page["BookID"]

	ifexist, %bookdir%\%PageIDA%_*  ; ����ͼƬ
	{
		NowContent := oBook.Page["Content"]
		stringreplace, NewContent, NowContent, %PageIDA%_, %PageIDB%_, A
		loop, parse, NowContent, `n, `r
		{
			If ( A_LoopField = "" )
				continue
			UU_1 := "" , UU_2 := ""
			stringsplit, UU_, A_LoopField, |
			stringreplace, NewName, UU_1, %PageIDA%_, %PageIDB%_, A
			FileMove, %bookdir%\%UU_1%, %bookdir%\%NewName%, 1
			oDB.Exec("update Page set ID = " . PageIDB . " , Content='" . NewContent . "' where ID = " . PageIDA)
		}
	} else
		odb.Exec("update page set ID = " . PageIDB . " where id=" . PageIDA)
}

; {
ReOrderBookIDDesc: ; ����
	oBook.ReGenBookID("Desc", "select ID From Book order by ID Desc")
	oBook.ReGenBookID("Asc", "select book.ID from Book left join page on book.id=page.bookid group by book.id order by count(page.id) desc,book.isEnd,book.ID")
	oDB.Exec("update Book set Disorder=ID")
	oBook.ShowBookList(oLVBook)
return

ReOrderBookIDAsc:  ; ˳��
	oBook.ReGenBookID("Desc", "select ID From Book order by ID Desc")
	oBook.ReGenBookID("Asc", "select book.ID from Book left join page on book.id=page.bookid group by book.id order by count(page.id),book.isEnd,book.ID")
	oDB.Exec("update Book set Disorder=ID")
	oBook.ShowBookList(oLVBook)
return

ReOrderPageID:
	oBook.ReGenPageID("Desc")
	oBook.ReGenPageID("Asc")
return

simplifyAllDelList: ; ��������
	oDB.gettable("select ID, DelURL from book where length(DelURL) > 200", oTable)
	loop, % oTable.RowCount
	{
		sDelURL := SimplifyDelList(oTable.rows[A_index][2]) ; ������ɾ���б�
		oDB.EscapeStr(sDelURL)
		oDB.Exec("update Book set DelURL=" . sDelURL . " where ID = " . oTable.rows[A_index][1])
	}
	oTable := []
	sDelURL := ""
return

DBMenuAct:
	sTime := A_TickCount
	If ( A_ThisMenuItem = "�༭������Ϣ(&E)" ) {
		gosub, CfgGUICreate
	}
	If ( A_ThisMenuItem = "���������鼮ID" ) {
		oBook.ReGenBookID("Desc")
		oBook.ReGenBookID("Asc")
		SB_settext("�鼮ID�������, ��ʱ(ms): " . (A_TickCount - sTime))
		oBook.ShowBookList(oLVBook)
	}
	If ( A_ThisMenuItem = "��������ҳ��ID" ) {
		gosub, ReOrderPageID
		SB_settext("ҳ��ID�������, ��ʱ(ms): " . (A_TickCount - sTime))
	}
	If ( A_ThisMenuItem = "���鼮ҳ����������" ) {
		gosub, ReOrderBookIDDesc
		SB_settext("���鼮ҳ���������� �� �����鼮ID���, ��ʱ(ms): " . (A_TickCount - sTime))
	}
	If ( A_ThisMenuItem = "���鼮ҳ��˳������" ) {
		gosub, ReOrderBookIDAsc
		SB_settext("���鼮ҳ��˳������ �� �����鼮ID���, ��ʱ(ms): " . (A_TickCount - sTime))
	}
	If ( A_ThisMenuItem = "����QidianID��SQL��������" ) {
		oDB.GetTable("select name,QidianID from book order by DisOrder", otable)
		loop, % oTable.rowcount
			TmpList .= "update Book set QidianID='" . oTable.Rows[A_index][2] . "' where name = '" . oTable.Rows[A_index][1] . "';`r`n"
		clipboard = %TmpList%
		TmpList := ""
		SB_settext("QidianID��SQL �ѵ����� ������")
	}
	If ( A_ThisMenuItem = "�����鼮�б�������" ) {
		oDB.GetTable("select name,url,QidianID from book order by DisOrder", otable)
		loop, % oTable.rowcount
			TmpList .= oTable.rows[A_index][1] . ">" . oTable.Rows[A_index][3] . ">" . oTable.Rows[A_index][2] . "`r`n"
		clipboard = %TmpList%
		TmpList := ""
		SB_settext("�鼮�б� �ѵ����� ������")
	}
	If ( A_ThisMenuItem = "��ʾ����ĸ��¼�¼" or A_ThisMenuItem = "��ʾ�����½ڼ�¼`tAlt+A" or A_ThisMenuItem = "��ʾ����image�½�`tAlt+G" or A_ThisMenuItem = "��ʾ����text�½�`tAlt+T" or A_ThisMenuItem = "��ʾ����ͬURL�½�`tCtrl+U" or NowInCMD = "ShowAll" ) {
		If ( A_ThisMenuItem = "��ʾ����ĸ��¼�¼" )
			SQLstr := "select page.name, page.CharCount, book.name, page.ID from book,Page where book.id=page.bookid and page.DownTime > " . A_YYYY . A_MM . A_DD  . "000000 order by page.bookid,page.ID"
		If ( A_ThisMenuItem = "��ʾ�����½ڼ�¼`tAlt+A" or NowInCMD = "ShowAll" )
			SQLstr := "select page.name, page.CharCount, book.name, page.ID from book,Page where book.id=page.bookid order by page.bookid,page.ID"
		If ( A_ThisMenuItem = "��ʾ����image�½�`tAlt+G" )
			SQLstr := "select page.name, page.CharCount, book.name, page.ID from book,Page where book.id=page.bookid and page.Mark = 'image' order by page.bookid,page.ID"
		If ( A_ThisMenuItem = "��ʾ����text�½�`tAlt+T" )
			SQLstr := "select page.name, page.CharCount, book.name, page.ID from book,Page where book.id=page.bookid and page.Mark = 'text' order by page.bookid,page.ID"
		If ( A_ThisMenuItem = "��ʾ����ͬURL�½�`tCtrl+U" )
			SQLstr := "select page.name, page.CharCount, book.name, page.ID from book,Page where book.id=page.bookid and ( ( select count(url) from page as p where p.bookid = page.bookid and p.url=page.url) > 1 ) order by page.bookid,page.ID"

		oLVDown.ReGenTitle()
		oLVDown.Clean()
		oDB.GetTable(SQLstr, oTable)
		LastItemBookName := "" , BookCount := 0
		LV_Colors.Detach(hLVPage)
		GuiControl, -Redraw, %hLVPage%
		LV_Colors.Attach(hLVPage, 0, 0)
		loop, % oTable.rowcount
		{
			LV_Add("",oTable.Rows[A_index][1],oTable.Rows[A_index][2],oTable.Rows[A_index][3],oTable.Rows[A_index][4])
			If ( oTable.rows[A_index][3] != LastItemBookName ) { ; ��ͬ��
				++BookCount
				if ( BookCount & 1 ) ; ���һ��
					NewColor := "0xCCFFCC"
				else
					NewColor := "0xCCFFFF"
			}
			LastItemBookName := oTable.rows[A_index][3]
			If ( oTable.rows[A_index][2] < 1000 ) ; ͼƬ�½���ɫ
				LV_Colors.Row(hLVPage, A_index, NewColor, 0xFF0000) ; ��ɫ:��������ɫ
			else
				LV_Colors.Row(hLVPage, A_index, NewColor, "") ; ��ɫ:����ɫ( ���)
		}
		GuiControl, +Redraw, %hLVPage%
		LV_Modify(LV_GetCount(), "Vis") ; Jump2Last
		SB_SetText("��¼����: " . oTable.RowCount)
	}
	If ( A_ThisMenuItem = "��������DelList" ) {
		gosub, simplifyAllDelList
		SB_settext("������ϣ���ʱ: " . ( A_TickCount - sTime) . " ms  �鼮��: " . oTable.RowCount)
	}
	If ( A_ThisMenuItem = "�л����ݿ�`tAlt+S" )
		gosub, FoxSwitchDB
	If ( A_ThisMenuItem = "�������ݿ�" or A_ThisMenuItem = "����(&L)" or NowInCMD = "SaveAndCompress" ) {  ; ��ť: �������ݿ�
		PicDir := oBook.PicDir ; ɾ���հ��ļ���
		loop, %PicDir%\*, 2, 0
			FileRemoveDir, %PicDir%\%A_LoopFileName%, 0
		FileRemoveDir, %PicDir%, 0

		;�������ڴ����ݿ�ʱ������
		SB_SetText("��ʼ�������ݿ⣬���Ե�...")
		FileGetSize, StartSize, %DBPath%, K
		if bMemDB
		{
			oDB.Exec("vacuum")
			FoxMemDB(oDB, DBPath, "Mem2File") ; Mem -> DB
			TmpSBText := "�ڴ����ݿ�������, "
		} else {
			oDB.Exec("vacuum")
			if ( EndSize > 5000 ) {  ; �����ݿ��СС��5M��ʱ����ͷŴ�С��������
				TmpSBText := ""
			} else {
				Filecopy, %DBPath%, %DBPath%.old, 1
				TmpSBText := "���ݿ��ļ��������, "
			}
		}
		FileGetSize, EndSize, %DBPath%, K
		SB_SetText("�հ��ļ���ɾ�����, " . TmpSBText . "�ͷŴ�С(K): " . ( StartSize - EndSize ) . "   ���ڴ�С(K): " . EndSize, 1)
	}
	If ( A_ThisMenuItem = "�����ݿ�`tAlt+O" )
		run, %DBPath%
	If ( A_ThisMenuItem = "����Ҫִ�е�SQL" ) {
		InputBox, ExtraSQL, ����SQL���, ��������ϣ��Exec��SQL���:`n��:[book] [page] [config]`ndelete from page where charcount < 9000, , 400, 150, , , , , update Book set LastModified = ''
		if ( ExtraSQL = "" or ExtraSQL = " " )
			return
		oDB.Exec(ExtraSQL)
		Traytip, ��ִ��:, %ExtraSQL%
		oBook.ShowBookList(oLVBook)
	}
	If ( A_ThisMenuItem = "��ݵ���`tAlt+E" or A_ThisMenuItem = "����(&E)" ) {
		gosub, ReOrderBookIDDesc
		gosub, ReOrderPageID
		gosub, simplifyAllDelList
		oDB.Exec("vacuum")
		SB_SetText("��ݵ������, ��ʱ(ms): " . (A_TickCount - sTime))
	}
	If ( A_ThisMenuItem = "���˳��`tAlt+W" or A_ThisMenuItem = "˳��(&W)" ) {
		gosub, ReOrderBookIDAsc
		gosub, ReOrderPageID
		gosub, simplifyAllDelList
		oDB.Exec("vacuum")
		SB_SetText("���˳�����, ��ʱ(ms): " . (A_TickCount - sTime))
	}
	NowInCMD := ""
return
; }
SetMenuAct:
	If ( A_ThisMenuItem = "�Ƚ�:���" )
		FoxCompSiteType := "qidian"
	If ( A_ThisMenuItem = "�Ƚ�:��Ҷ�" )
		FoxCompSiteType := "dajiadu"
	If ( A_ThisMenuItem = "�Ƚ�:PaiTxt" )
		FoxCompSiteType := "paitxt"
	If ( A_ThisMenuItem = "�Ƚ�:13xs" )
		FoxCompSiteType := "13xs"
	If ( A_ThisMenuItem = "�Ƚ�:��Ȥ��" )
		FoxCompSiteType := "biquge"
	; ---
	If ( A_ThisMenuItem = "ͼƬ(�ļ�):�и�:270*360(�ֻ�)" )
		oBook.ScreenWidth := 270 , oBook.ScreenHeight := 360
	If ( A_ThisMenuItem = "ͼƬ(�ļ�):�и�:530*665(K3_Mobi)" )
		oBook.ScreenWidth := 530 , oBook.ScreenHeight := 665   ; mobi split
	If ( A_ThisMenuItem = "ͼƬ(�ļ�):�и�:580*750(K3_Epub)" )
		oBook.ScreenWidth := 580 , oBook.ScreenHeight := 750   ; mobi split
	; ---
	If ( A_ThisMenuItem = "PDFͼƬ(����):ת��" )
		oBook.PDFGIFMode := "normal"
	If ( A_ThisMenuItem = "PDFͼƬ(����):�и�ΪK3:530*700" )
		oBook.PDFGIFMode := "SplitK3"
	If ( A_ThisMenuItem = "PDFͼƬ(����):�и�Ϊ�ֻ�:285*380" )
		oBook.PDFGIFMode := "SplitPhone"
	; ---
	If ( A_ThisMenuItem = "������:����" )
		oBook.DownMode := "BuildIn"
	If ( A_ThisMenuItem = "������:wget" )
		oBook.DownMode := "wget"
	If ( A_ThisMenuItem = "������:curl" )
		oBook.DownMode := "curl"
	; ---
	If ( A_ThisMenuItem = "�鿴��:IE�ؼ�" )
		oBook.ShowContentMode := "IEControl"
	If ( A_ThisMenuItem = "�鿴��:IE" )
		oBook.ShowContentMode := "IE"
	If ( A_ThisMenuItem = "�鿴��:AHK_Edit" )
		oBook.ShowContentMode := "BuildIn"
	; ---
	If ( A_ThisMenuItem = "����:Sqlite" )
		oBook.CFGMode := "sqlite"
	If ( A_ThisMenuItem = "����:ini" ) {
		IniPath := A_scriptdir . "\RE.ini"
		IfNotExist, %IniPath%
		{
			msgbox, ��ǰĿ¼�²����� RE.ini`nʹ�������ļ�ʧЧ`n����ʹ��SQLite���ù���
			return
		} else
			oBook.CFGMode := "ini"
	}
	gosub, SettingMenuCheck
return

GuiContextMenu:
	If ( A_GuiControl = "LVBook" )
		Menu, BookMenu, Show, %A_GuiX%, %A_GuiY%
	If ( A_GuiControl = "LVPage" ) {
		If ( LV_GetCount() > 0 )
			Menu, PageMenu, Show, %A_GuiX%, %A_GuiY%
	}
return

ListViewClick:
	If ( A_gui = 1 and bNoSwitchLV = 0 ) { ; ��������
		Hotkey, IfWinActive, ahk_class AutoHotkeyGUI
		If ( A_GuiEvent == "F" ) { ; �л�LVʱ
			Gui, ListView, %A_GuiControl%
			If ( A_GuiControl = "LVBook" )
				HotKey, ^A, LVBookSelectAll, on
			If ( A_GuiControl = "LVPage" )
				HotKey, ^A, LVPageSelectAll, on
		}
		If ( A_GuiEvent == "f" ) { ; ʧȥ����
			If ( A_GuiControl = "LVBook" )
				HotKey, ^A, LVBookSelectAll, off
			If ( A_GuiControl = "LVPage" )
				HotKey, ^A, LVPageSelectAll, off
		}
		Hotkey, IfWinActive
		If ( A_GuiEvent = "DoubleClick" ){
			If ( A_GuiControl = "LVBook" ) {
				oLVBook.LastRowNum := oLVBook.GetOneSelect()
				NowBookID := oLVBook.GetOneSelect(3)
				oBook.ShowPageList(NowBookID, oLVPage)
			}
			If ( A_GuiControl = "LVPage" ) {
				oLVPage.LastRowNum := oLVPage.GetOneSelect()
				NowPageID := oLVPage.GetOneSelect(4)
				If ( oBook.ShowContentMode = "IEControl" )
					gosub, IEGUICreate
				oBook.ShowPageContent(NowPageID, pWeb)
			}
		}
		If ( A_GuiEvent = "ColClick" ){
			If ( A_GuiControl = "LVBook" ) { ; �����Book���⣬�ػ���ɫ
				if ( A_EventInfo = 1 ) { ; �����1��
					ColA := ! ColA
					if ColA
						orderby := "book.Name,book.DisOrder"
					else
						orderby := "book.Name desc,book.DisOrder"
				}
				if ( A_EventInfo = 2 ) {
					ColB := ! ColB
					if ColB
						orderby := "count(page.id),book.DisOrder"
					else
						orderby := "count(page.id) desc,book.DisOrder"
				}
				if ( A_EventInfo = 3 ) {
					ColC := ! ColC
					if ColC
						orderby := "book.DisOrder desc"
					else
						orderby := "book.DisOrder"
				}
				if ( A_EventInfo = 4 ) {
					ColD := ! ColD
					if ColD
						orderby := "book.URL"
					else
						orderby := "book.URL desc"
				}
				BookCount := oBook.ShowBookList(oLVBook, "select book.Name,count(page.id),book.ID,book.URL,book.isEnd from Book left join page on book.id=page.bookid group by book.id order by " . orderby)
				SB_settext(bMemDB . " ��ѯ��ʱ: " . ( A_TickCount - sTime) . " ms  �鼮��: " . BookCount)
			}
		}
	}
return

LVBookSelectAll:
	oLVBook.Focus()
	LV_Modify(0, "Select")
return

LVPageSelectAll:
	oLVPage.Focus()
	LV_Modify(0, "Select")
return

DeleteselectedPages:
	sTime := A_TickCount
	aIDList := oLVPage.GetSelectList(4)
	aIDCount := aIDList.MaxIndex()
	If ( aIDCount > 55 )
		SB_settext("ѡ��ID�� > 55 , ʹ�� ����ɾ��ģʽ(�Ͽ�) ɾ��ѡ�����½�...")
	else
		SB_settext("ѡ��ID�� <= 55 , ʹ�� �ϼ�ɾ��ģʽ(����) ɾ��ѡ�����½�...")
	If bNotAddintoDelList
	{
		oBook.DeletePages(aIDList,1) ; ɾ���½���Ŀ,��д����ɾ���б�
		bNotAddintoDelList := 0
	} else {
		oBook.DeletePages(aIDList) ; ɾ���½���Ŀ
	}
	oBook.ShowBookList(oLVBook)
	oLVBook.select(oLVBook.LastRowNum)
	oBook.ShowPageList(oLVBook.GetOneSelect(3), oLVPage)
	SB_settext("��ϲ: ѡ�����½�ɾ�����, ��ʱ: " . ( A_TickCount - sTime ) )
return

#Ifwinactive, ahk_class AutoHotkeyGUI
#If WinActive("ahk_id " . hMain)
; -----��ע:
^esc:: gosub, FoxReload
+esc::Edit
!esc:: gosub, GuiClose

^R:: WinSet, ReDraw, , A  ; �ػ洰��
^F:: gosub, FaRGUICreate
^i:: SelectChapter(oLVPage, "Pic") ; ѡ��ͼƬ�½�
+Del::gosub, DeleteselectedPages
^Up::
	oLVBook.Focus()
	LV_MoveRow()       ; �����ƶ�һ��
return
^Down::
	oLVBook.Focus()
	LV_MoveRow(false)  ; �����ƶ�һ��
return
^Left:: oLVBook.Focus()
^right:: oLVPage.focus()
!1::CopyInfo2Clip(1)
!2::CopyInfo2Clip(2)
!3::CopyInfo2Clip(3)
!4::CopyInfo2Clip(4)
!5::CopyInfo2Clip(5)
!6::CopyInfo2Clip(6)
#If

#If WinActive("ahk_id " . hIE)
CapsLock::
+CapsLock::
	pWeb.document.close()
	If ( A_ThisHotkey = "CapsLock" )
		IESql := ">" , IESec := "asc" , IETip := "ĩ��"
	If ( A_ThisHotkey = "+CapsLock" )
		IESql := "<" , IESec := "desc" , IETip := "����"
	
	oDB.GetTable("select id from page where id " . IESql . " " . NowPageID . " and bookid = (select bookid from page where id = " . NowPageID . ") order by id " . IESec . " limit 1", oNaberID)
	if ( oNaberID.rows[1,1] = "" )
		pWeb.document.write("<html><head><META http-equiv=Content-Type content=""text/html; charset=utf-8""><title></title></head><body bgcolor=""#eefaee""><center><br><br><br><br><br><br><br><br><font color=""green""><h1>��������</h1><h1>���Ѿ���" . IETip . "��</h1><h1>��������</h1></font></center></body></html>")
	else {
		NowPageID := oNaberID.rows[1,1]
		oBook.ShowPageContent(NowPageID, pWeb)
	}
return
#If
#Ifwinactive

GetTitleKeyWord(NR="", RetType=1) ; RetType: 1:RE1/Part1 2:RE1/Part2
{
	stringreplace, NR, NR, `,, %A_space%, A
	stringreplace, NR, NR, `., %A_space%, A
	stringreplace, NR, NR, ��, %A_space%, A
	stringreplace, NR, NR, ��, %A_space%, A
	stringreplace, NR, NR, %A_space%%A_space%, %A_space%, A
	regexmatch(NR, "Ui)([��]?[0-9���һ�������������߰˾�ʮ��ǧإئ�cҼ��������½��ƾ�ʰ��Ǫ�򣱣�����������������]{1,7}[�½ڹ��ý��ؼ�]{1})[ ]*(.*)$", rr_)
	if ( rr_1 = "" ) {
		stringsplit, xx_, NR, %A_space%
		if ( RetType = 1 )
			return, xx_1
		if ( RetType = 2 )
			return, xx_2
	} else {
		if ( RetType = 1 )
			return, rr_1
		if ( RetType = 2 )
			return, rr_2
	}
}

CopyInfo2Clip(Num=1) {
	global oLVBook, oBook
	if ( Num = 1 ) {
		Gui, ListView, LVBook
		LV_GetText(NowVar, LV_GetNext(0), Num)
	}
	if ( Num = 2 ) {
		Gui, ListView, LVBook
		LV_GetText(NowBookID, LV_GetNext(0), 3)
		oBook.GetBookInfo(NowBookID)
		NowVar := qidian_getIndexURL_Mobile(oBook.Book["QidianID"])
	}
	if ( Num = 3 ) {
		Gui, ListView, LVPage
		LV_GetText(ShortURL, LV_GetNext(0), Num)
		oLVBook.select(oLVBook.LastRowNum)
		Gui, ListView, LVBook
		LV_GetText(LongURL, LV_GetNext(0), 4)
		NowVar := GetFullURL(ShortURL, LongURL)
	}
	if ( Num = 4 ) {
		Gui, ListView, LVBook
		LV_GetText(NowVar, LV_GetNext(0), Num)
	}
	if ( Num = 5 ) {
		Gui, ListView, LVPage
		LV_GetText(NowVar, LV_GetNext(0), Num)
	}
	if ( Num = 6 ) {
		Gui, ListView, LVPage
		LV_GetText(NowVar, LV_GetNext(0), 2)
	}
	Clipboard = %NowVar%
	SB_settext("������: " . NowVar)
}


Class FoxLV {
	Name := "" , FieldSet := []
	LastRowNum := -1
	__New(LVName) {
		This.Name := LVName
	}
	Switch() {
		Gui, ListView, % This.Name
	}
	Focus() {
		this.Switch()
		Guicontrol, Focus, % This.Name
	}
	Clean() {
		This.Switch()
		LV_Delete()
	}
	select(RowNum=0){
		This.Switch()
		LV_Modify(RowNum, "select focus")
	}
	ReGenTitle(bNew=0){
		This.Switch()
		if bNew
		{
			loop, 9
				LV_DeleteCol(1)
			loop, % This.FieldSet.MaxIndex()
				LV_InsertCol(A_index, This.FieldSet[A_index,1], This.FieldSet[A_index,2])
		} else {
			loop, % This.FieldSet.MaxIndex()
				LV_ModifyCol(A_index, This.FieldSet[A_index,1], This.FieldSet[A_index,2])
		}
	}
	GetOneSelect(FieldNum=-1){
		This.Switch()
		RowNum := LV_GetNext(0)
		If ( FieldNum != -1 ){
			LV_GetText(xx, RowNum, FieldNum)
			return, xx
		} else
			return, RowNum
	}
	GetSelectList(FieldNum=-1) {
		This.Switch()
		aSelectItems := []
		RowNumber := 0 , SelectCount := 0
		Loop {
			RowNumber := LV_GetNext(RowNumber)
			if not RowNumber
				break
			++SelectCount
			If ( FieldNum != -1 ){
				LV_GetText(xx, RowNumber, FieldNum)
				aSelectItems[SelectCount] := xx
			} else
				aSelectItems[SelectCount] := RowNumber
		}
		return, aSelectItems
	}
}

Class Book {
	FoxSet := {}
	PicDir := A_scriptdir . "\FoxPic"
	
	PDFGIFMode := "normal" ; normal | SplitK3 | SplitPhone
	ScreenWidth := 270 , ScreenHeight := 360

	SBMSG := ""
	isStop := 0
	MainMode := "update" ; update reader
	DownMode := "wget" ; BuildIn wget curl
	ShowContentMode := "IEControl" ; IEControl IE BuildIn
	CFGMode := "sqlite" ; sqlite ini
	Book := Object("ID", "��ID"
	, "Name", "��Name"
	, "URL", "��URL"
	, "DelList", "��DelList"
	, "DisOrder", "��DisOrder"
	, "isEnd", "��isEnd"
	, "QidianID", "��QidianID")
	Page := Object("ID", "��"
	, "BookID", "��"
	, "Name", "��"
	, "URL", "��"
	, "CharCount", "��"
	, "Content", "��"
	, "DisOrder", "��"
	, "DownTime", "��")

	oDB := ""
	__New(oDB, FoxSet, FoxType=0) {
		This.oDB := oDB
		This.FoxSet := FoxSet
		This.PicDir := FoxSet["PicDir"]
		if ( FoxType = 0 )
			This.PDFGIFMode := "SplitK3" , This.ScreenWidth := 530 , This.ScreenHeight := 665
		if ( FoxType = 1 )
			This.PDFGIFMode := "SplitPhone" , This.ScreenWidth := 270 , This.ScreenHeight := 360
	}
	ShowBookList(oLVBook, SQLStr="select book.Name,count(page.id),book.ID,book.URL,book.isEnd from Book left join page on book.id=page.bookid group by book.id order by book.DisOrder") {
		oLVBook.Clean()
		LV_Colors.Detach(This.hLVBook)
		GuiControl, -Redraw, %hLVBook%
		LV_Colors.Attach(This.hLVBook, 0, 0)
		This.oDB.gettable(SQLStr, oTable)
		loop, % oTable.RowCount
		{
			LV_Add("", oTable.rows[A_index][1],oTable.rows[A_index][2],oTable.rows[A_index][3],oTable.rows[A_index][4])
			If ( oTable.rows[A_index][2] > 0 )
				LV_Colors.Row(This.hLVBook, A_index, 0xCCFFCC, "") ; ��ɫ:���½�
			else
				LV_Colors.Row(This.hLVBook, A_index, 0xCCFFFF, "") ; ��ɫ:���½�
			If ( oTable.rows[A_index][5] = 1 )
				LV_Colors.Row(This.hLVBook, A_index, "", 0x008000) ; ��ɫ:���ٸ���
			If ( oTable.rows[A_index][5] = 2 )
				LV_Colors.Row(This.hLVBook, A_index, "", 0x3D4ACB) ; ��ɫ:����
		}
		GuiControl, +Redraw, %hLVBook%
		return, oTable.RowCount
	}
	GetCFG(AnyFullURL="http://www.qidian.com/xxx.html") {
		SplitPath, AnyFullURL, , , , , URLSite
		NowCFG := Object("Site", ""
		, "IdxRE", ""
		, "IdxStr", ""
		, "PageRE", ""
		, "PageStr", ""
		, "cookie", "")
		If ( This.CFGMode = "sqlite" ) {
			this.oDB.GetTable("select * from config where Site = '" . URLSite . "'", oTable)
			NowCFG["site"] := oTable.rows[1][2]
			NowCFG["IdxRE"] := oTable.rows[1][3]
			NowCFG["IdxStr"] := oTable.rows[1][4]
			NowCFG["PageRE"] := oTable.rows[1][5]
			NowCFG["PageStr"] := oTable.rows[1][6]
			NowCFG["cookie"] := oTable.rows[1][7]
			if ( oTable.RowCount = 0 )
				This.CFGMode := "ini"
		}
		If ( This.CFGMode = "ini" ) {
			IniPath := A_scriptdir . "\RE.ini"
			NowCFG["site"] := URLSite
			IniRead, XX, %IniPath%, %URLSite%, �б�Χ����, %A_space%
			xx := A_space = xx ? "" : xx
			NowCFG["IdxRE"] := XX
			IniRead, XX, %IniPath%, %URLSite%, �б�ɾ���ַ����б�, %A_space%
			xx := A_space = xx ? "" : xx
			NowCFG["IdxStr"] := XX
			IniRead, XX, %IniPath%, %URLSite%, ҳ�淶Χ����, %A_space%
			xx := A_space = xx ? "" : xx
			NowCFG["PageRE"] := XX
			IniRead, XX, %IniPath%, %URLSite%, ҳ��ɾ���ַ����б�, %A_space%
			xx := A_space = xx ? "" : xx
			NowCFG["PageStr"] := XX
			This.CFGMode := "sqlite"
		}
		return, NowCFG
	}
	DownURL(URL, SavePath="", AddParamet="", bDeleteHTML=true) ; ����URL, ����ֵΪ����
	{
		If ( SavePath = "" )
			SavePath := This.FoxSet["TmpDir"] . "\Fox_" . This.FoxSet["MyPID"] . "_" . A_TickCount . ".gz"
		SplitPath, SavePath, OutFileName, OutDir, OutExt
		IfNotExist, %OutDir%
			FileCreateDir, %OutDir%

		If ( "wget" = This.DownMode ) {
			stderrPath := This.FoxSet["TmpDir"] . "\Fox_" . This.FoxSet["MyPID"] . "_stderr.txt"
			oriAddParamet := AddParamet
			if instr(AddParamet, "<embedHeader>")
				stringreplace, AddParamet, AddParamet, <embedHeader>, -o "%stderrPath%",A
			if instr(AddParamet, "<useUTF8>")
				stringreplace, AddParamet, AddParamet, <useUTF8>, -U "ZhuiShuShenQi/2.22",A
			loop, 3 { ; ���أ�ֱ���������
				runwait, wget.exe -S -c -T 5 --header="Accept-Encoding: gzip`, deflate" -O "%SavePath%" %AddParamet% "%URL%", %A_scriptdir%\bin32 , Min UseErrorLevel
				If ( ErrorLevel = 0 ) {  ; �������
					break
				} else {
					if ( ErrorLevel = 1 ) { ; ��ҳľ�и���
						SB_settext("���ؾ���: ��ҳ���ľ�и��¹���")
						break
					} else {
						SB_settext("���ش���: ���Ե�ַ: " . URL)
					}
				}
			}
		}
		If ( "curl" = This.DownMode ) {
			loop { ; ���أ�ֱ���������
				runwait, curl.exe --compressed -L -o "%SavePath%" %AddParamet% "%URL%",  %A_scriptdir%\bin32, Min UseErrorLevel
				If ( ErrorLevel = 0 )
					break
				else
					SB_settext("���ش���: " . ErrorLevel . " : ���Ե�ַ: " . URL)
			}
		}

		If ( "BuildIn" = This.DownMode ) {
			loop { ; ���أ�ֱ���������
				UrlDownloadToFile, %URL%, %SavePath%
				If ( ErrorLevel = 0 )
					break
				else
					SB_settext("���ش���: ���Ե�ַ: " . URL)
			}
		}
		If OutExt in gif,png,jpg,jpeg
		{
			oContent := OutFileName . "|" . URL
		} else { ; ��ҳ/json
			if oriAddParamet contains <embedHeader>,<useUTF8>
			{
				if instr(oriAddParamet, "<embedHeader>") ; ��ҳ ʹ��LastModified
				{
					fileread, ssterr, %stderrPath%
					oContent := "`n<!--`n" . ssterr . "`n-->`n"
					oContent .= GeneralW_htmlUnGZip(SavePath)
				}
				if instr(oriAddParamet, "<useUTF8>") ; json
					oContent := GeneralW_htmlUnGZip(SavePath, "UTF-8")
			} else { ; ��ʹ��LastModified
				oContent := GeneralW_htmlUnGZip(SavePath)
			}
			if bDeleteHTML
			{
				FileDelete, %SavePath%
				FileDelete, %stderrPath%
;				fileappend, %oContent%, c:\tmp\oContent
			}
		}
		return, oContent
	}
	GetBookInfo(iBookID) {
		this.oDB.GetTable("select * from book where id = " . iBookID, oTable)
		This.Book["ID"] := oTable.rows[1][1]
		This.Book["Name"] := oTable.rows[1][2]
		This.Book["URL"] := oTable.rows[1][3]
		This.Book["DelList"] := oTable.rows[1][4]
		This.Book["DisOrder"] := oTable.rows[1][5]
		This.Book["isEnd"] := oTable.rows[1][6]
		This.Book["QidianID"] := oTable.rows[1][7]
		This.Book["LastModified"] := oTable.rows[1][8]
		return, this.Book
	}
	Book2MOBIorUMD(iBookID, ToF="mobi") {
		This.GetBookInfo(iBookID)

		This.oDB.GetTable("select id from page where bookid = " . iBookID, oTable)
		TmpPageCount := oTable.RowCount
		If ( TmpPageCount = "" or TmpPageCount = 0 )
			return
		oPageList := []
		loop, %TmpPageCount% 
			oPageList[A_index] := oTable.rows[A_index][1]

		This.Pages2MobiorUMD(oPageList, This.FoxSet["OutDir"] . "\" . This.Book["name"] . "." . ToF)
	}
	Book2PDF(iBookID) {
		sTime := A_TickCount
		This.GetBookInfo(iBookID)
		SavePDFPath := This.FoxSet["OutDir"] . "\" . This.Book["name"] . ".pdf"
		This.oDB.gettable("select id,name from page where BookID=" . iBookID, oTable)
		If ( oTable.rowcount = "" or oTable.rowcount = 0 )
			return
		oPageIDList := []
		loop, % oTable.rowcount
			oPageIDList[A_index] := oTable.rows[A_index][1]
		BakSBMSG := This.SBMSG
		This.SBMSG .= This.Book["Name"] . " : "
		This.Pages2PDF(oPageIDList, SavePDFPath) 
		eTime := A_TickCount - sTime
		SB_settext(This.SBMSG . "�� " . oTable.RowCount . " �½ڣ�תΪ PDF ��ϣ���ʱ: " . eTime)
		This.SBMSG := BakSBMSG
	}
	ShowPageList(iBookID, oLVPage) {
		LV_Colors.Detach(This.hLVPage)
		GuiControl, -Redraw, %hLVPage%
		LV_Colors.Attach(This.hLVPage, 0, 0)
		This.oDB.gettable("select Name,CharCount,URL,ID,Mark from Page where BookID = " . iBookID . " order by DisOrder", oTable)
		oLVPage.ReGenTitle()
		oLVPage.Clean()
		loop, % oTable.RowCount
		{
			LV_Add("", oTable.rows[A_index][1],oTable.rows[A_index][2],oTable.rows[A_index][3],oTable.rows[A_index][4])
			If ( oTable.rows[A_index][5] = "image" or oTable.rows[A_index][2] < 1000 )
				LV_Colors.Row(This.hLVPage, A_index, "", 0x008000) ; ��ɫ:ͼƬ�½�
		}
		GuiControl, +Redraw, %hLVPage%
;		LV_Modify(LV_GetCount(), "Vis") ; Jump2Last
		This.GetBookInfo(iBookID)
		SB_settext("ѡ��: " . This.Book["Name"] . "��ID:" . This.Book["ID"] . "��QiDian:" . This.Book["QiDianID"] . "��<" . This.Book["LastModified"] . ">��ͣ��:" . This.Book["isEnd"] . "��" . This.Book["URL"])
	}
	DeletePages(aIDList, isNotAddIntoDelList=0){ ; ɾ��ҳ��
		IDCount := aIDList.MaxIndex()
	If ( IDCount > 55 ) { ; ���� 55 �� PageID ���ǵ����鼮��¼ɾ��
		msgbox, 4, ȷ��ɾ��, ��ǰѡ����¼����55`n�ж��� �����鼮���Ƿ�ɾ����, 9
		ifmsgbox, no
			return
		this.GetPageInfo(aIDList[1])
		NowBookID := this.page["BookID"]
		this.GetBookInfo(NowBookID)
		sDelURL := this.book["DelList"]
		NowBookDir := this.PicDir . "\" . NowBookID
		This.oDB.Exec("BEGIN;")
		loop, %IDCount% {
			NowPageID := aIDList[A_index]
			this.GetPageInfo(NowPageID)
			FileDelete, %NowBookDir%\%NowPageID%_* ; ɾ��ͼƬ�ļ�
			sDelURL .= this.Page["URL"] . "|" . this.Page["Name"] . "`n"
			This.oDB.Exec("Delete From Page where ID = " . NowPageID)
		}
		this.oDB.EscapeStr(sDelURL)
		If ! isNotAddIntoDelList
			This.oDB.Exec("update Book set DelURL=" . sDelURL . " where ID = " . NowBookID)
		This.oDB.Exec("COMMIT;")
	} else { ; �ϼ����¼ɾ�����ٶȽ���
		PicDir := This.PicDir
		loop, %IDCount% {
			NowPageID := aIDList[A_index]
			this.GetPageInfo(NowPageID)
			NowBookID := This.Page["BookID"]
			FileDelete, %PicDir%\%NowBookID%\%NowPageID%_* ; ɾ��ͼƬ�ļ�
			This.oDB.Exec("Delete From Page where ID = " . NowPageID)
			If ! isNotAddIntoDelList
			{
				this.GetBookInfo(NowBookID)
				sDelURL := this.book["DelList"]
				sDelURL .= this.Page["URL"] . "|" . this.Page["name"] . "`n"
				this.oDB.EscapeStr(sDelURL)
				This.oDB.Exec("update Book set DelURL=" . sDelURL . " where ID = " . NowBookID)
			}
		}
	}
	} ; ɾ��ҳ��
	MarkBook(iBookID, Mark="") {
		If ( Mark = "��������" )
			SQLStr := "update Book set isEnd=null where ID = " . iBookID
		If ( Mark = "���ٸ���" )
			SQLStr := "update Book set isEnd=1 where ID = " . iBookID
		If ( Mark = "����" )
			SQLStr := "update Book set isEnd=2 where ID = " . iBookID
		this.odb.exec(SQLstr)
		SB_SetText("BookID " . iBookID . " �ѱ��Ϊ: " . Mark)
	}
	UpdateBook(iBookID, oLVBook=-9, oLVPage=-9, oLVDown=-9, IndexURL=-9) {
		This.GetBookInfo(iBookID)
		If ( IndexURL = -9 ) ; -9 ʱ��˵��Ϊд�����ݿ�ģʽ
			IndexURL := This.book["URL"] , bJustView := 0
		else
			bJustView := 1
		oLVDown.ReGenTitle()
		This.SBMSG .= This.Book["Name"] . " : "

		; ����Ƿ��пհ��½�,�о͸���
		This.oDB.GetTable("select ID,Name from page where CharCount isnull and BookID=" . iBookID " order by DisOrder", otable)
		If ( oTable.rowcount != "" ) {
			LastSBMSG := This.SBMSG
			This.SBMSG .= "�հ��½�: "
			loop, % oTable.RowCount
			{
				SB_settext(LastSBMSG . A_index . " / " . oTable.RowCount . " : " . oTable.Rows[A_index][2])
				PageContentSize := This.UpdatePage(oTable.Rows[A_index][1])
			}
			This.SBMSG := LastSBMSG
		}

		SB_settext(This.SBMSG . "����Ŀ¼ҳ: " . IndexURL)
		if ( This.Book["LastModified"] = "" )
			WgetCMDIfModifiedSince := "<embedHeader>"
		else
			WgetCMDIfModifiedSince := "<embedHeader> --header=""If-Modified-Since: " . This.Book["LastModified"] . """"
		if IndexURL contains m.baidu.com/tc,3g.if.qidian.com
			WgetCMDIfModifiedSince := "<useUTF8>"
		oNewPage := This._GetBookNewPages(IndexURL, "GetIt", WgetCMDIfModifiedSince) ; [Title,URL]
		NewPageCount := oNewPage.MaxIndex()
		If ( NewPageCount = "") {
			SB_settext(This.SBMSG . "�����½�")
			print(This.SBMSG . "`n")
			return, 0
		}
		print(This.SBMSG . "`t`t`t���½�: " . NewPageCount . "`n")
		SB_settext(This.SBMSG . "���½���: " . NewPageCount)
		If ( bJustView = 1 ) { ; ��д�����ݿ�
			oLVDown.Focus()
			lastNum := NewPageCount - 10 ; ��ʾ�����
			loop, %NewPageCount%  ; Page
			{
				if (A_index > lastNum)
					LV_Add("",oNewPage[A_index,2], "ֻ��", oNewPage[A_index,1], "��д")
			}
			LV_Modify(LV_GetCount(), "Vis") ; Jump2Last
			return, 0
		}
		If ( This.MainMode = "update" ) { ; ����ģʽ��������Ŀ¼
			This.oDB.Exec("BEGIN;")
			loop, %NewPageCount% {
				This.oDB.Exec("INSERT INTO Page (BookID, Name, URL, DownTime) VALUES (" . iBookID . ", '" . oNewPage[A_index,2] . "', '" . oNewPage[A_index,1] . "', " . A_now . ")")
				LV_Add("",oNewPage[A_index,2], "", oNewPage[A_index,1], 0)
			}
			This.oDB.Exec("COMMIT;")
			LV_Modify(LV_GetCount(), "Vis") ; Jump2Last
			This.ShowPageList(iBookID, oLVPage)
			return, 0
		}

		If ( This.MainMode = "reader" ) { ; ����ģʽ�����¸���
			LastSBMSG := This.SBMSG
			loop, %NewPageCount% {
				This.oDB.Exec("INSERT INTO Page (BookID, Name, URL, DownTime) VALUES (" . iBookID . ", '" . oNewPage[A_index,2] . "', '" . oNewPage[A_index,1] . "', " . A_now . ")")
				This.oDB.LastInsertRowID(LastRowID)
				oLVDown.Switch()
				LV_Add("", oNewPage[A_index,2], "", This.Book["Name"], LastRowID)
				LastLVRowNum := LV_GetCount()
				LV_Modify(LastLVRowNum, "Vis")

				This.SBMSG := LastSBMSG . A_index . " / " . NewPageCount . " : "
				PageContentSize := This.UpdatePage(LastRowID)
				oLVPage.Switch()
				LV_Modify(LastLVRowNum, "Vis Col2", PageContentSize)
				If ( This.isStop = 1 )
					return
			}
		}
		This.ShowBookList(oLVBook) ; ��������б�
		oLVBook.select(oLVBook.LastRowNum)
		SB_settext(This.SBMSG . "�������!")
	}
	_GetBookNewPages(IndexURL, ExistChapterList="GetIt", LastModifiedStr="" ) { ; ����ҳ�棬�Ա����ݿ⣬��ȡ���½��б�
		IfExist, %ExistChapterList%
		{  ;  �༭�½�����ʱʹ��
			Fileread, iHTML, %ExistChapterList%
			regexmatch(iHTML, "Ui)<meta[^>]+charset([^>]+)>", Encode_)
			If instr(Encode_1, "UTF-8")
				Fileread, iHTML, *P65001 %ExistChapterList%
		} else { ; ��ͨ����
			if ( "GetIt" = ExistChapterList ) {  ; ��ͨ����
				if instr(LastModifiedStr, "<embedHeader>")  ; ����ҳ�б�����ͷ��ʱ����ȡ����ͷ��
				{
					if instr(iHTML, "Last-Modified:")  ; ��ľ�и��£�Ҳ�Ͳ���дͷ����
					{
						regexmatch(iHTML, "mi)Last-Modified:[ ]?(.*)$", LM_)
						if ( LM_1 != "" ) { ; ��ͷ�����������ݿ��ֶ�
							This.oDB.Exec("update Book set LastModified = '" . LM_1 . "' where ID = " . This.Book["ID"] . ";")
						}
					}
				}
			} else {
				iHTML := This.DownURL(IndexURL, ExistChapterList, "", 0)
			}
		}

		oCFG := This.GetCFG(IndexURL) ; "IdxRE", "IdxStr"

		if ( "GetIt" = ExistChapterList ) {
			oBookInfo := This.Book
			This.oDB.GetTable("select URL,Name from page where BookID=" . oBookInfo["ID"], oTable)
			ExistChapterList := oBookInfo["DelList"]
			loop, % oTable.RowCount
				ExistChapterList .= oTable.Rows[A_index][1] . "|" . oTable.Rows[A_index][2] . "`n"
			stringreplace, ExistChapterList, ExistChapterList, `r, , A
			stringreplace, ExistChapterList, ExistChapterList, `n`n, `n, A

		}

		if ( instr(IndexURL, "3g.if.qidian.com") ) { ; ��������ֻ�
			oRemoteLink := qidianL_getIndexJson(iHTML)
			oNewPage := FoxNovel_Compare2GetNewPages(oRemoteLink, ExistChapterList)
			return, oNewPage
		}
		if ( instr(IndexURL, "m.baidu.com/tc") ) { ; ����ٶȶ���ҳ��
			oRemoteLink := bdds_getIndexJson(iHTML) ; ������������: [url,Title]
			oNewPage := FoxNovel_Compare2GetNewPages(oRemoteLink, ExistChapterList)
			return, oNewPage
		}
		if ( instr(IndexURL, "novel.mse.sogou.com") ) { ; �����ѹ�����ҳ��
			oRemoteLink := sogou_getIndexJson(iHTML) ; ������������: [url,Title]
			oNewPage := FoxNovel_Compare2GetNewPages(oRemoteLink, ExistChapterList)
			return, oNewPage
		}

		LinkDelList := oCFG["IdxStr"]
		regexmatch(iHTML, oCFG["IdxRE"], Tmp_)
		If Tmp_1
			iHTML := Tmp_1
		stringreplace, iHTML, iHTML, `r, , A
		stringreplace, iHTML, iHTML, `n, , A
		iHTML := RegExReplace(iHTML, "Ui)<!--[^>]+-->", "") ; ɾ��Ŀ¼�е�ע�� ��� niepo
		iHTML := RegExReplace(iHTML, "Ui)<span[^>]+>", "") ; ɾ�� span��ǩ qidian
		stringreplace, iHTML, iHTML, </span>, , A

		stringreplace, iHTML, iHTML, <a, `n<a, A
		stringreplace, iHTML, iHTML, </a>, </a>`n, A
		stringreplace, iHTML, iHTML, ����, %A_space%%A_space%%A_space%%A_space%, A
		oNewPage := [] , NewItemCount := 0
		if ( oCFG["IdxRE"] = "" ) { ; �����޹���(ͨ��): 2014-2-22 �����б�Ӧ���ǳ��ȼ����Ƶ�
			oRemoteLink := FoxNovel_getHrefList(iHTML) ; oPre����: [����, ����]
			oNewPage := FoxNovel_Compare2GetNewPages(oRemoteLink, ExistChapterList)
		} else { ; �������й���Ĵ���
			oRemoteLink := This._getRuledSiteLinkArray(iHTML, LinkDelList)
			oNewPage := FoxNovel_Compare2GetNewPages(oRemoteLink, ExistChapterList)
		}
		return, oNewPage
	}
	_getRuledSiteLinkArray(iHTML, LinkDelList=" ") { ; return: oRemoteLink:[url, title]
		oRemoteLink := [] , oRemoteCount := 0
		loop, parse, iHTML, `n, `r
		{
			If ! instr(A_LoopField, "href")
				continue
			regexmatch(A_LoopField, "i)href *= *[""']?([^>""']+)[^>]*> *([^<]+)<", FF_)
			If FF_1 contains %LinkDelList% ; ɾ������
				continue
			if ( FF_1 = "" )
				continue
			++oRemoteCount
			oRemoteLink[oRemoteCount, 1] := FF_1 ; url
			oRemoteLink[oRemoteCount, 2] := FF_2 ; title
		}
		return, oRemoteLink
	}
	ReGenBookID(Action="Desc", NowSQL="") { ; �޸�����BookID
		If ( Action = "Desc" ) {
			StartID := 55555
			if ( NowSQL = "" )
				NowSQL := "select ID From Book order by DisOrder Desc"
		} else {
			StartID := 1
			if ( NowSQL = "" )
				NowSQL := "select ID From Book order by DisOrder"
		}
		PicDir := This.PicDir
		IDList := This.oDB.GetTable(NowSQL, oTable)
		This.oDB.Exec("BEGIN;")         ; ����ʼ
		loop, % oTable.rowcount
		{
			NowOldID := oTable.Rows[A_index][1] , NowNewID := StartID
			If ( NowOldID = "" or NowNewID = "" )
				continue
			This.oDB.Exec("update Book set ID = " . NowNewID . " where ID = " . NowOldID . ";")
			This.oDB.Exec("update Page set BookID = " . NowNewID . " where BookID = " . NowOldID . ";")
			FileMoveDir, %PicDir%\%NowOldID%, %PicDir%\%NowNewID%, 0
			If ( Action = "Desc" )
				--StartID
			else
				++StartID
		}
		This.oDB.Exec("COMMIT;")        ; �������
	}

	GetPageInfo(iPageID) {
		this.oDB.GetTable("select * from Page where id = " . iPageID, oTable)
		This.Page["ID"] := oTable.rows[1][1]
		This.Page["BookID"] := oTable.rows[1][2]
		This.Page["Name"] := oTable.rows[1][3]
		This.Page["URL"] := oTable.rows[1][4]
		This.Page["CharCount"] := oTable.rows[1][5]
		This.Page["Content"] := oTable.rows[1][6]
		This.Page["DisOrder"] := oTable.rows[1][7]
		This.Page["DownTime"] := oTable.rows[1][8]
		This.Page["Mark"] := oTable.rows[1][9]
		This.Book["ID"] := oTable.rows[1][2]
		return, this.Page
	}
	ShowPageContent(iPageID, pWeb="") {
		This.GetPageInfo(iPageID)
		Title := This.Page["Name"]
		TmpTxt := This.Page["Content"]
		If ( This.ShowContentMode = "BuildIn" ) {
			stringreplace, TmpTxt, TmpTxt, `n, `r`n, A
			ListLines
			winwait, ahk_class AutoHotkey, , 3
			ControlSetText, Edit1, %TmpTxt%, ahk_class AutoHotkey
			TmpTxt := ""
		}
		If ( This.ShowContentMode = "IEControl" ) {
			NowHTML := This._CreateHtml(iPageID)
			StringList := "С˵,��,�½�,�ִ�,����,�ٶ�,Сʱ,com"
			loop, parse, StringList, `,
				stringreplace, NowHTML, NowHTML, %A_loopfield%, <font color=blue><b>%A_loopfield%</b></font>, A  ; ����ȥ���
			pWeb.document.focus() ; д֮ǰ���÷���space��ҳ
			pWeb.document.write(NowHTML)
		}
		If ( This.ShowContentMode = "IE" ) {
			NowHTML := This._CreateHtml(iPageID)
			NowSaveDir := This.PicDir . "\" . This.Page["BookID"]
			URL := NowSaveDir . "\" . This.Page["ID"] . ".html"
			IfNotExist, %NowSaveDir%
				FileCreateDir, %NowSaveDir%
			FileAppend, %NowHTML%, %URL%, UTF-8
			IfExist, %A_ProgramFiles%\Internet Explorer\IEXPLORE.EXE
				run, %A_ProgramFiles%\Internet Explorer\IEXPLORE.EXE -new %URL%, , , oPID
		}
	}
	_CreateHtml(iPageID){
		Title := This.Page["Name"] , TmpTxt := This.Page["Content"]
		BookDir := This.PicDir . "\" . This.Page["Bookid"] . "\"
		HtmlHead =
		(join`n Ltrim
		<html><head>
		<meta http-equiv=Content-Type content="text/html; charset=gb2312">
		<style type="text/css">h2,h3,h4,.FoxPic{text-align:center;}</style>
		<script language=javascript>
			function BS(colorString) {document.bgColor=colorString;}
			var currentpos,timer; 
			function initialize() {timer=setInterval("scrollwindow()",100);} 
			function clr(){clearInterval(timer);} 
			function scrollwindow() {
				currentpos=document.body.scrollTop;
				window.scroll(0,currentpos+=1);
				if (currentpos != document.body.scrollTop) clr();
			} 
			document.onmousedown=clr;
			document.ondblclick=initialize;
		</script>
		<title>Test</title></head><body bgcolor="#eefaee">`n
		<a id="%iPageID%"></a>`n
		<h4>%title%����
		<a href="javascript:BS('#e9faff');">��</a>
		<a href="javascript:BS('#ffffed');">��</a>
		<a href="javascript:BS('#eefaee');">��</a>
		<a href="javascript:BS('#fcefff');">��</a>
		<a href="javascript:BS('#ffffff');">��</a>
		<a href="javascript:BS('#efefef');">��</a>
		</h4>`n
		<div id="IEContent" class="content" style="font-size:30px; font-family:΢���ź�; line-height:150`%;">`n`n
		)
		If instr(TmpTxt, iPageID . "_") and instr(TmpTxt, "|")
		{ ; ͼƬ�½�
			NowBody := "<div class=""FoxPic"">`n`n"
			loop, parse, TmpTxt, `n, `r
			{
				PP_1 := ""
				stringsplit, pp_, A_LoopField, |, %A_space%
				If ( PP_1 != "" )
					NowBody .= "<img src=""" . BookDir . PP_1 . """ /><hr><br>`n"
			}
			NowBody .= "`n</div>`n"
		} else { ; �����½�
			If ( TmpTxt = "" )
				return
			loop, parse, TmpTxt, `n, `r
			{
				If ( A_loopfield = "" )
					continue
				NowBody .= "����" . A_LoopField . "<br>`n"
			}
		}
		return, HtmlHead . NowBody . "`n</div></body></html>`n`n"
	}
	UpdatePage(iPageID=0) {
		This.GetPageInfo(iPageID)
		This.GetBookInfo(This.Page["BookID"])
		NowPageURL := GetFullURL(This.Page["URL"], This.Book["URL"])
		FileDelete, % This.PicDir . "\" . This.Page["BookID"] . "\" . iPageID . "_*" ; ���±���ʱ��ɾ�����ܴ��ڵ�ͼƬ�ļ�
		SB_settext(This.SBMSG . This.Page["Name"] .  ": ��������ҳ...")
		NowTmpBookURL := This.Book["URL"]
		if NowTmpBookURL contains qidian.com,m.baidu.com/tc,novel.mse.sogou.com
		{
			if instr(NowPageURL, "qidian.com")
			{
				if ( instr(NowPageURL, "free.qidian.com") ) {
					NowPageURL := qidian_free_toPageURL_FromPageInfoURL(NowPageURL)
				} else {
					if ( ! instr(NowPageURL, "files.qidian.com") ) {
						nouseHTML := This.DownURL(NowPageURL)
						xx_1 := ""
						regexmatch(nouseHTML, "<script.*(http.*\.txt).*", xx_)
						NowPageURL := xx_1
					}
				}
				; 2015-4-16: Ĭ������.gz�����ʹ��cdn��Ȼ����ֹ���
				SavePath := This.FoxSet["TmpDir"] . "\Fox_" . This.FoxSet["MyPID"] . "_" . A_TickCount . ".txt"
				runwait, wget -S -c -T 5 -O "%SavePath%" "%NowPageURL%", , Min
				fileread, oHTML, %SavePath%
				FileDelete, %SavePath%

				PageContent := qidian_getTextFromPageJS(oHTML)
				oHTML := ""
				NowSBMSG := This.SBMSG . "�� : "
			}
			if instr(This.Book["URL"], "m.baidu.com/tc")
			{
				regexmatch(This.Book["URL"], "i)gid=([0-9a-z]+)&", bdgid_)
				PageContent := bdds_getPageJson(This.DownURL("http://m.baidu.com/tc?srd=1&appui=alaxs&ajax=1&gid=" . bdgid_1 . "&pageType=undefined&src=" . NowPageURL . "&time=&skey=&id=wisenovel", "", "<useUTF8>"))
			}
			if instr(This.Book["URL"], "novel.mse.sogou.com")
			{
				regexmatch(This.Book["URL"], "i)md=([0-9a-z]+)", gsmd_)
				PageContent := sogou_getPageJson(This.DownURL("http://novel.mse.sogou.com/http_interface/getContData.php?md=" . gsmd_1 . "&url=" . NowPageURL, "", "<useUTF8>"))
			}
		} else {
			iHTML := This.DownURL(NowPageURL)
			PageContent := This._GetPageContent(iHTML, This.Page["ID"], NowPageURL) ; ����HTML�õ����
		}
		; ��Բ�ͬ����ֵ����ͬ����ʽ
		If instr(PageContent, "|http://")  ; ͼƬ����
		{
			NowMark := "image"
			NowImageSaveDir := This.PicDir . "\" . This.Page["BookID"]
			PicCount := 0
			loop, parse, PageContent, `n, `r
			{
				If ( A_loopfield = "" )
					continue
				FF_1 := "" , FF_2 := ""
				stringsplit, FF_, A_loopfield, |, %A_space%
				++PicCount
				SB_settext(This.SBMSG . "ͼ : " . This.Page["Name"] . " : " . PicCount . " : " . FF_1)
				if ( This.DownMode = "curl" )
					This.DownURL(FF_2, NowImageSaveDir . "\" . FF_1 , "-e " . NowPageURL)
				else
					This.DownURL(FF_2, NowImageSaveDir . "\" . FF_1 , "--referer=" . NowPageURL)
			}
			NowSBMSG := This.SBMSG . "ͼ : "
		} else {
			NowMark := "text"
			if Content contains html>,<body,<br>,<p>,<div>
				NowMark := "html"
		}
		; �ı�����, ��PageContent StrSize д�����ݿ�,���޸�LV
		StrSize := StrLen(PageContent)
		This.oDB.EscapeStr(PageContent)
		This.oDB.Exec("update Page set CharCount=" . StrSize . ", Mark='" . NowMark . "', Content=" . PageContent . " where ID = " . This.Page["ID"])
		If ( NowSBMSG = "" )
			NowSBMSG := This.SBMSG . "�� : "
		SB_settext(NowSBMSG . This.Page["Name"] . " : �ַ���: " . StrSize)
		return, StrSize
	}
	_GetPageContent(iHTML, PageID=0, PageURL="") {
		oCFG := This.GetCFG(PageURL)
		if ( oCFG["PageRE"] = "" ) { ; ��û����Ӧ����Ļ���ʹ��ͨ�ô���ʽ: Add: 2014-2-21
			return, FoxNovel_getPageText(iHTML) ; ���� Ӧ������<div>�����ŵ������
		}
		regexmatch(iHTML, oCFG["PageRE"], Tmp_)
		If ( Tmp_1 != "" )
			iHTML := Tmp_1
		iHTML := FoxNovel_Html2Txt(iHTML)
		stringreplace, iHTML, iHTML, <div, `n<div, A
		stringreplace, iHTML, iHTML, <img, `n<img, A
		stringreplace, iHTML, iHTML, `n`n, `n, A
		If instr(iHTML, "<img")
		{	; ͼƬ
			PicCount := 0
			loop, parse, iHTML, `n, %A_space%
			{
				If ! instr(A_LoopField, "<img")
					continue
				II_1 := ""
				regexmatch(A_LoopField, "i)src *= *[""']?([^""'>]+)[^>]*>", II_)
				If ( II_1 != "" ) {
					If instr(II_1, "/front.gif")
						continue
					NowGifURL := GetFullURL(II_1, PageURL)
					SplitPath, NowGifURL, , , PicExt
					++PicCount
					oHTML .= PageID . "_" . PicCount . "." . PicExt . "|" . NowGifURL . "`n"
				}
			}
		} else { ; ����
			iHTML := RegExReplace(iHTML, "Ui)<a [^>]+>[^<]*</a>", "") ; ɾ�������е�����
			iHTML := RegExReplace(iHTML, "Ui)<[^>]+>", "") ; ɾ�� html��ǩ

			PageDelStrList := oCFG["PageStr"]       ; ɾ��ҳ���ַ���
			stringreplace, PageDelStrList, PageDelStrList, <##>, `v, A
			stringreplace, PageDelStrList, PageDelStrList, <br>, `n, A
			loop, parse, PageDelStrList, `v, `r
			{
				If ( A_LoopField = "" )
					continue
				if instr(A_loopfield, "<re>")
				{	; ����<re>��ǩ��������ʾ������ʽ
					fawi_1 := ""
					regexmatch(A_loopfield, "Ui)<re>(.*)</re>", fawi_)
					iHTML := RegExReplace(iHTML, fawi_1, "") ; ɾ��
				} else {
					stringreplace, iHTML, iHTML, %A_loopfield%, , A
				}
			}
			loop, parse, iHTML, `n, `r
			{
				NowLine = %A_LoopField%
				If ( NowLine = "" )
					continue
				oHTML .= NowLine . "`n"
			}
			iHTML := ""
		}
		stringreplace, oHTML, oHTML, `n`n, `n, A
		return, oHTML
	}
	Pages2MobiorUMD(oPageIDList, SavePath="C:\fox.mobi", tmode="�鼮") {
		SplitPath, SavePath, OutFileName, OutDir, OutExt, OutNameNoExt, OutDrive
		If OutExt not in mobi,epub,chm,umd,txt
			return, -1
		This.GetPageInfo(oPageIDList[1])
		This.GetBookInfo(This.Page["BookID"])
		TmpPageCount := oPageIDList.MaxIndex()

		if ( tmode = "�鼮" )
			ShowingBookName := This.Book["Name"]
		else
			ShowingBookName := This.Book["Name"] . "_" . tmode
		If ( OutExt = "mobi" or OutExt = "epub" )
			oEpub := New FoxEpub(ShowingBookName, This.FoxSet["TmpDir"] . "\ePubTmp_" . This.FoxSet["MyPID"])
		If ( OutExt = "chm" )
			oCHM := New FoxCHM(ShowingBookName, This.FoxSet["TmpDir"] . "\ChmTmp_" . This.FoxSet["MyPID"])
		If ( OutExt = "umd" )
			oUMD := New FoxUMD(ShowingBookName)
		If ( OutExt = "txt" )
			sTxt := ""
		TmpMsg := This.SBMSG . oEpub.BookName . " ת " . OutExt . " : "

		LastBookID := 0
		loop, %TmpPageCount% {
			This.GetPageInfo(oPageIDList[A_index])
			If ( LastBookID = This.Page["BookID"] ) { ; ��ȡ�½ڱ���,�����ϴ�Bookid�Ƿ�������ͬ���ж��Ƿ�౾��ϼ�
				NowPageTitle := This.Page["Name"]
			} else {
				This.GetBookInfo(This.Page["BookID"])
				NowPageTitle := "��" . This.Book["Name"] . "��" . This.Page["Name"]
				LastBookID := This.Page["BookID"]
			}
			SB_settext(TmpMsg . A_index . " / " . TmpPageCount)
			If ( OutExt = "mobi" or OutExt = "epub" ) {
				NowContent := This.Page["Content"]
				If ! instr(NowContent, ".gif|")   ; �ı��½�
				{
					xxCC := ""
					loop, parse, NowContent, `n, `r
						xxCC .= "����" . A_loopfield . "<br/>`n"
					oEpub.AddChapter(NowPageTitle, xxCC, oPageIDList[A_index])
				} else { ; ͼƬ�½�
					tmpdir := oEpub.TmpDir ; Mobi��ʱ�ļ�Ŀ¼
					srcgifdir := This.PicDir . "\" . This.Page["BookID"]
					PNGPreFix := tmpdir . "\html\" . oPageIDList[A_index] . "_"
					ChapterHTMLY := ""
					GifpathArray := [] , NowGC := 0
					loop, parse, NowContent, `n, `r
					{
						FF_1 := ""
						stringsplit, FF_, A_loopfield, |
						if ( FF_1 = "" )
							continue
						++NowGC
						GifpathArray[NowGC] := srcgifdir . "\" . FF_1
					}
					gifsplit(PNGPreFix, GifpathArray, This.ScreenWidth, This.ScreenHeight)
					loop, %PNGPreFix%*, 0, 0
						ChapterHTMLY .= "<div><img src=""" . A_LoopFileName . """ alt=""Fox"" /></div>`n"
					oEpub.AddChapter(NowPageTitle, ChapterHTMLY, oPageIDList[A_index])
				}
			}
			If ( OutExt = "chm" ) {
				if ( TmpPageCount = A_index )
					oCHM.isLastChapter := 1
				NowContent := This.Page["Content"]
				If ! instr(NowContent, ".gif|") {  ; �ı��½�
					NewContent := ""
					loop, parse, NowContent, `n, `r
						NewContent .= "����" . A_loopfield . "<br>`n"
					oCHM.AddChapter(NowPageTitle, NewContent)
					NewContent := ""
				} else { ; ͼƬ�½�
					tmpdir := oCHM.TmpDir ; CHM��ʱ�ļ�Ŀ¼
					srcgifdir := This.PicDir . "\" . This.Page["BookID"]
					PNGPreFix := tmpdir . "\p" . oPageIDList[A_index] . "_"
					ChapterHTMLY := ""
					GifpathArray := [] , NowGC := 0
					loop, parse, NowContent, `n, `r
					{
						FF_1 := ""
						stringsplit, FF_, A_loopfield, |
						if ( FF_1 = "" )
							continue
						++NowGC
						GifpathArray[NowGC] := srcgifdir . "\" . FF_1
					}
					gifsplit(PNGPreFix, GifpathArray, This.ScreenWidth, This.ScreenHeight)
					loop, %PNGPreFix%*, 0, 0
						ChapterHTMLY .= "<div><img src=""" . A_LoopFileName . """ /></div>`n"
					ChapterHTMLY .= "`n<!-- A image page splitted by fox -->`n"
					oCHM.AddChapter(NowPageTitle, ChapterHTMLY)
				}
			}
			If ( OutExt = "umd" )
				oUMD.AddChapter(NowPageTitle, This.Page["Content"])
			If ( OutExt = "txt" ) {
				txtContent := "`n" . This.Page["Content"]
				StringReplace, txtContent, txtContent, `n, `n����, A
				sTxt .= NowPageTitle . "`n" . txtContent . "`n`n"
			}
		}
		If ( OutExt = "mobi" or OutExt = "epub" ) {
			SB_settext(TmpMsg . "����" . OutExt . "�ļ�...")
			oEpub.SaveTo(SavePath)
		}
		If ( OutExt = "chm" ) {
			SB_settext(TmpMsg . "����CHM�ļ�...")
			oCHM.SaveTo(SavePath)
		}
		If ( OutExt = "umd" ) {
			SB_settext(TmpMsg . "����UMD�ļ�...")
			oUMD.SaveTo(SavePath)
		}
		If ( OutExt = "txt" ) {
			SB_settext(TmpMsg . "����Txt�ļ�...")
			FileAppend, %sTxt%, %SavePath%
			sTxt := ""
		}
	}
	Pages2PDF(oPageIDList, SavePDFPath="") {
;		FreeImage_FoxInit(True) ; Load Dll
		nPageIDCount := oPageIDList.MaxIndex()
		NowPageID := oPageIDList[1]
		This.GetPageInfo(oPageIDList[1])
		This.GetBookInfo(This.Page["BookID"])
		oPDF := new FoxPDF(This.Book["Name"])
		if ( This.PDFGIFMode = "SplitK3" ) {
			oPDF.ScreenWidth := 530 , oPDF.ScreenHeight := 700
			oPDF.TextPageWidth := 250 , oPDF.TextPageHeight := 330 , oPDF.TextTitleFontsize := 12 , oPDF.BodyFontSize := 9.5 , oPDF.BodyLineHeight := 12.5 , oPDF.CalcedOnePageRowNum := 26 ; 26*26�� �ı�ҳ�ߴ� K3
		}
		if ( This.PDFGIFMode = "SplitPhone" ) {
			oPDF.ScreenWidth := 285 , oPDF.ScreenHeight := 380
			oPDF.TextPageWidth := 180 , oPDF.TextPageHeight := 240 , oPDF.TextTitleFontsize := 13.5 , oPDF.BodyFontSize := 12 , oPDF.BodyLineHeight := 14.5 , oPDF.CalcedOnePageRowNum := 16 ; 26*26�� �ı�ҳ�ߴ� K3
		}
		loop, %nPageIDCount% {
			NowPageID := oPageIDList[A_index]
			This.GetPageInfo(NowPageID)
			NowTitle := This.Page["Name"] , NowContent := This.Page["Content"] , NowStrSize := This.Page["CharCount"] , NowMark := This.Page["Mark"]
; ------
			If ( NowMark = "text" or NowMark = "" or NowStrSize > 1000 ) { ; �ı��½�
				SB_settext(This.SBMSG . "ҳ��: " . A_index . " / " . nPageIDCount . " :��: " . NowTitle)

				NewContent := "" ; �½��ı�����
				loop, parse, NowContent, `n, `r
				{
					If ( A_loopfield = "" )
						continue
					NewContent .= "����" . A_loopfield . "`n"
				}
				NowContent := NewContent , NewContent := ""

				hFirstPage := oPDF.AddTxtChapter(NowContent, NowTitle)
			} else { ; ͼƬ�½�
				SB_settext(This.SBMSG . "ҳ��: " . A_index . " / " . nPageIDCount . " :ͼ: " . NowTitle)
				GIFPathArray := [] , GIFCount := 0
				loop, parse, NowContent, `n, `r
				{
					If ( A_loopfield = "" )
						continue
					FF_1 := ""
					regexmatch(A_loopfield, "Ui)^(.*\.gif)\|", FF_)
					If ( FF_1 = "" )
						continue
					NowGIFPath := This.PicDir . "\" . This.Page["bookid"] . "\" . FF_1
					IfNotExist, %NowGIFPath%
						continue
					++GIFCount
					GIFPathArray[GIFCount] := NowGIFPath
				}
				if ( This.PDFGIFMode = "normal" )
					hFirstPage := oPDF.AddPNGChapter(GIFPathArray, NowTitle) ; GIFPathArray Ϊ GIF�ļ�·�� ����
				if ( This.PDFGIFMode = "SplitK3" or This.PDFGIFMode = "SplitPhone" )
					hFirstPage := oPDF.AddGIFChapterAndSplit(GIFPathArray, NowTitle)  ; �и�ͼƬ
			}
; ------
		}
		If ( SavePDFPath = "" )
			SavePDFPath := This.FoxSet["OutDir"] . "\" . A_TickCount . ".pdf"
		SB_settext(This.SBMSG . "����PDF�ļ� -> " . SavePDFPath)
		oPDF.SaveTo(SavePDFPath)
;		FreeImage_FoxInit(False) ; unLoad Dll
	}
	ReGenPageID(Action="Desc") { ; �޸�����PageID
		If ( Action = "desc" )
			StartID := 55555 , NowSQL := "select ID from Page order by BookID,ID Desc"
		else
			StartID := 1 , NowSQL := "select ID from Page order by BookID,ID"
		PicDir := This.PicDir
		This.oDB.GetTable("select id from page where mark='image'", oExistPic)
		if ( oExistPic.RowCount > 0 ) {
			bExistPicDir := 1
			imageChaList := ":"
			loop, % oExistPic.RowCount
				imageChaList .= oExistPic.rows[A_index,1] . ":"
		} else {
			bExistPicDir := 0
		}
		This.oDB.GetTable(NowSQL, oTable)
		nPageCount := oTable.RowCount
		This.oDB.Exec("BEGIN;")         ; ����ʼ
		loop, %nPageCount% {
			NowPageID := oTable.Rows[A_index][1]
			SB_settext("���ڴ����¼: " . A_index . " / " . nPageCount . " : " . NowPageID . " -> " . StartID)
			if bExistPicDir
			{ ; ����ͼƬ�½�
				if instr(imageChaList, ":" . NowPageID . ":")
				{
					This.GetPageInfo(NowPageID)
					NowBookID := This.Page["BookID"]
					NowContent := This.Page["Content"]
					stringreplace, NewContent, NowContent, %NowPageID%_, %StartID%_, A
					This.oDB.Exec("update Page set ID = " . StartID . " , Content='" . NewContent . "' where ID = " . NowPageID)
					loop, parse, NowContent, `n, `r
					{
						If ( A_LoopField = "" )
							continue
						UU_1 := "" , UU_2 := ""
						stringsplit, UU_, A_LoopField, |
						stringreplace, NewName, UU_1, %NowPageID%_, %StartID%_, A
						FileMove, %PicDir%\%NowBookID%\%UU_1%, %PicDir%\%NowBookID%\%NewName%, 1
					}
				} else {
					This.oDB.Exec("update Page set ID = " . StartID . " where ID = " . NowPageID . ";")
				}
			} else { ; �����½�
				This.oDB.Exec("update Page set ID = " . StartID . " where ID = " . NowPageID . ";")
			}
			If ( Action = "desc" )
				--StartID
			else
				++StartID
		}
		This.oDB.Exec("COMMIT;")        ; �������
	}
	; {
	Search_paitxt(iBookName="͵��") {	; ����Ŀ¼ҳ��ַ
		OldDownMode := This.DownMode
		This.DownMode := "wget"
		html := This.DownURL("http://paitxt.com/modules/article/search.php", "", "--post-data=SearchClass=1&searchkey=" . iBookName . "&searchtype=articlename") ; ����URL, ����ֵΪ����
		This.DownMode := OldDownMode
		RegExMatch(html, "smUi)href=""(http://[w\.]*paitxt.com/[0-9]*/[0-9]*/)"" target=""_blank"">����Ķ�</a>", FF_)
		If ( FF_1 != "" )
			return, FF_1
		else
			return, "δ�ҵ�"
	}
	Search_dajiadu(iBookName="͵��") {	; ����Ŀ¼ҳ��ַ
		OldDownMode := This.DownMode
		This.DownMode := "wget"
		html := This.DownURL("http://www.dajiadu.net/modules/article/searcha.php", "", "--post-data=searchtype=articlename&searchkey=" . iBookName . "&&Submit=+%CB%D1+%CB%F7+")
		This.DownMode := OldDownMode
		regexmatch(html, "Ui)href=""([^""]*)"">����Ķ�</a>", FF_)
		If ( FF_1 != "" )
			return, FF_1
		else
			return, "δ�ҵ�"
	}
	; }
	; {
	GetSiteBookList(SiteType = "dajiadu") {
		TmpcookiePath := This.FoxSet["Tmpdir"] . "\FoxTmpCookie.txt"

		if ( SiteType = "dajiadu" )
			URLBookShelf := "http://www.dajiadu.net/modules/article/bookcase.php"
		if ( SiteType = "paitxt" )
			URLBookShelf := "http://paitxt.com/modules/article/bookcase.php"
		if ( SiteType = "13xs" )
			URLBookShelf := "http://www.13xs.com/shujia.aspx"
		if ( SiteType = "biquge" )
			URLBookShelf := "http://www.biquge.com.tw/modules/article/bookcase.php"

		oCFG := This.GetCFG(URLBookShelf) ; ��ȡcookie����
		NowCookie := oCFG["cookie"]
		FileDelete, %TmpcookiePath% ; ɾ����ʱcookie�ļ�
		Fileappend, %NowCookie% , %TmpcookiePath% ; ������ʱcookie�ļ�

		OldDownMode := This.DownMode
		This.DownMode := "wget"
		html := This.DownURL(URLBookShelf, "", "-S --load-cookies=""" . TmpcookiePath . """ --keep-session-cookies")
		This.DownMode := OldDownMode

		oRet := [] ; �������ݶ���: 1:���� 2:������ 3:����URL 4: ��������
		CountRet := 0

		if ( SiteType = "dajiadu" ) {  ; ����html,��� ����
			StringReplace, html, html, `r, , A
			StringReplace, html, html, `n, , A
			StringReplace, html, html, <tr, `n<tr, A
			StringReplace, html, html, <span class="hottext">��</span>, , A
			loop, parse, html, `n, `r
			{
				if ! instr(A_loopfield, "checkid")
					continue
				RegExMatch(A_loopfield, "Ui)<td.*</td>.*<td[^>]*><a[^>]*>([^<]*)<.*</td>.*<td[^>]*><a href=""([^""]+)""[^>]+>([^<]*)</a>.*</td>.*<td.*</td>.*<td.*</td>.*<td.*</td>", FF_)
				RegExMatch(FF_2, "i)cid=([0-9]+)", pid_)
				++CountRet
				oRet[CountRet,1] := FF_1
				oRet[CountRet,2] := FF_3
				oRet[CountRet,3] := pid_1 . ".html"
				oRet[CountRet,4] := ""
			}

		}
		if ( SiteType = "paitxt" ) {  ; ����html,��� ����
			StringReplace, html, html, `r, , A
			StringReplace, html, html, `n, , A
			StringReplace, html, html, <tr, `n<tr, A
			loop, parse, html, `n, `r
			{
				if ! instr(A_loopfield, "odd")
					continue
				RegExMatch(A_loopfield, "Ui)<td.*</td>.*<td.*<a[^>]+>([^<]*)<.*</td>.*<td.*<a href=""([^""]+)""[^>]+>([^<]*)<.*</td>.*<td.*</td>.*<td.*</td>.*<td.*</td>", FF_)
				RegExMatch(FF_2, "i)cid=([0-9]+)", pid_)
				++CountRet
				oRet[CountRet,1] := FF_1
				oRet[CountRet,2] := FF_3
				oRet[CountRet,3] := pid_1 . ".html"
				oRet[CountRet,4] := ""
			}
		}
		if ( SiteType = "13xs" ) {  ; ����html,��� ����
			StringReplace, html, html, `r, , A
			StringReplace, html, html, `n, , A
			StringReplace, html, html, <tr, `n<tr, A
			loop, parse, html, `n, `r
			{
				if ! instr(A_loopfield, "odd")
					continue
				RegExMatch(A_loopfield, "Ui)<td.*</td>.*<td.*><a[^>]*>([^<]*)</a></td>.*<td.*href=""([^""]*)""[^>]*>([^<]*)<.*</td>.*<td.*</td>.*<td[^>]*>([^<]*)</td>.*<td.*</td>", FF_)
				RegExMatch(FF_2, "i)cid=([0-9]+)", pid_)
				++CountRet
				oRet[CountRet,1] := FF_1
				oRet[CountRet,2] := FF_3
				oRet[CountRet,3] := pid_1 . ".html"
				oRet[CountRet,4] := FF_4
			}
		}
		if ( SiteType = "biquge" ) {  ; ����html,��� ����
			StringReplace, html, html, `r, , A
			StringReplace, html, html, `n, , A
			StringReplace, html, html, <tr, `n<tr, A
			loop, parse, html, `n, `r
			{
				if ! instr(A_loopfield, "odd")
					continue
				RegExMatch(A_loopfield, "Ui)<td.*</td>.*<td.*><a[^>]*>([^<]*)</a></td>.*<td.*href=""([^""]*)""[^>]*>([^<]*)<.*</td>.*<td.*</td>.*<td[^>]*>([^<]*)</td>.*<td.*</td>", FF_)
				++CountRet
				oRet[CountRet,1] := FF_1
				oRet[CountRet,2] := FF_3
				oRet[CountRet,3] := biquge_urlFromBCToPage(FF_2)
				oRet[CountRet,4] := FF_4
			}
		}
		FileDelete, %TmpcookiePath% ; ɾ����ʱcookie�ļ�
		return, oRet
	}
	; }
}

#include <SQLiteDB_Class>
#Include <LV_Colors_Class>
#include <FoxNovel>
#include <FoxPDF_Class>
#include <FoxEpub_Class>
#include <FoxUMD_Class>
#include <FoxCHM_Class>

; {
biquge_urlFromBCToPage(sURL="http://www.biquge.com/modules/article/readbookcase.php?aid=5976&bid=2782260&cid=2116619")
{
	RegExMatch(sURL, "i)aid=([0-9]+)", aa_)
;	RegExMatch(sURL, "i)bid=([0-9]+)", bb_)
	RegExMatch(sURL, "i)cid=([0-9]+)", cc_)
	return, "/" . biquge_id2IndexBid(aa_1) . "/" . cc_1 . ".html"
}

biquge_id2IndexBid(iId=5976) ; 5676 -> 5_5976  213 -> 0_213
{
	if ( iId < 1000 )
		return, "0_" . iId
	if ( iId < 10000 ) {
		StringLeft, hh, iId, 1
		return, hh . "_" . iId
	}
	if ( iId < 100000 ) {
		StringLeft, hh, iId, 2
		return, hh . "_" . iId
	}
	msgbox, ����:`nID : %iId% >= 100000`n��ô�����أ�
}

; }

; {
qidianL_getIndexJson(json="") ; ���������б�: URL`tTitle
{
	oRemoteLink := [] , oRemoteCount := 0
	StringReplace, json,json, `r,,A
	StringReplace, json,json, `n,,A
	StringReplace, json,json, {,`n{,A
	StringReplace, json,json, },}`n,A
	bid_1 := 0
	regexmatch(json, "i)""BookId"":([0-9]+),", bid_) ; ��ȡbookid
	urlHead := "http://files.qidian.com/Author" . ( 1 + mod(bid_1, 8) ) . "/" . bid_1 . "/" ; . pageid . ".txt"
	; {"c":80213678,"n":"��������ʮ���� ���Ĵ��֣��ϣ�","v":0,"p":0,"t":1423412257000,"w":2177,"vc":"101","ui":0,"pn":0,"ccs":0,"cci":0}
	RE = i)"c":([0-9]+),"n":"([^"]+)","v":([01]),

	loop, parse, json, `n, `r
	{
		xx_1 := "", xx_2 := "", xx_3 := ""
		regexmatch(A_LoopField, RE, xx_)
		if( xx_1 = "" )
			continue
		if ( "1" = xx_3 )
			break
		++oRemoteCount
		oRemoteLink[oRemoteCount, 1] := urlHead . xx_1 . ".txt" ; url
		oRemoteLink[oRemoteCount, 2] := xx_2 ; title
	}
	return, oRemoteLink
}
; }

; {
bdds_getIndexJson(json="") ; ���������б�: URL`tTitle
{
	oRemoteLink := [] , oRemoteCount := 0
	sp := "`t"
	StringReplace, json,json, `r,,A
	StringReplace, json,json, `n,,A
	StringReplace, json,json, {,`n{,A
	StringReplace, json,json, },}`n,A
; {        "index": "3",        "cid": "3682020160|12752225317556097817",        "text": "��2�� �����ص�����",        "href": "http://www.zhuzhudao.com/txt/29176/9559662/",        "rank": "0",        "create_time": "1425223386"      }
	RE = i)"text": *"([^"]*)"[, ]*"href": *"([^"]*)"[, ]*
	loop, parse, json, `n, `r
	{
		if instr(A_loopfield, "pageType") ; �������һ���ظ�
			break
		xx_1 := "", xx_2 := "", xx_3 := ""
		regexmatch(A_LoopField, RE, xx_)
		if( xx_1 = "" )
			continue
		++oRemoteCount
		oRemoteLink[oRemoteCount, 1] := xx_2 ; url
		oRemoteLink[oRemoteCount, 2] := xx_1 ; title
	}
	return, oRemoteLink
}
bdds_getPageJson(json="") ; ����txt����
{
	RE = i)<div[^>]+>(.*)</div>
	regexmatch(json, RE, xx_)
	StringReplace, xx_1, xx_1, &amp`;, , A
	StringReplace, xx_1, xx_1, \", ", A
	StringReplace, xx_1, xx_1, % chr(160), , A ; ����հ��ַ�
	xx_1 := FoxNovel_getPageText(xx_1)
	return, xx_1
}
; }

; {
sogou_getIndexJson(json="") ; ���������б�: URL`tTitle
{
	json := GeneralW_JsonuXXXX2CN(json) ; ת��
	StringReplace, json, json, \/, /, A

	oRemoteLink := [] , oRemoteCount := 0
	sp := "`t"
	StringReplace, json,json, `r,,A
	StringReplace, json,json, `n,,A
	StringReplace, json,json, {,`n{,A
	StringReplace, json,json, },}`n,A
; {"name":"��1�� ǰ��ģ���Ƥ�����","cmd":"6221462379586502657","url":"http://read.qidian.com/BookReader/3425938,80820570.aspx"}
	RE = i)"name":[ ]*"([^"]*)",.*"url":[ ]*"([^"]*)"
	loop, parse, json, `n, `r
	{
		xx_1 := "", xx_2 := "", xx_3 := ""
		regexmatch(A_LoopField, RE, xx_)
		if( xx_1 = "" )
			continue
		++oRemoteCount
		oRemoteLink[oRemoteCount, 1] := xx_2 ; url
		oRemoteLink[oRemoteCount, 2] := xx_1 ; title
	}
	return, oRemoteLink
}
sogou_getPageJson(json="") ; ����txt����
{
	RE = Ui)"block":"[\\n]*(.*)"}
	regexmatch(json, RE, xx_)
	StringReplace, xx_1, xx_1, \n, `n, A
	StringReplace, xx_1, xx_1, ����, , A
	StringReplace, xx_1, xx_1, `n`n, `n, A
	return, xx_1
}
; }

FoxMemDB(oMemDB, FileDBPath, Action="Mem2File") ; 2013-1-9 ���
{
	if ( Action = "Mem2File" ) ; MemDB -> FileDB
		ifExist, %FileDBPath%
			FileMove, %FileDBPath%, %FileDBPath%.old, 1
	oFileDB := new SQLiteDB
	oFileDB.OpenDB(FileDBPath)

	if ( Action = "Mem2File" ) ; MemDB -> FileDB
		oDBFrom := oMemDB , oDBTo := oFileDB
	else ; FileDB -> MemDB
		oDBFrom := oFileDB , oDBTo := oMemDB

	pBackup := DllCall("SQlite3\sqlite3_backup_init", "UInt", oDBTo._Handle, "Astr", "main", "UInt", oDBFrom._Handle, "Astr", "main", "Cdecl Int")
	RetA := DllCall("SQlite3\sqlite3_backup_step", "UInt", pBackup, "Int", -1, "Cdecl Int")
	DllCall("SQlite3\sqlite3_backup_finish", "UInt", pBackup, "Cdecl Int")

	oFileDB.closedb()
	if ( RetA != 101 ) ; SQLITE_DONE
		msgbox, ����:`nAction: %Action%`nsqlite3_backup_step ����ֵ: %RetA% ������ 101:��˼ȫ���������
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

print(cmdstr=":��ʼ��:") ; �����б�׼���
{
	static stdout
;	DllCall("AllocConsole")
	if ( cmdstr = ":��ʼ��:" ) {
		stdout := FileOpen(DllCall("GetStdHandle", "int", -11, "ptr"), "h `n")
		EnvGet, nowShell, SHELL
		if ( nowShell != "" ) ; ͨ�����������ж��Ƿ���cygwin����
			stdout.Encoding := "UTF-8"  ; ��׼������� UTF-8, ���� cygwin ʹ��
		return
	}
	if ( stdout = "" )
		return
	stdout.Write(cmdstr)
	stdout.Read(0) ; ˢ��д�뻺����.
}

LV_MoveRow(moveup = true) { ; ��Ӣ����̳Ū���ĺ��������ܵ���ListView�е���Ŀ˳��
   Loop, % (allr := LV_GetCount("Selected"))
      max := LV_GetNext(max)
   Loop, %allr% {
      cur := LV_GetNext(cur)
      If ((cur = 1 && moveup) || (max = LV_GetCount() && !moveup))
         Return
      Loop, % (ccnt := LV_GetCount("Col"))
         LV_GetText(col_%A_Index%, cur, A_Index)
      LV_Delete(cur), cur := moveup ? cur-1 : cur+1
      LV_Insert(cur, "Select Focus", col_1)
      Loop, %ccnt%
         LV_Modify(cur, "Col" A_Index, col_%A_Index%), col_%A_Index% := ""
   }
}

SelectChapter(oLVPage, SelType="Pic") ; ѡȡ�½�
{
	TypePoint := 1000  ; ��С�ָ��
	oLVPage.focus()
	piccount := 0
	txtcount := 0
	Loop, % LV_GetCount()
	{ ; ��ȡѡ�����б�
		LV_GetText(NowSize, A_index, 2)
		If ( SelType = "Pic" And NowSize < TypePoint ) {
			++PicCount
			LV_Modify(A_index, "Select")
		}
		If ( SelType = "Text" And NowSize >= TypePoint ) {
			++txtcount
			LV_Modify(A_index, "Select")
		}
	}
	if ( SelType = "Pic" )
		SB_settext("ѡ���½���:  ͼƬ: " . PicCount)
}

FoxInput(wParam, lParam, msg, hwnd)  ; ������ؼ��������ⰴ���ķ�Ӧ
{ ;	tooltip, <%wParam%>`n<%lParam%>`n<%msg%>`n<%hwnd%>`n%A_GuiControl%
	Global
	If ( A_GuiControl = "LVBook" and wParam = 13 ) {
		oLVBook.LastRowNum := oLVBook.GetOneSelect()
		NowBookID := oLVBook.GetOneSelect(3)
		oBook.ShowPageList(NowBookID, oLVPage)
	}
	If ( A_GuiControl = "LVPage" and wParam = 13 ) {
		NowPageID := oLVPage.GetOneSelect(4)
		If ( oBook.ShowContentMode = "IEControl" )
			gosub, IEGUICreate
		oBook.ShowPageContent(NowPageID, pWeb)
	}
	If ( A_GuiControl = "CfgURL" and wParam = 13 ) {
		Gui, Cfg:submit, nohide
		If instr(CFGURL, "http://")
			SplitPath, CFGURL, , , , , CfgSite
		else
			CfgSite := CFGURL
		oDB.GetTable("select * from config where Site like '%" . CfgSite . "%'", oTable)
		Guicontrol, Cfg:, CFGID, % oTable.rows[1][1]
		Guicontrol, Cfg:, CFGURL, % oTable.rows[1][2]
		Guicontrol, Cfg:, IndexRE, % oTable.rows[1][3]
		Guicontrol, Cfg:, IndexDelStr, % oTable.rows[1][4]
		Guicontrol, Cfg:, PageRE, % oTable.rows[1][5]
		Guicontrol, Cfg:, PageDelStr, % oTable.rows[1][6]
		Guicontrol, Cfg:, ConfigCookie, % oTable.rows[1][7]
	}
	If ( A_GuiControl = "PageFilter" and wParam = 13 ) {
		gosub, FilterTmpList
	}
}

; {{
Receive_WM_COPYDATA(wParam, lParam)  ; ͨ����Ϣ���մ��ַ���
{
	global gFoxMsg
	StringAddress := NumGet(lParam + 2*A_PtrSize)
	gFoxMsg := StrGet(StringAddress)
	if instr(gFoxMsg, "<MsgType>FoxBook_onePage</MsgType>")
		gosub, IGotAPage
	return true
}

Send_WM_COPYDATA(ByRef StringToSend, ByRef TargetScriptTitle)  ; ͨ����Ϣ���ʹ��ַ���
{
	VarSetCapacity(CopyDataStruct, 3*A_PtrSize, 0)
	SizeInBytes := (StrLen(StringToSend) + 1) * (A_IsUnicode ? 2 : 1)
	NumPut(SizeInBytes, CopyDataStruct, A_PtrSize)
	NumPut(&StringToSend, CopyDataStruct, 2*A_PtrSize)
	Prev_DetectHiddenWindows := A_DetectHiddenWindows
	Prev_TitleMatchMode := A_TitleMatchMode
	DetectHiddenWindows On
	SetTitleMatchMode 2
	SendMessage, 0x4a, 0, &CopyDataStruct,, %TargetScriptTitle%
	DetectHiddenWindows %Prev_DetectHiddenWindows%
	SetTitleMatchMode %Prev_TitleMatchMode%
	return ErrorLevel
}
; }}

gifsplit(pngprefix, GifpathArray, ScreenWidth=350, ScreenHeight=467)
{
	VarSetCapacity(hImageArray, 1024, 0)
	gifPathCount := GifpathArray.MaxIndex()
	VarSetCapacity(gifpathlist, 2560, 0)
	loop, %gifPathCount%
		StrPut(GifpathArray[A_index], (&gifpathlist)+256*(A_Index-1), "CP936")

	ifExist, %A_scriptdir%\bin32\FreeImage.dll
		NowDllDir = %A_scriptdir%\bin32\
	return, dllcall(NowDllDir . "FreeImage.dll\gifsplit"
	, "AStr", pngprefix
	, "Uint", &gifpathlist
	, "short", gifPathCount
	, "short", ScreenWidth
	, "short", ScreenHeight
	, "Uint", 0
	, "Uint", &hImageArray
	, "Cdecl int")
}

; {

CreateNewDB(oDB) {
	oDB.Exec("Create Table Book (ID integer primary key, Name Text, URL text, DelURL text, DisOrder integer, isEnd integer, QiDianID text, LastModified text)")
	oDB.Exec("Create Table Page (ID integer primary key, BookID integer, Name text, URL text, CharCount integer, Content text, DisOrder integer, DownTime integer, Mark text)")
	oDB.Exec("Create Table config (ID integer primary key, Site text, ListRangeRE text, ListDelStrList text, PageRangeRE text, PageDelStrList text, cookie text)")

	NovelList := InitBookInfo("NovelList") ; ConfigList
	loop, parse, NovelList, `n
	{
		stringsplit, FF_, A_loopfield, >
		oDB.Exec("INSERT INTO Book (Name, URL, QiDianID) VALUES ('" . FF_1 . "', '" . FF_2 . "', '" . FF_3 . "')")
	}
	ConfigList := InitBookInfo("ConfigList") ; NovelList
	loop, parse, ConfigList, `n
	{
		FF_1 := "" , FF_2 := "" , FF_3 := "" , FF_4 := "" , FF_5 := ""
		stringsplit, FF_, A_loopfield, @
		oDB.EscapeStr(FF_2)
		oDB.EscapeStr(FF_4)
		oDB.Exec("INSERT INTO config (Site, ListRangeRE, ListDelStrList, PageRangeRE, PageDelStrList) VALUES ('" . FF_1 . "', " . FF_2 . ", '" . FF_3 . "', " . FF_4 . ", '" . FF_5 . "')")
	}
}

CheckAndFixDB(oDB) ; ��ѯ ��ṹ������Ƿ�ȱ�������ֶΣ��޸���
{
	;CREATE TABLE sqlite_master ( type TEXT, name TEXT, tbl_name TEXT, rootpage INTEGER, sql TEXT);
	; ��� Book ��
	oDB.GetTable("select sql from sqlite_master where tbl_name like '%book%'", sBook)
	NowSQL := sBook.rows[1,1]
	if NowSQL not contains ID,Name,URL,DelURL,DisOrder,isEnd,QiDianID
	{
		TrayTip, ���ݿ����:, ���Book�б����ֶ�ȱ��
	} else {
		if ! instr(NowSQL, "LastModified")
			oDB.Exec("alter table book add LastModified text")
	}

	; ��� Page ��
	oDB.GetTable("select sql from sqlite_master where tbl_name like '%page%'", sPage)
	NowSQL := sPage.rows[1,1]
	if NowSQL not contains ID,BookID,Name,URL,CharCount,Content,DisOrder,DownTime
	{
		TrayTip, ���ݿ����:, ���Page�б����ֶ�ȱ��
	} else {
		if ! instr(NowSQL, "Mark")
			oDB.Exec("alter table Page add Mark text")
	}

	; ��� Config ��
	oDB.GetTable("select sql from sqlite_master where tbl_name like '%config%'", sConfig)
	NowSQL := sConfig.rows[1,1]
	if NowSQL not contains ID,Site,ListRangeRE,ListDelStrList,PageRangeRE,PageDelStrList
	{
		TrayTip, ���ݿ����:, ���config�б����ֶ�ȱ��
	} else {
		if ! instr(NowSQL, "cookie")
			oDB.Exec("alter table config add cookie text")
	}
}
/*
RE.ini :
[ģ��]
�б�Χ����=smUi)
�б�ɾ���ַ����б�=
ҳ�淶Χ����=smUi)
ҳ��ɾ���ַ����б�=
˵��=�б�ɾ���ַ����б��Զ��ŷָ�����ɾ�������ַ�����������html���룻ҳ��ɾ���ַ����б���<##>�ָ���<br>��ʾ���У�<re>������ʽ</re>����ɾ���ı��ַ���
*/

getCompSiteType(oDB) { ; �������Ϊ�˻�ȡĬ�ϱȽ���ܵ���վ�ؼ��֣���Ҫ����������վ����������ʽ
	oDB.GetTable("select URL from book where ( isEnd isnull or isEnd < 1 )", oBBB)
	RegExMatch(oBBB.rows[1,1], "Ui)http[s]?://[0-9a-z\.]*([^\.]+)\.(com|net|org|se|me|cc|cn|net\.cn|com\.cn|com\.tw|org\.cn)/", Type_)
	if (Type_1 != "")
		return, Type_1
	else
		return, "biquge" ; Ĭ�������վ :dajiadu 13xs
}

InitBookInfo(What2Return="NovelList") ; ConfigList
{
lNovelList =
(join`n
���ִ���>http://3g.if.qidian.com/Client/IGetBookInfo.aspx?version=2&BookId=1939238&ChapterId=0>1939238
)
lConfigList =
(Join`n
http://www.qidian.com@smUi)<div id="content">(.*)<div class="book_opt">@/book/,/BookReader/vol,/financial/,BuyVIPChapterList@@
http://read.qidian.com@smUi)<div id="content">(.*)<div class="book_opt">@/book/,/BookReader/vol,/financial/,BuyVIPChapterList@@
)
; http://msn.qidian.com@smUi)<!--����-->(.*)<!-- ����վ������ end -->@@@
	return, l%What2Return%
}
; }


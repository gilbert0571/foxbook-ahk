/* imgsplit.cpp : Defines the entry point for the console application.
	2012-5-18: �޸� gifsplit ��������(��ʹ������߶���ȷ���Ƿ񱣴浽����)
	2012-5-14: ��� K3 PDF ��ҪͼƬ�и����, �޸�main���������б�(-w -h)
	2012-5-8: ���� joblist ���������и��С
	2012-4-26: Dll ���:gifcat����:������ͼƬ�ϳ�Ϊһ��ͼƬ(���ͬһ�½�ͼƬ��ͬ�����ܻ���δ֪����)�������ٶ���΢������
	2012-4-25: Dll ���:gif2png_bufopen,gif2png_bufclose, bugfix: png�����Ϊ3λ
	2012-4-23: Dll ���:gifsplit, ��Ҫʹ��lib�������dll����Ҫ��־:FREEIMAGE_LIB����Ҫ�����ԭʼDLL��ȥ���ñ�־����ȥ����ʼ���ͷ���ʼ������
	2012-4-16: ��� ��ͼƬ��������
	2012-4-16: ���� ���һ�� action = 1 �� = 2 ��״���������δʹ��ģ�棬ʹ��+������
*/

// gifsplit() : bSaveToBuff = 1 ʱ:�����buff,����ͼΪPDF����ճ�һ�Σ�LineSpace

// #define FREEIMAGE_LIB

#define WIN32_LEAN_AND_MEAN
#pragma comment ( linker,"/ALIGN:4096" )

#include <stdio.h>
#include <math.h>
#include <string.h>
#include "FreeImage.h"

#define FOX_DLL extern "C" __declspec(dllexport)  // DLL����


#define MAXGIFCOUNT 10   // ���ͼƬ��
#define MAXPATHCHAR 256  // ·������ַ���
#define MAXCNCHARWIDTH 25  // ��������ַ���� ɨ�跶Χ��
#define MAXYLIST 1000    // ���Y������
#define MAXJOBLIST 3000  // ���job��
#define MAXOUTBUFCOUNT 256  // ��� hImage ����


// ȫ������������
	typedef struct TextPos {  // ��¼��Ϣ��
		unsigned pos;
		unsigned len;
	} POSLIST;

	typedef struct LineBorder {  // ��Ϣ����������
		unsigned left;
		unsigned right;
	} LineLR;

	typedef struct FoxJob { // �����б�
		unsigned action;  // 0: Ĭ�� 1:�ȴ�����ͼƬ 2:�󱣴�ͼƬ
		unsigned left;
		unsigned top;
		unsigned right;
		unsigned bottom;
		unsigned newleft;
		unsigned newtop;
	} JOBLIST;

// ȫ�ֺ�������
	FIBITMAP * gifcat(char gifpath[MAXGIFCOUNT][MAXPATHCHAR], unsigned gifPathCount) ; // ������ͼƬ����Ϊһ��ͼƬ
	FIBITMAP * CreateTemplete(FIBITMAP * hImage, unsigned ScreenWidth, unsigned ScreenHeight) ; // �����հ�PNGģ��

	unsigned GetAYLineInfoCount(unsigned NowX, unsigned NowY, unsigned YLineHeight, BYTE * pBit, unsigned ImgPitch) ; // ��ȡһ�����ص���Ϣ��
	unsigned GetLeftBorderX(unsigned NowX, unsigned MaxWidth, unsigned NowY, unsigned YLineHeight, BYTE * pBit, unsigned ImgPitch)  ; // ɨ�跽��: ��->��, ��ȡ��ʼX����
	unsigned GetRightBorderX(unsigned NowX, unsigned MaxWidth, unsigned NowY, unsigned YLineHeight, BYTE * pBit, unsigned ImgPitch) ; // ɨ�跽��: ��->��, ��ȡ����X����

	unsigned GetMinXToLeft(unsigned NowX, unsigned MaxWidth, unsigned NowY, unsigned YLineHeight, BYTE * pBit, unsigned ImgPitch) ; // ɨ�跽��: ��->��, ��ȡ������Ϣ����X����

	unsigned GetYList(POSLIST ylist[MAXYLIST] , BYTE * pBit , unsigned ImgPitch, unsigned ImgWidth, unsigned ImgHeight) ;  // ��ȡ Y �ָ��б�
	unsigned GetLineBorder(LineLR yinfo[MAXYLIST], POSLIST ylist[MAXYLIST], unsigned TextLineCount, BYTE * pBit , unsigned ImgPitch, unsigned ImgWidth, unsigned ImgHeight) ; // ÿ����������
	unsigned NewGetJobList(JOBLIST joblist[MAXJOBLIST], LineLR yinfo[MAXYLIST], POSLIST ylist[MAXYLIST], unsigned TextLineCount,unsigned ScreenWidth, unsigned ScreenHeight, unsigned ImgWidth, unsigned ImgHeight, BYTE * pBit, unsigned ImgPitch, unsigned bSaveToBuff) ; // �°������б�,ֻ������Ļ���ȡX����,���̶�

	FOX_DLL unsigned gifsplit(char * pngprefix, char gifpath[MAXGIFCOUNT][MAXPATHCHAR], unsigned gifPathCount, unsigned ScreenWidth, unsigned ScreenHeight, unsigned bSaveToBuff, FIBITMAP * hImageList[MAXOUTBUFCOUNT]) ; // 1 base count



// ������ʼ

int main(int argc, char* argv[])
{
//	unsigned ScreenWidth = 530 , ScreenHeight = 665 ; // 2 : 700:PDF 665:Mobi
	unsigned ScreenWidth = 270 , ScreenHeight = 360 ; // 3

	FIBITMAP * hImageList[MAXOUTBUFCOUNT] ;  // ��� himage ����, ��Ԫ�ذ������鳤��
	
	// �ļ�������
	int FileCount = 0 ;  // 1 base
	char pathlist[MAXGIFCOUNT][MAXPATHCHAR] ; // [����ļ�����][·����ַ���]

	char PNGPreFix[MAXPATHCHAR] = "Fox_" ; // ǰ׺����
	int i = 0 ;

	if ( argc == 1 ) {
		printf("�÷�:  imgsplit.exe [[ -p pngsPreFix]|[ -w ScreenWidth]|[ -h ScreenHeight]] gifpathA [ gifpathB]\n\n��л: û�׵���\n����: FreeImage\n����: ������֮��\nURL:  http://www.autohotkey.net/~linpinger/index.html\n\n");
		return 0;
	}

	for (i = 1; i < argc && argv[i][0] == '-'; i += 2) {
		switch(argv[i][1]) {
		    	case 'p':
				strcpy(PNGPreFix, argv[i+1]) ; // ���Ƶ�ǰ׺����
				break ;
	    		case 'w':
				sscanf(argv[i+1], "%d", &ScreenWidth);
				break ;
	    		case 'h':
				sscanf(argv[i+1], "%d", &ScreenHeight);
				break ;
			default:
				printf("imgsplit: δ֪ѡ�� %s\n", argv[i]) ;
		}
	}

	if ( i >= argc ) {
		printf("����: δ����������ļ���\n") ;
		return 0 ;
	}

	for(i = i; i < argc; ++i ) {
		strcpy(pathlist[FileCount], argv[i]) ; // ���Ƶ�·������
		++FileCount ;
	}

	printf("---------------------------------\n") ;
	printf("����:\n  PNGǰ׺: %s\n  �и���: %d\n  �и�߶�: %d\n", PNGPreFix, ScreenWidth, ScreenHeight);
	printf("������GIF�б�����: %d\n" , FileCount);
	for(i=0; i < FileCount; ++i )
		printf("  %s\n", pathlist[i]) ;
	printf("---------------------------------\n") ;

//	��ʼת��
	FreeImage_Initialise() ; // ��ʼ��
	gifsplit(PNGPreFix, pathlist, FileCount, ScreenWidth, ScreenHeight, 0 , hImageList);
	FreeImage_DeInitialise() ; // ��β����

	printf("\n   GIF�ָ����.\n");

	return 0;
}


FIBITMAP * CreateTemplete(FIBITMAP * hImage, unsigned ScreenWidth, unsigned ScreenHeight) // �����հ�PNGģ��
{
	FIBITMAP * hPicTemplete;
	RGBQUAD * palMain ;
	RGBQUAD * palTemplete ;
	unsigned ImgPitchLocal ;
	BYTE * pBitLocal;
	unsigned x, y, n;

	hPicTemplete = FreeImage_Allocate(ScreenWidth, ScreenHeight, 8, 0, 0, 0);  //����Ŀ��ͼ��
	palMain = FreeImage_GetPalette(hImage);
	palTemplete = FreeImage_GetPalette(hPicTemplete);
	for (n = 0 ; n < 256 ; n++) {
		palTemplete[n].rgbRed = palMain[n].rgbRed ;
		palTemplete[n].rgbGreen = palMain[n].rgbGreen ;
		palTemplete[n].rgbBlue = palMain[n].rgbBlue ;
	}
	palTemplete[70].rgbRed = 255   ;
	palTemplete[70].rgbGreen = 255 ;
	palTemplete[70].rgbBlue = 255  ;
//	FreeImage_SetTransparent(hPicTemplete, false);
	// ����������ɫ���Ϊ 70 ������
	ImgPitchLocal = FreeImage_GetPitch(hPicTemplete) ;
	pBitLocal = FreeImage_GetBits(hPicTemplete);
	for (y = 0 ; y < ScreenHeight; y++) {
		for (x = 0; x < ScreenWidth ; x++)
			pBitLocal[x] = 70 ;
		pBitLocal += ImgPitchLocal ; // ��һ��
	}
	return hPicTemplete;
}


unsigned GetYList(POSLIST ylist[MAXYLIST] , BYTE * pBit , unsigned ImgPitch, unsigned ImgWidth, unsigned ImgHeight)  // ��ȡ Y �ָ��б�
{
	unsigned TextLineCount = 0 ; // Y �и����
	BYTE * pBitLocal;

	unsigned x, y;
	bool bInfoLine;
	unsigned StartY = 0 , OldInfY = 0 , xTextHeight = 0;

	pBitLocal = pBit + ImgPitch * ( ImgHeight - 1 ) ;

	// Get Ylist
	for (y = 0 ; y < ImgHeight ; y++) {
		bInfoLine = false ;
		for (x = 0; x < ImgWidth ; x++) {
			if ( ( pBitLocal[x] < 240 ) && ( pBitLocal[x] != 70 ) ) {
				bInfoLine = true ;
				break ;
			}
		}
		pBitLocal -= ImgPitch ; // ��һ��
		if ( ImgHeight == y + 1 ) // �������һ��Ϊ��Ϣ�У�������������еĴ���
			bInfoLine = true ;

		if ( bInfoLine ) {
			if ( y == OldInfY + 1 ) {
				OldInfY = y ;
			} else {
				xTextHeight = OldInfY - StartY ;
				if ( xTextHeight > 0 ) {
					ylist[TextLineCount].pos = StartY ;
					ylist[TextLineCount].len = xTextHeight ;
					++TextLineCount ;
				}
				StartY = y ;
				OldInfY = y ;
			}
		}
	}
	return TextLineCount ;
}

unsigned GetLineBorder(LineLR yinfo[MAXYLIST], POSLIST ylist[MAXYLIST], unsigned TextLineCount, BYTE * pBit , unsigned ImgPitch, unsigned ImgWidth, unsigned ImgHeight) // ÿ����������
{
	unsigned y, NowY, StartX, EndX, linelen ;
	if ( yinfo[0].left >= 0 ) {
		StartX = yinfo[0].left - 1 ;
		EndX = yinfo[0].right ;
	} else {
		StartX = 0 ;
		EndX = ImgWidth - 1 ;
	}
	linelen = EndX - StartX ;

	for (y = 0; y < TextLineCount; ++y ) {
		NowY = ImgHeight - ylist[y].pos - ylist[y].len ;
		yinfo[y].left = GetLeftBorderX(StartX, linelen, NowY, ylist[y].len, pBit, ImgPitch) ;
		yinfo[y].right = GetRightBorderX(EndX, linelen, NowY, ylist[y].len, pBit, ImgPitch) ;
//		printf("yLR: %d , L: %d , R: %d\n", y, yinfo[y].left, yinfo[y].right) ;
	}
	return StartX ;
}

FIBITMAP * gifcat(char gifpath[MAXGIFCOUNT][MAXPATHCHAR], unsigned gifPathCount) // ������ͼƬ����Ϊһ��ͼƬ
{
	FIBITMAP * hImageAll ;
	unsigned ImgHeightAll = 0 ;
	FIBITMAP * hImage[MAXGIFCOUNT] ;
	unsigned ImgHeight[MAXGIFCOUNT] ;
	unsigned ImgWidth ;
	RGBQUAD * palSrc ;
	RGBQUAD * palAll ;
	unsigned n , NowYPos = 0 ;
//	---
	for ( n=0; n < gifPathCount; ++n) {
		hImage[n] = FreeImage_Load(FIF_GIF, gifpath[n], 0);
		ImgHeight[n] = FreeImage_GetHeight(hImage[n]) ;
		ImgHeightAll += ImgHeight[n] ;
	}
	ImgWidth = FreeImage_GetWidth(hImage[0]) ;

	hImageAll = FreeImage_Allocate(ImgWidth, ImgHeightAll, 8, 0, 0, 0);  //����Ŀ��ͼ��
	palAll = FreeImage_GetPalette(hImageAll);       // ���Ƶ�ɫ��
	palSrc = FreeImage_GetPalette(hImage[0]);
	for (n = 0; n < 256; ++n) {
		palAll[n].rgbRed = palSrc[n].rgbRed ;
		palAll[n].rgbGreen = palSrc[n].rgbGreen ;
		palAll[n].rgbBlue = palSrc[n].rgbBlue ;
	}
	palAll[70].rgbRed = 255   ;
	palAll[70].rgbGreen = 255 ;
	palAll[70].rgbBlue = 255  ;

	for ( n=0; n < gifPathCount; ++n) {  // ճ��ͼ��
		FreeImage_Paste(hImageAll, hImage[n], 0, NowYPos, 300) ;
		NowYPos += ImgHeight[n] ;
		FreeImage_Unload(hImage[n]) ;
	}
	return hImageAll ;
}

unsigned GetAYLineInfoCount(unsigned NowX, unsigned NowY, unsigned YLineHeight, BYTE * pBit, unsigned ImgPitch) // ��ȡһ�����ص���Ϣ�� v1.1
{
	BYTE * pBitLocal ;
	unsigned count = 0 , n;
	pBitLocal = pBit + (ImgPitch * NowY) ;

	for (n = 0; n < YLineHeight ; ++n) {  // ѭ��YLineHeight��
		if ( ( pBitLocal[NowX] < 240 ) && ( pBitLocal[NowX] != 70 ) )
			++count ;
		pBitLocal += ImgPitch ;
	}
	return count ;
}

unsigned GetLeftBorderX(unsigned NowX, unsigned MaxWidth, unsigned NowY, unsigned YLineHeight, BYTE * pBit, unsigned ImgPitch) // ɨ�跽��: ��->��, ��ȡ��ʼX����
{
	unsigned n;
	bool bIslastBlank = false ;

	for ( n=0 ; n<MaxWidth; ++n) {
		if ( 0 < GetAYLineInfoCount(NowX, NowY, YLineHeight, pBit, ImgPitch) ) { ; // ��ȡһ�����ص���Ϣ��
			if ( bIslastBlank )
				return NowX ;
			else
				bIslastBlank = false ;
		} else 
			bIslastBlank = true ;
		++NowX ;
	}
	return NowX;
}

unsigned GetRightBorderX(unsigned NowX, unsigned MaxWidth, unsigned NowY, unsigned YLineHeight, BYTE * pBit, unsigned ImgPitch) // ɨ�跽��: ��->��, ��ȡ����X����
{
	unsigned n;
	bool bIslastBlank = false ;

	for ( n=0 ; n<MaxWidth; ++n) {
		if ( 0 < GetAYLineInfoCount(NowX, NowY, YLineHeight, pBit, ImgPitch) ) { ; // ��ȡһ�����ص���Ϣ��
			if ( bIslastBlank )
				return NowX ;
			else
				bIslastBlank = false ;
		} else 
			bIslastBlank = true ;
		--NowX ;
	}
	return NowX;
}

unsigned GetMinXToLeft(unsigned NowX, unsigned MaxWidth, unsigned NowY, unsigned YLineHeight, BYTE * pBit, unsigned ImgPitch) // ɨ�跽��: ��->��, ��ȡ������Ϣ����X����
{
	unsigned n ;
	unsigned MinNum = 55555, MinX, NowNum;
	bool bIslastBlank = false ;

	MinX = NowX ;
	for ( n=0 ; n < MaxWidth; ++n) {
		NowNum = GetAYLineInfoCount(NowX, NowY, YLineHeight, pBit, ImgPitch) ; // ��ȡһ�����ص���Ϣ��
		if ( NowNum < MinNum ) {
			MinNum = NowNum ;
			MinX = NowX ;
		}
		--NowX ;
	}
	return MinX;
}

// ������������ȡgifͼƬ��д�ױ�����תΪPNG��д�뻺�棬���ػ����ַ
FOX_DLL FIMEMORY * gif2png_bufopen(char *gifpath, BYTE ** buffpointeraddr, DWORD * bufflenaddr)
{
	FIBITMAP * hImage ;
	RGBQUAD * pal ;
	FIMEMORY * hMemory = NULL ;
	BYTE *mem_buffer = NULL ;
	DWORD size_in_bytes = 0 ;

	hImage = FreeImage_Load(FIF_GIF, gifpath, 0);

	pal = FreeImage_GetPalette(hImage);
	pal[70].rgbRed = 255 ;
	pal[70].rgbGreen = 255 ;
	pal[70].rgbBlue = 255 ;
	FreeImage_SetTransparent(hImage, false);

	hMemory = FreeImage_OpenMemory() ;
	FreeImage_SaveToMemory(FIF_PNG, hImage, hMemory, PNG_DEFAULT) ;
	FreeImage_Unload(hImage) ;

	FreeImage_AcquireMemory(hMemory, &mem_buffer, &size_in_bytes);
	*buffpointeraddr = mem_buffer ;
	*bufflenaddr = size_in_bytes ;
	
	return hMemory ;
//	FreeImage_CloseMemory(hMemory) ; // ʹ���껺��ǵ�Ҫ�ͷ�
}

FOX_DLL int gif2png_bufclose(FIMEMORY * hMemory)
{
	FreeImage_CloseMemory(hMemory) ; // ʹ���껺��ǵ�Ҫ�ͷ�
	return 0 ;
}
/*
AHK L ���÷���:
	FreeImage_FoxInit(True) ; Load Dll
	VarSetCapacity(pBuffAddr, 4 0) , VarSetCapacity(pBuffLen, 4 0)
	hMemory := DllCall("FreeImage.dll\gif2png_bufopen", "Str", _StrToGBK(gifpath),"Uint", &pBuffAddr, "Uint", &pBuffLen, "Cdecl")
	BuffAddr := numget(&pBuffAddr+0, 0, "Uint") , BuffLen := numget(&pBuffLen+0, 0, "Uint")
	; ����buf���봦���������ǵ��ͷ�
	xx := DllCall("FreeImage.dll\gif2png_bufclose", "Uint", hMemory, "Cdecl")
	FreeImage_FoxInit(False) ; unLoad Dll
*/

FOX_DLL unsigned gifsplit(char * pngprefix, char gifpath[MAXGIFCOUNT][MAXPATHCHAR], unsigned gifPathCount, unsigned ScreenWidth, unsigned ScreenHeight, unsigned bSaveToBuff, FIBITMAP * hImageList[MAXOUTBUFCOUNT]) // 1 base count
{
//	------ ������ʼ
//	FIBITMAP * hImageList[MAXOUTBUFCOUNT] ;  // ��� himage ����, ��Ԫ�ذ������鳤��
	FIBITMAP * hPicTemplete;
	FIBITMAP * hImage ;
	FIBITMAP * hPicBlank;
	BYTE * pBit ;
	unsigned ImgPitch, ImgWidth, ImgHeight ;

	char pathPNG[MAXPATHCHAR];
	unsigned n;

//	ylist
	unsigned xsplitcount = 0 ;   // X �и����
	POSLIST ylist[MAXYLIST] ;
	unsigned TextLineCount = 0 ; // Y �и����
	LineLR yinfo[MAXYLIST] ;
	unsigned StartX, EndX ;

//	joblist
	JOBLIST joblist[MAXJOBLIST]  ;
	unsigned NowJobCount ; // joblist item count

	unsigned nNewPicCount = 0 ;

//	------- ��俪ʼ

	hImage = gifcat(gifpath, gifPathCount) ; // ������ͼƬ����Ϊһ��ͼƬ
	hPicTemplete = CreateTemplete(hImage, ScreenWidth, ScreenHeight) ; // �����հ�PNGģ��
	

		ImgWidth = FreeImage_GetWidth(hImage) ;
		ImgHeight = FreeImage_GetHeight(hImage) ;
		ImgPitch = FreeImage_GetPitch(hImage) ;
		pBit = FreeImage_GetBits(hImage) ;

		TextLineCount = GetYList(ylist , pBit , ImgPitch, ImgWidth, ImgHeight) ;  // ��ȡ Y �ָ��б�
		StartX = GetLeftBorderX(0, ImgWidth, 0, ImgHeight, pBit, ImgPitch) ;
		EndX = GetRightBorderX(ImgWidth - 1, ImgWidth, 0, ImgHeight, pBit, ImgPitch) ;
		yinfo[0].left = StartX ;
		yinfo[0].right = EndX ;
		GetLineBorder(yinfo, ylist, TextLineCount, pBit, ImgPitch, ImgWidth, ImgHeight) ; // ÿ����������
		yinfo[TextLineCount].left = StartX ;
		yinfo[TextLineCount].right = EndX ;

		NowJobCount = NewGetJobList(joblist, yinfo, ylist, TextLineCount, ScreenWidth, ScreenHeight, ImgWidth, ImgHeight, pBit, ImgPitch, bSaveToBuff) ; // �°������б�,ֻ������Ļ���ȡX����,���̶�


	// ����joblist ������ png
	for (n = 0; n < NowJobCount; n++) {
//		printf("������: %d , A: %d , L: %d , R: %d , T: %d , B: %d , nL: %d , nT: %d, R-L: %d\n", n, joblist[n].action, joblist[n].left, joblist[n].right, joblist[n].top, joblist[n].bottom, joblist[n].newleft, joblist[n].newtop, joblist[n].right - joblist[n].left) ; // ������
		if ( ( joblist[n].action >= 1 ) && ( joblist[n].action != 5 ) )
			hPicBlank = FreeImage_Clone(hPicTemplete);

		FreeImage_Paste(hPicBlank, FreeImage_Copy(hImage, joblist[n].left, joblist[n].top, joblist[n].right, joblist[n].bottom), joblist[n].newleft, joblist[n].newtop, 300);

		if ( joblist[n].action >= 5 ) {
			++nNewPicCount ;
			sprintf(pathPNG, "%s%03d.png", pngprefix, nNewPicCount) ;
			printf("����PNG %d : %s\n", nNewPicCount , pathPNG) ;

			if ( bSaveToBuff == 1 ) { // �����buff
				hImageList[nNewPicCount-1] = hPicBlank ;
			} else {  // ������ļ�
				FreeImage_Save(FIF_PNG, hPicBlank, pathPNG) ;
				FreeImage_Unload(hPicBlank) ;
			}
		}
	}
	return nNewPicCount;
}


unsigned NewGetJobList(JOBLIST joblist[MAXJOBLIST], LineLR yinfo[MAXYLIST], POSLIST ylist[MAXYLIST], unsigned TextLineCount,unsigned ScreenWidth, unsigned ScreenHeight, unsigned ImgWidth, unsigned ImgHeight, BYTE * pBit, unsigned ImgPitch, unsigned bSaveToBuff)  // �°������б�,ֻ������Ļ���ȡX����,���̶�
{
	unsigned StartX, EndX ;  // ����ͼƬ�����ұ߽�X����
	unsigned i = 0 ; // joblist item count
	unsigned y = 0 ; // Ylist item count
	unsigned TrueRight, NowSegWidth ;
	unsigned nScreenWidth = 0 , nScreenHeight = 0 ;
	unsigned LineSpace = 5 ;  // �м��

	if ( bSaveToBuff == 1 ) { // �������и�ΪK3��Ҫ��PDFʱ����һ��ͼƬ�ճ�һ�οհ����������У�Ҫ����drawͼƬ����show����
		nScreenHeight = 30 ;
	}

	StartX = yinfo[TextLineCount].left ;
	EndX = yinfo[TextLineCount].right  ;

	for ( i=0; i < MAXJOBLIST; ++i )
		joblist[i].action = 0 ;

	i = 0 ;
	joblist[i].action = 1 ;
	joblist[i].left = StartX ;
	joblist[i].right = joblist[i].left + ScreenWidth ;
	joblist[i].top = ylist[y].pos ;
	joblist[i].bottom = ylist[y].pos + ylist[y].len ;
	joblist[i].newleft = 0 ;
	joblist[i].newtop = nScreenHeight ;

while ( true ) { // ����ѭ������joblist
	TrueRight = GetMinXToLeft(joblist[i].right, MAXCNCHARWIDTH, ImgHeight - ylist[y].pos - ylist[y].len, ylist[y].len, pBit, ImgPitch) ; // ʵ�ʴ�������
	joblist[i].right = TrueRight ; // ��ǰ����������
	NowSegWidth = joblist[i].right - joblist[i].left ; // ��ǰƬ�ο��
	nScreenWidth += NowSegWidth ;      // ��ǰСͼ��д���

	++i ;
	joblist[i].left = TrueRight ;
	joblist[i].right = TrueRight + ScreenWidth ;
	joblist[i].top = ylist[y].pos ;
	joblist[i].bottom = ylist[y].pos + ylist[y].len ;
	joblist[i].newleft = nScreenWidth ;
	joblist[i].newtop = nScreenHeight ;

	if ( joblist[i].right > yinfo[y].right )
		joblist[i].right = yinfo[y].right + 1 ;

	if ( ScreenWidth - nScreenWidth < MAXCNCHARWIDTH ) { // �¸����� ʣ�� 1 ���Ŀ�� С����
		nScreenWidth = 0 ;
		nScreenHeight += ylist[y].len + LineSpace ;
		joblist[i].newleft = 0 ;
		joblist[i].newtop = nScreenHeight ;
	} else { // ��С����
		++y ;
		if ( y >= TextLineCount ) { // ��ͼƬ����
			joblist[i-1].action += 5 ;
			break ;
		}
		if ( yinfo[y].left > StartX + MAXCNCHARWIDTH ) {  // �¶�
			joblist[i].left = StartX ;

			nScreenWidth = 0 ;
			nScreenHeight += ylist[y].len + LineSpace ;
			joblist[i].newleft = 0 ;
			joblist[i].newtop = nScreenHeight ;
		} else
			joblist[i].left = yinfo[y].left ;

		joblist[i].right = joblist[i].left + ScreenWidth - nScreenWidth  ;
		if (joblist[i].right > yinfo[y].right)   // ��Ԥ���ұ�С��ͼƬʵ�ʿ��ʱ
			joblist[i].right = yinfo[y].right + 1 ;

		joblist[i].top = ylist[y].pos ;
		joblist[i].bottom = ylist[y].pos + ylist[y].len ;
	}
	if ( joblist[i].newtop + ylist[y].len > ScreenHeight) { // ��ҳ
		joblist[i-1].action += 5 ;
		joblist[i].action = 1 ;
		nScreenHeight = 0 ;
		joblist[i].newtop = nScreenHeight ;
	}
}
	return i ;
}


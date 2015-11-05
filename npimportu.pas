unit npimportu;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,inifiles,strutils,
  StdCtrls, ComCtrls, ExtCtrls, FileCtrl,shellapi, xmldom, XMLIntf,tt_ttsystem,tt_tttextconv,
  XSLProd, msxmldom, XMLDoc, faststrings,Menus,tt_ttstring,tt_ttdatetime,TTToolsDeluxe_tlb,
  tt_ttfile,tt_ttclasses,ttcompression,tt_news_ttnitf;

type
  TNPimp = class(TForm)
    filer: TFileListBox;
    Splitter1: TSplitter;
    listan: TRichEdit;
    Timer1: TTimer;
    Timer2: TTimer;
    MainMenu1: TMainMenu;
    Visa1: TMenuItem;
    Katalog1: TMenuItem;
    Inkommandekatalog1: TMenuItem;
    Visainifilen1: TMenuItem;
    XMLDocument1: TXMLDocument;
    XSLpp: TXSLPageProducer;
    zipfil: TFileListBox;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Timer2Timer(Sender: TObject);
    procedure Rapportera (vad : string;Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure KollaMappen (sender : Tobject;sektionsnamn : string);
    procedure Katalog1Click(Sender: TObject);
    procedure Inkommandekatalog1Click(Sender: TObject);
    procedure Visainifilen1Click(Sender: TObject);
    procedure Skrivtilllogg (text,loggfilnamn : string);
    procedure ProcessaTTNITF (sender : tobject;filnamn,xsltfilnamn : string);
    function KollaSommartid: string;
    procedure ProcessaEnXMLfilmedXSLTochSparaTillNPimport (sender:tobject;filnamn:string;xsltfil:string);
    procedure ProcessaNEWSML(sender : tobject;filnamn,xsltfilnamn:string);
    procedure ProcessaTTNINJS(sender : tobject;filnamn,xsltfilnamn:string);
  private
    { Private declarations }
    nyheartbeat : TTHeartBeater;
  public
    { Public declarations }
    utfil,infil : tstringlist;
    exepath, datapath,sparpath,loggfilnamn,temppath : string;
    programnamn : string;
    inifil : tinifile;
    intervall : integer;
  end;

var
  NPimp: TNPimp;

implementation

{$R *.DFM}

//=================== Changes =========//
//
//     20150902 JL lade till kontroll mot dubbelimport n�r b�de xml och json skickas
//
//
//
//==================================================//




//=================== Run once when instance is created =========//
//
// Johan Lindgren 2015-06-10
//
//==================================================//
procedure TNPimp.FormCreate(Sender: TObject);
begin
  exepath := extractfilepath (application.exename); //Get the path to this instance
  exepath := kollaslutet (exepath,'\'); //Make sure it ends with a backslash

  inifil := tinifile.create (exepath+'NPimport.ini'); //Create an ini-file in the path of the instance

  temppath := exepath+'temp\';  //Set up a temp-path
  forcedirectories(temppath); //Make sure it exists

  programnamn := inifil.readstring('Settings','Programnamn','NPimport'); //Read the setting for the name of the aplication, with NPimport as default

  timer2.Interval := inifil.ReadInteger ('Settings','Heartbeat',60)*1000; //Read the setting for heartbeats

  timer1.Enabled := true; //Make sure timer1 is enabled
  timer2.Enabled := true; //Make sure timer2 is enabled

  infil := tstringlist.create;  //Create a stringlist for reading a file
  utfil := tstringlist.create;  //Create a stringlist for writing a file

  nyheartbeat := TTHeartBeater.Create(programnamn);
  nyheartbeat.RaiseExceptionOnError := false;

  loggfilnamn := inifil.readstring('Settings','Loggfil','[EXEPATH]npimport_[DATUM].log'); //Filnamn f�r loggning av rubens aktiviteter. Tomt filnamn betyder ingen loggning
  loggfilnamn := stringreplace(loggfilnamn,'[EXEPATH]',exepath);
  loggfilnamn := stringreplace(loggfilnamn,'[DATUM]',idag);

  if inifil.ValueExists('Placering','Top') then begin
    Top := inifil.ReadInteger('Placering','Top',100);
    Left := inifil.ReadInteger('Placering','LEft',100);
    Width := inifil.ReadInteger('Placering','Width',400);
    Height := inifil.ReadInteger('Placering','Height',300);
  end;

  NPimp.Caption := NPimp.caption + ' Startad: '+idag+' '+klockannu; //Tala om i huvudraden n�r programmet startades

  Skrivtilllogg('NP import startat',loggfilnamn);

  Rapportera ('Startar NPimport '+idag+' '+klockannu,sender);

end;

//=================== When the program instance is stopped =========//
//
// Johan Lindgren 2015-06-13
//
//==================================================//
procedure TNPimp.FormDestroy(Sender: TObject);
begin
  inifil.WriteInteger('Placering','Top',Top);
  inifil.WriteInteger('Placering','Left',left);
  inifil.WriteInteger('Placering','Width',width);
  inifil.WriteInteger('Placering','Height',height);
  inifil.free; //Frig�r resursen f�r inifilen

  nyheartbeat.Free;

  infil.Free; //frig�r resursen
  utfil.Free; //frig�r resursen
end;

//=========== Skriv en text till loggfilen. Loggen skapas om den inte finns ===========//
procedure TNPimp.Skrivtilllogg (text,loggfilnamn : string);
var
  loggfil : textfile;
begin
  if loggfilnamn <> '' then begin //Om vi har n�got inneh�ll i variabeln
    try               //F�rs�k
      AssignFile(loggfil,loggfilnamn); //Skapa en koppling till en textfil
      if fileexists (loggfilnamn) then  //om filen finns
        Append(loggfil)        //L�gg till text
      else                     //annars
        rewrite (loggfil);             //Skapar vi filen
      Writeln(loggfil, '['+idag+' '+klockannu+'] '+ text);     //Skriv ut den �nskade rden
      Flush(loggfil);  // ensures that the text was actually written to file
    finally               //slutligen
      CloseFile(loggfil);            //st�ng filen
    end; //try finally
  end; //om vi har en loggfil angiven
end; //Skriv till logg

//================ N�r timer 2 tickar till skall heartbeat skickas ===========//
//
// Johan Lindgren 2015-06-13
//
//==================================================//
procedure TNPimp.Timer2Timer(Sender: TObject);
begin
  nyheartbeat.SendHeartBeat;
end;

//=========== Notera vad som h�nder i listan ==========//
procedure TNPimp.Rapportera (vad : string;Sender: TObject);
begin
  if listan.lines.count > 500 then listan.lines.clear;  //Om vi har �ver 100 rader s� rensar vi
  listan.lines.add(vad); //Skriv ut vilken vi behandlar
  listan.Refresh; //Fr�scha upp listan s� vi ser vad som skrivits
  listan.perform (em_scrollcaret,0,0);//(em_linescroll,0,1); //Scrolla upp en rad
end; //rapportera till listan

//=================== N�r timer 1 tickar till =========//
//
// Johan Lindgren 2015-06-13
//
//==================================================//
procedure TNPimp.Timer1Timer(Sender: TObject);
var
  i : integer;
  sektionsnamn : string;
  mapplista : tstringlist;
begin
  timer1.Enabled := false;
  timer2.Enabled := false;

  screen.Cursor := crHourglass; //L�gg upp ett timglas

  mapplista := tstringlist.create;

  try
    loggfilnamn := inifil.readstring('Settings','Loggfil','[EXEPATH]npimport_[DATUM].log'); //Filnamn f�r loggning av rubens aktiviteter. Tomt filnamn betyder ingen loggning
    loggfilnamn := stringreplace(loggfilnamn,'[EXEPATH]',exepath);
    loggfilnamn := stringreplace(loggfilnamn,'[DATUM]',idag);

    Intervall := inifil.readinteger ('Settings','Intervall',60)*1000; //Hur ofta programmet skall kolla efter nya filer

    inifil.ReadSectionValues('Mapplista',mapplista);  //Om vi har flera NP-instanser som vi bevakar

    for i := 0 to mapplista.Count - 1 do begin //G� igenom  alla instanser

      sektionsnamn := trim(mapplista.ValueFromIndex[i]);  //L�s ut ett sektionsnamn

      if sektionsnamn <> '' then begin //Om det inte �r tomt g�r vi vidare

        KollaMappen (sender,sektionsnamn); //Anropa metoden f�r att kolla denna sektion

      end;
    end;

  finally
    mapplista.free;
    timer1.Interval := intervall; //St�ll in intervall
    filer.Directory := exepath; //St�ll tillbaka fillistan till programkatalogen
    filer.Update; //Uppdatera fillistan
    screen.cursor := crDefault; //�terst�ll musmark�ren
    timer1.enabled := true; //Aktivera tidtagaren igen
    timer2.Enabled := true;
  end;
end;

//=================== Kolla i mappen �ver inkommande =========//
//
// Johan Lindgren 2015-06-21
//
//==================================================//
procedure TNPimp.KollaMappen (sender : Tobject;sektionsnamn : string);
var
  zipfilnamn,filnamn,senastefilnamn,xsltfilnamn : string;
  i,j,filedate : integer;
begin
  datapath := inifil.ReadString (sektionsnamn,'Datapath',exepath+'npimport\'); //L�s in s�kv�g till filer att bearbeta
  datapath := stringreplaceall(datapath,'[EXEPATH]',exepath);
  datapath := kollaslutet (datapath,'\'); //Se till att den slutar med en backslash
  forcedirectories (datapath);

  sparpath := inifil.ReadString (sektionsnamn,'sparpath',exepath+'2np\'); //L�s in s�kv�g till var bearbetade filer ska l�ggas f�r import i NP
  sparpath := stringreplaceall(sparpath,'[EXEPATH]',exepath);
  sparpath := kollaslutet (sparpath,'\'); //Se till att den slutar med en backslash
  forcedirectories (sparpath);

  filer.directory := datapath; //St�ll in datapath i fil-katalogen
  filer.update; //Uppdatera inneh�llet

  Rapportera ('Kollar '+datapath+' '+idag+' '+klockannu,sender); //Visa i loggrutan vad som sker

  if filer.Items.Count > 0 then begin //Om vi har n�gra filer att behandla

    senastefilnamn := '';
    Sleep(10000); //Ta en micropaus s� alla filer �r f�rdigsparade

    try // f�rs�k ... finally

      for i := 0 to filer.items.count -1 do begin //G� igenom alla filer

        infil.Clear; //Rensa str�nglistan f�r att l�sa in en fil
        filnamn := filer.items[i]; //Ta in ett filnamn
        zipfil.Directory := exepath;
        zipfil.Refresh;

        Skrivtilllogg('Hittat '+filnamn,loggfilnamn); //Visa i loggrutan vad som sker


        if (endswith(ansilowercase(filnamn),'.zip')) then begin   //Om det �r en zip
          try
            Rapportera('Zippar upp '+filnamn,sender);   //Visa i loggrutan vad som sker
            DeCompressFile(datapath+filnamn,temppath); //Zippa upp till tempmappen
            zipfil.Directory := temppath;  //Lista filerna vi fick dit
            zipfil.Refresh;

            for j := 0 to zipfil.Items.Count - 1 do begin //G� igenom filerna som d�k upp

              zipfilnamn := zipfil.Items[j];
              if (endswith(ansilowercase(zipfilnamn),'.xml')) or (endswith(ansilowercase(zipfilnamn),'.jpg')) then begin  //Vi plockar xml och jpg ur zippen och l�gger f�r normal bearbetning
                PjerMoveFile(temppath+zipfilnamn,datapath+zipfilnamn,true);  //D� flyttar vi filen till mappen f�r normal bearbetning
              end
              else begin //Om det var n�gon annan filtyp s� raderar vi den
                deletefile(temppath+zipfilnamn);
              end;

              rapportera ('Fixat '+zipfilnamn+' som fanns i zippen.',sender);   //Visa i loggrutan vad som sker

            end;
          except
            on e: exception do begin
              rapportera('Problem vid unzip: '+e.Message,sender);
            end;

          end;
        end;


        // Om det �r en xml-fil, en ttt-fil eller en json-fil s� ska den bearbetas
        if ((endswith(ansilowercase(filnamn),'.xml')) or (endswith(ansilowercase(filnamn),'.ttt')) or (endswith(ansilowercase(filnamn),'.json')))
          and (senastefilnamn <> changefileext(filnamn,''))  then begin  //Kolla ocks� s� det inte �r samma filnamn som senastefilnamn s� slipper vi dubletter. TT skickar b�de json och xml

          infil.LoadFromFile (datapath+filnamn); //L�s in filen

          if pos('{"uri":"http://tt.se/',infil.Text) > 0 then begin //Om vi har detta s� �r det en json    'import_TTNINJS_NPDOC.xsl'
            xsltfilnamn := trim(inifil.ReadString (sektionsnamn,'TTNINJS_XSLT','import_TTNINJS_NPDOC.xsl')); //L�s in s�kv�g till filer att bearbeta
            if xsltfilnamn <> '' then begin
              ProcessaTTNINJS(sender,filnamn,xsltfilnamn);     //Anropa json-bearbetningen
              senastefilnamn := changefileext(filnamn,'');  //Vi noterar senaste filnamn utan filtyp
            end;
          end
          else begin
            if pos('<newsMessage>',infil.Text) > 0 then begin //Om den har en <newsMessage> s� �r det en NewsML-fil  'import_TTNEWSML_NPDOC.xsl'
              xsltfilnamn := trim(inifil.ReadString (sektionsnamn,'TTNEWSML_XSLT','import_TTNEWSML_NPDOC.xsl')); //L�s in s�kv�g till filer att bearbeta
              if xsltfilnamn <> '' then begin
                ProcessaNEWSML(sender,filnamn,xsltfilnamn);
                senastefilnamn := changefileext(filnamn,'');   //Vi noterar senaste filnamn utan filtyp
              end;
            end
            else begin
              if pos('<TTNITF>',infil.Text) > 0 then begin  //Om den har TTNITF       'import_TTNITF_NPDOC.xsl'
                xsltfilnamn := trim(inifil.ReadString (sektionsnamn,'TTNITF_XSLT','import_TTNITF_NPDOC.xsl')); //L�s in s�kv�g till filer att bearbeta
                if xsltfilnamn <> '' then begin
                  ProcessaTTNITF(sender,filnamn,xsltfilnamn);  //S� bearbeta som TTNITF
                  senastefilnamn := changefileext(filnamn,'');   //Vi noterar senaste filnamn utan filtyp
                end;  
              end;
            end;
          end;
        end;

        if endswith(ansilowercase(filnamn),'.jpg') then  begin
          filedate := fileage(datapath+filnamn);
          if FileDateToDateTime( filedate) + 1 < now  then begin
            Rapportera(filnamn+ ' �r �ldre �n en dag s� vi raderar den.',sender);
            deletefile(datapath+filnamn);
          end;


        end;


        if (not (endswith(ansilowercase(filnamn),'.crdownload'))) and (not (endswith(ansilowercase(filnamn),'.jpg'))) then
          deletefile (datapath+filnamn); //Radera andra filer som kan t�nkas dyka upp

        nyheartbeat.SendHeartBeat;

      end; //for i

    finally  //slutligen

    end; //try finally
    zipfil.Directory := exepath;
    zipfil.Refresh;

  end; //if filer

  nyheartbeat.SendHeartBeat;

end;


//========================= Om det �r NewsML s� k�r vi denna variant ===================================//
//
//  Johan Lindgren 2015-06-20
//
//==============================================================================//
procedure TNPimp.ProcessaNEWSML(sender : tobject;filnamn,xsltfilnamn:string);
begin
  infil.SaveToFile(exepath+'testfil_newsml.xml'); //Spara filen i samma mapp som instansen. OBS - bara f�r test�ndam�l
  ProcessaEnXMLfilmedXSLTochSparaTillNPimport(sender,filnamn,xsltfilnamn); //H�r har vi redan xml s� det �r bara att anropa slutsteget med r�tt filter
end;


//========================= Om det �r json s� k�r vi denna variant ===================================//
//
//  Johan Lindgren 2015-06-20
//
//==============================================================================//
procedure TNPimp.ProcessaTTNINJS(sender : tobject;filnamn,xsltfilnamn:string);
begin

  if pos('<?xml', infil.text) < 1 then begin  //F�r att XSLT ska funka m�ste vi l�gga in det i ett XML-kuvert. S� saknas XML k�r vi dessa steg
    infil.Text := UTF8Decode(infil.text); //Konvertera fr�n UTF8
    infil.Text := BytSGML2win(infil.text);  //G�r om SGML-entiteterna till windows-tecken
    infil.Text := fastreplace(infil.text,'\"','"'); //Fixa dessa tecken
    infil.text := '<?xml version="1.0" encoding="UTF-8"?><TTNINJS><![CDATA['+infil.text+']]></TTNINJS>'; //L�gg xml runt s� xslt fungerar
    infil.Text := UTF8Encode(infil.text); // g�r om till utf igen
  end;

  infil.SaveToFile(exepath+'testfil_json.xml'); //Spara filen i samma mapp som instansen. OBS - bara f�r test�ndam�l
  infil.SaveToFile(datapath+filnamn); //Spara filen s� slutbearbetningen kan anv�nda den

  ProcessaEnXMLfilmedXSLTochSparaTillNPimport(sender,filnamn,xsltfilnamn);   //Anropa slutbearbetningen med det filter som funkar p� json i XML-kuvert
end;


//========================= Om det �r TTNITF s� k�r vi denna variant ===================================//
//
//  Johan Lindgren 2015-06-20
//
//==============================================================================//
procedure TNPimp.ProcessaTTNITF (sender : tobject;filnamn,xsltfilnamn : string);
var
  temptext : string;
begin
  if pos('<?xml', infil.text) < 1 then begin  //Om vi har TTNITF men i det �ldre SGML-formatet s� m�ste vi g�ra XML av det f�rst
    temptext := infil.text; //Kopiera texten
    RensaTTNITF(temptext); //Rensa vissa interna och gamla saker
    TTNITF2XML(temptext); //G�r om till XML
    infil.text := temptext;  //L�gg tillbaka i str�nglistan
  end;

  infil.Text := BytSGML2win(infil.text); //Se till att alla entiteter �r omgjorda till windows-tecken

  infil.SaveToFile(datapath+filnamn); //Spara tillbaka filen s� slutbearbetningen kan anv�nda den

  ProcessaEnXMLfilmedXSLTochSparaTillNPimport(sender,filnamn,xsltfilnamn); //Anropa slutbearbetningen med filter f�r TTNITF i XML-version
end;


//========================= Slutsteg till NP ===================================//
//
//  Johan Lindgren 2015-06-20
//
//==============================================================================//
procedure TNPimp.ProcessaEnXMLfilmedXSLTochSparaTillNPimport (sender:tobject;filnamn:string;xsltfil:string);
var
  rentfilnamn,enbild,nybild,nummer,enimage,nyimage,temptext : string;
  inummer : integer;
begin
  xmldocument1.ParseOptions := [];  //Nollst�ll detta f�r s�kerhetsskull
  xmldocument1.FileName := datapath+filnamn; //S�tt in filnamnet p� XML-filen som ska bearbetas i xmldoc-komponenten
  xmldocument1.Active := true; //Aktivera den
  xslpp.FileName := exepath+xsltfil; //Plocka in xslfilen som ska anv�ndas f�r bearbetningen
  xslpp.Active := true; //Aktivera xsl-komponenten, d� k�rs transformeringen
  temptext := xslpp.Content; //H�mta ut det f�rdiga resultatet
  xslpp.Active := false; //st�ng av xsl-komponenten
  xmldocument1.Active := false; //St�ng av xml-komponenten

  infil.text := UTF8Decode(temptext);
  if infil.text = '' then infil.text := temptext;
  
  infil.Text := stringreplace(infil.text,'encoding="UTF-16"','');
  infil.Text := stringreplace(infil.text,'encoding="utf-16"','');
  infil.Text := stringreplace(infil.text,'encoding="UTF-8"','');
  infil.Text := stringreplace(infil.text,'encoding="utf-8"','');

  //Eftersom XSLT 1.0 inte har n�gon funktion f�r att ta fram aktuellt datum och tid s� fixar vi det h�r
  infil.Text := fastreplace(infil.Text,'[#currentDateTime]',copy(idag,1,4)+'-'+copy(idag,5,2)+'-'+copy(idag,7,2)+'T'+copy(klockannu,1,2)+':'+copy(klockannu,3,2)+':'+copy(klockannu,5,2)+'+0'+KollaSommartid+':00');
  infil.Text := fastreplace(infil.Text,'[#tomorrowDateTime]',copy(julian2date(date2julian(idag)+1),1,4)+'-'+copy(julian2date(date2julian(idag)+1),5,2)+'-'+copy(julian2date(date2julian(idag)+1),7,2)+'T'+copy(klockannu,1,2)+':'+copy(klockannu,3,2)+':'+copy(klockannu,5,2)+'+0'+KollaSommartid+':00');
  infil.Text := fastreplace(infil.Text,'xmlns=""',''); //Rensa eventuellt tomma namespaces som xslt l�mnat efter sig

  rentfilnamn := stringreplace(filnamn,ExtractFileExt(filnamn),''); //Ta bort �ndelsen fr�n filnamnet p� filen vi bearbetat

{                   <image id="-a000" refType="Image">
                     <name>[#BILD:a000]</name>
                     <data src="[#BILD:a000]"/>
                  </image>
}

  while pos('[#BILD:',infil.text)  > 0 do begin  //G� igenom alla st�llen d�r vi lagt variabeln [#BILD:
    enbild := hamtastrengink(infil.text,'[#BILD:',']'); //H�mta sj�lva bildinfon
    nummer := hamtastrengmellan(enbild,'[#BILD:a',']');  //Plocka ut numret
    inummer := strtointdef(nummer,0)+1;   //Omvandla till en integer och l�gg p� 1
    nummer := rightstr('0'+inttostr(inummer),2); //Skapa ett nytt tresiffrigt nummer
    nybild := rentfilnamn+'-'+nummer+'nh.jpg';  //Skapa ett nytt filnamn f�r bilden
    infil.text := stringreplace(infil.text,enbild,nybild); //L�gg in det ist�llet f�r bildinfon vi plockade ut
    if fileexists(datapath+nybild) then begin  //Om vi har bilden tillg�nglig
      try
        PjerMoveFile(datapath+nybild,sparpath+nybild,true);  //Flytta bilden till mappen d�r den ska importeras av NP, men NP bryr sig inte om jpg f�rr�n en npdoc som refererar den kommer dit
      except
        on e: exception do begin
          rapportera('Fel vid bildflytt: '+e.Message,sender);
        end;
      end;
    end;
  end;

  infil.SaveToFile(exepath+'testfil_steg2.xml'); //Spara filen i samma mapp som instansen. OBS - bara f�r test�ndam�l

  while pos('<image ',infil.text) > 0 do begin //G� igenom alla image-element efter att de st�dats enligt ovan
    enimage := hamtastrengink(infil.Text,'<image ','</image>');
    nyimage := stringreplace(enimage,'<image ','<IMAGE '); //Ifall vi ska ha kvar bilden vill vi inte skapa en loop
    enbild := hamtastrengmellan (enimage,'<name>','</name>'); //H�mta ut sj�lva bildnamnet
    if fileexists(sparpath+enbild) then begin //Om bildfilen finns tillg�nglig f�r NP-importen
      infil.text := stringreplace(infil.text,enimage,nyimage); //D� byter vi bara ut s� vi inte loopar
    end
    else begin
      infil.text := stringreplace(infil.text,enimage,'');  //Fins inte bilden tar vi bort bildreferensen f�r annars spricker importen
    end;

  end;

  infil.text := fastreplace(infil.text,'<IMAGE ','<image '); //N�r vi g�tt igenom alla image s� kan vi �terst�lla till gement p� de som �r kvar.

  infil.Text := stringreplace(infil.text,'?>',' encoding="UTF-8"?>');
  infil.Text :=  UTF8Encode(infil.text);    //Se till att det �r UTF8-encodat

  infil.SaveToFile(sparpath+filnamn+'.npdoc');  //Spara till mappen f�r att NP ska importera
  infil.SaveToFile(exepath+'testfil_ut.xml'); //Bara f�r TEST-�ndam�l

  Rapportera('['+idag+' '+klockannu+'] Processat '+filnamn,sender);   //Visa vad vi gjort
  Skrivtilllogg('['+idag+' '+klockannu+'] Processat '+filnamn+' med '+xsltfil,loggfilnamn);  //Logga vad vi gjort

end;





//========================= Kollar om vi har sommartid eller inte ===================================//
//
//  Johan Lindgren 2015-06-20
//
//==============================================================================//
function TNPimp.KollaSommartid: string;
var
  Error: Double;
  TimeZone: TTimeZoneInformation;
begin
  Error := GetTimeZoneInformation(TimeZone);
  Result := floattostr(Error);
end;


//========================= Menyklick i appen ===================================//
//
//  Johan Lindgren 2015-06-20
//
//==============================================================================//


procedure TNPimp.Katalog1Click(Sender: TObject);
begin
  shellexecute (application.handle,pchar('open'),pchar(exepath),Nil,Nil,SW_SHOW); //Visa programmets katalog
end;

procedure TNPimp.Inkommandekatalog1Click(Sender: TObject);
begin
  shellexecute (application.handle,pchar('open'),pchar(datapath),Nil,Nil,SW_SHOW); //Visa programmets katalog
end;

procedure TNPimp.Visainifilen1Click(Sender: TObject);
begin
  shellexecute (application.handle,pchar('open'),pchar(exepath+'npimport.ini'),Nil,Nil,SW_SHOW); //Visa programmets katalog

end;


end.

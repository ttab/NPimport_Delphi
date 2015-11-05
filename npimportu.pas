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
//     20150902 JL lade till kontroll mot dubbelimport när både xml och json skickas
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

  loggfilnamn := inifil.readstring('Settings','Loggfil','[EXEPATH]npimport_[DATUM].log'); //Filnamn för loggning av rubens aktiviteter. Tomt filnamn betyder ingen loggning
  loggfilnamn := stringreplace(loggfilnamn,'[EXEPATH]',exepath);
  loggfilnamn := stringreplace(loggfilnamn,'[DATUM]',idag);

  if inifil.ValueExists('Placering','Top') then begin
    Top := inifil.ReadInteger('Placering','Top',100);
    Left := inifil.ReadInteger('Placering','LEft',100);
    Width := inifil.ReadInteger('Placering','Width',400);
    Height := inifil.ReadInteger('Placering','Height',300);
  end;

  NPimp.Caption := NPimp.caption + ' Startad: '+idag+' '+klockannu; //Tala om i huvudraden när programmet startades

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
  inifil.free; //Frigör resursen för inifilen

  nyheartbeat.Free;

  infil.Free; //frigör resursen
  utfil.Free; //frigör resursen
end;

//=========== Skriv en text till loggfilen. Loggen skapas om den inte finns ===========//
procedure TNPimp.Skrivtilllogg (text,loggfilnamn : string);
var
  loggfil : textfile;
begin
  if loggfilnamn <> '' then begin //Om vi har något innehåll i variabeln
    try               //Försök
      AssignFile(loggfil,loggfilnamn); //Skapa en koppling till en textfil
      if fileexists (loggfilnamn) then  //om filen finns
        Append(loggfil)        //Lägg till text
      else                     //annars
        rewrite (loggfil);             //Skapar vi filen
      Writeln(loggfil, '['+idag+' '+klockannu+'] '+ text);     //Skriv ut den önskade rden
      Flush(loggfil);  // ensures that the text was actually written to file
    finally               //slutligen
      CloseFile(loggfil);            //stäng filen
    end; //try finally
  end; //om vi har en loggfil angiven
end; //Skriv till logg

//================ När timer 2 tickar till skall heartbeat skickas ===========//
//
// Johan Lindgren 2015-06-13
//
//==================================================//
procedure TNPimp.Timer2Timer(Sender: TObject);
begin
  nyheartbeat.SendHeartBeat;
end;

//=========== Notera vad som händer i listan ==========//
procedure TNPimp.Rapportera (vad : string;Sender: TObject);
begin
  if listan.lines.count > 500 then listan.lines.clear;  //Om vi har över 100 rader så rensar vi
  listan.lines.add(vad); //Skriv ut vilken vi behandlar
  listan.Refresh; //Fräscha upp listan så vi ser vad som skrivits
  listan.perform (em_scrollcaret,0,0);//(em_linescroll,0,1); //Scrolla upp en rad
end; //rapportera till listan

//=================== När timer 1 tickar till =========//
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

  screen.Cursor := crHourglass; //Lägg upp ett timglas

  mapplista := tstringlist.create;

  try
    loggfilnamn := inifil.readstring('Settings','Loggfil','[EXEPATH]npimport_[DATUM].log'); //Filnamn för loggning av rubens aktiviteter. Tomt filnamn betyder ingen loggning
    loggfilnamn := stringreplace(loggfilnamn,'[EXEPATH]',exepath);
    loggfilnamn := stringreplace(loggfilnamn,'[DATUM]',idag);

    Intervall := inifil.readinteger ('Settings','Intervall',60)*1000; //Hur ofta programmet skall kolla efter nya filer

    inifil.ReadSectionValues('Mapplista',mapplista);  //Om vi har flera NP-instanser som vi bevakar

    for i := 0 to mapplista.Count - 1 do begin //Gå igenom  alla instanser

      sektionsnamn := trim(mapplista.ValueFromIndex[i]);  //Läs ut ett sektionsnamn

      if sektionsnamn <> '' then begin //Om det inte är tomt går vi vidare

        KollaMappen (sender,sektionsnamn); //Anropa metoden för att kolla denna sektion

      end;
    end;

  finally
    mapplista.free;
    timer1.Interval := intervall; //Ställ in intervall
    filer.Directory := exepath; //Ställ tillbaka fillistan till programkatalogen
    filer.Update; //Uppdatera fillistan
    screen.cursor := crDefault; //Återställ musmarkören
    timer1.enabled := true; //Aktivera tidtagaren igen
    timer2.Enabled := true;
  end;
end;

//=================== Kolla i mappen över inkommande =========//
//
// Johan Lindgren 2015-06-21
//
//==================================================//
procedure TNPimp.KollaMappen (sender : Tobject;sektionsnamn : string);
var
  zipfilnamn,filnamn,senastefilnamn,xsltfilnamn : string;
  i,j,filedate : integer;
begin
  datapath := inifil.ReadString (sektionsnamn,'Datapath',exepath+'npimport\'); //Läs in sökväg till filer att bearbeta
  datapath := stringreplaceall(datapath,'[EXEPATH]',exepath);
  datapath := kollaslutet (datapath,'\'); //Se till att den slutar med en backslash
  forcedirectories (datapath);

  sparpath := inifil.ReadString (sektionsnamn,'sparpath',exepath+'2np\'); //Läs in sökväg till var bearbetade filer ska läggas för import i NP
  sparpath := stringreplaceall(sparpath,'[EXEPATH]',exepath);
  sparpath := kollaslutet (sparpath,'\'); //Se till att den slutar med en backslash
  forcedirectories (sparpath);

  filer.directory := datapath; //Ställ in datapath i fil-katalogen
  filer.update; //Uppdatera innehållet

  Rapportera ('Kollar '+datapath+' '+idag+' '+klockannu,sender); //Visa i loggrutan vad som sker

  if filer.Items.Count > 0 then begin //Om vi har några filer att behandla

    senastefilnamn := '';
    Sleep(10000); //Ta en micropaus så alla filer är färdigsparade

    try // försök ... finally

      for i := 0 to filer.items.count -1 do begin //Gå igenom alla filer

        infil.Clear; //Rensa stränglistan för att läsa in en fil
        filnamn := filer.items[i]; //Ta in ett filnamn
        zipfil.Directory := exepath;
        zipfil.Refresh;

        Skrivtilllogg('Hittat '+filnamn,loggfilnamn); //Visa i loggrutan vad som sker


        if (endswith(ansilowercase(filnamn),'.zip')) then begin   //Om det är en zip
          try
            Rapportera('Zippar upp '+filnamn,sender);   //Visa i loggrutan vad som sker
            DeCompressFile(datapath+filnamn,temppath); //Zippa upp till tempmappen
            zipfil.Directory := temppath;  //Lista filerna vi fick dit
            zipfil.Refresh;

            for j := 0 to zipfil.Items.Count - 1 do begin //Gå igenom filerna som dök upp

              zipfilnamn := zipfil.Items[j];
              if (endswith(ansilowercase(zipfilnamn),'.xml')) or (endswith(ansilowercase(zipfilnamn),'.jpg')) then begin  //Vi plockar xml och jpg ur zippen och lägger för normal bearbetning
                PjerMoveFile(temppath+zipfilnamn,datapath+zipfilnamn,true);  //Då flyttar vi filen till mappen för normal bearbetning
              end
              else begin //Om det var någon annan filtyp så raderar vi den
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


        // Om det är en xml-fil, en ttt-fil eller en json-fil så ska den bearbetas
        if ((endswith(ansilowercase(filnamn),'.xml')) or (endswith(ansilowercase(filnamn),'.ttt')) or (endswith(ansilowercase(filnamn),'.json')))
          and (senastefilnamn <> changefileext(filnamn,''))  then begin  //Kolla också så det inte är samma filnamn som senastefilnamn så slipper vi dubletter. TT skickar både json och xml

          infil.LoadFromFile (datapath+filnamn); //Läs in filen

          if pos('{"uri":"http://tt.se/',infil.Text) > 0 then begin //Om vi har detta så är det en json    'import_TTNINJS_NPDOC.xsl'
            xsltfilnamn := trim(inifil.ReadString (sektionsnamn,'TTNINJS_XSLT','import_TTNINJS_NPDOC.xsl')); //Läs in sökväg till filer att bearbeta
            if xsltfilnamn <> '' then begin
              ProcessaTTNINJS(sender,filnamn,xsltfilnamn);     //Anropa json-bearbetningen
              senastefilnamn := changefileext(filnamn,'');  //Vi noterar senaste filnamn utan filtyp
            end;
          end
          else begin
            if pos('<newsMessage>',infil.Text) > 0 then begin //Om den har en <newsMessage> så är det en NewsML-fil  'import_TTNEWSML_NPDOC.xsl'
              xsltfilnamn := trim(inifil.ReadString (sektionsnamn,'TTNEWSML_XSLT','import_TTNEWSML_NPDOC.xsl')); //Läs in sökväg till filer att bearbeta
              if xsltfilnamn <> '' then begin
                ProcessaNEWSML(sender,filnamn,xsltfilnamn);
                senastefilnamn := changefileext(filnamn,'');   //Vi noterar senaste filnamn utan filtyp
              end;
            end
            else begin
              if pos('<TTNITF>',infil.Text) > 0 then begin  //Om den har TTNITF       'import_TTNITF_NPDOC.xsl'
                xsltfilnamn := trim(inifil.ReadString (sektionsnamn,'TTNITF_XSLT','import_TTNITF_NPDOC.xsl')); //Läs in sökväg till filer att bearbeta
                if xsltfilnamn <> '' then begin
                  ProcessaTTNITF(sender,filnamn,xsltfilnamn);  //Så bearbeta som TTNITF
                  senastefilnamn := changefileext(filnamn,'');   //Vi noterar senaste filnamn utan filtyp
                end;  
              end;
            end;
          end;
        end;

        if endswith(ansilowercase(filnamn),'.jpg') then  begin
          filedate := fileage(datapath+filnamn);
          if FileDateToDateTime( filedate) + 1 < now  then begin
            Rapportera(filnamn+ ' är äldre än en dag så vi raderar den.',sender);
            deletefile(datapath+filnamn);
          end;


        end;


        if (not (endswith(ansilowercase(filnamn),'.crdownload'))) and (not (endswith(ansilowercase(filnamn),'.jpg'))) then
          deletefile (datapath+filnamn); //Radera andra filer som kan tänkas dyka upp

        nyheartbeat.SendHeartBeat;

      end; //for i

    finally  //slutligen

    end; //try finally
    zipfil.Directory := exepath;
    zipfil.Refresh;

  end; //if filer

  nyheartbeat.SendHeartBeat;

end;


//========================= Om det är NewsML så kör vi denna variant ===================================//
//
//  Johan Lindgren 2015-06-20
//
//==============================================================================//
procedure TNPimp.ProcessaNEWSML(sender : tobject;filnamn,xsltfilnamn:string);
begin
  infil.SaveToFile(exepath+'testfil_newsml.xml'); //Spara filen i samma mapp som instansen. OBS - bara för teständamål
  ProcessaEnXMLfilmedXSLTochSparaTillNPimport(sender,filnamn,xsltfilnamn); //Här har vi redan xml så det är bara att anropa slutsteget med rätt filter
end;


//========================= Om det är json så kör vi denna variant ===================================//
//
//  Johan Lindgren 2015-06-20
//
//==============================================================================//
procedure TNPimp.ProcessaTTNINJS(sender : tobject;filnamn,xsltfilnamn:string);
begin

  if pos('<?xml', infil.text) < 1 then begin  //För att XSLT ska funka måste vi lägga in det i ett XML-kuvert. Så saknas XML kör vi dessa steg
    infil.Text := UTF8Decode(infil.text); //Konvertera från UTF8
    infil.Text := BytSGML2win(infil.text);  //Gör om SGML-entiteterna till windows-tecken
    infil.Text := fastreplace(infil.text,'\"','"'); //Fixa dessa tecken
    infil.text := '<?xml version="1.0" encoding="UTF-8"?><TTNINJS><![CDATA['+infil.text+']]></TTNINJS>'; //Lägg xml runt så xslt fungerar
    infil.Text := UTF8Encode(infil.text); // gör om till utf igen
  end;

  infil.SaveToFile(exepath+'testfil_json.xml'); //Spara filen i samma mapp som instansen. OBS - bara för teständamål
  infil.SaveToFile(datapath+filnamn); //Spara filen så slutbearbetningen kan använda den

  ProcessaEnXMLfilmedXSLTochSparaTillNPimport(sender,filnamn,xsltfilnamn);   //Anropa slutbearbetningen med det filter som funkar på json i XML-kuvert
end;


//========================= Om det är TTNITF så kör vi denna variant ===================================//
//
//  Johan Lindgren 2015-06-20
//
//==============================================================================//
procedure TNPimp.ProcessaTTNITF (sender : tobject;filnamn,xsltfilnamn : string);
var
  temptext : string;
begin
  if pos('<?xml', infil.text) < 1 then begin  //Om vi har TTNITF men i det äldre SGML-formatet så måste vi göra XML av det först
    temptext := infil.text; //Kopiera texten
    RensaTTNITF(temptext); //Rensa vissa interna och gamla saker
    TTNITF2XML(temptext); //Gör om till XML
    infil.text := temptext;  //Lägg tillbaka i stränglistan
  end;

  infil.Text := BytSGML2win(infil.text); //Se till att alla entiteter är omgjorda till windows-tecken

  infil.SaveToFile(datapath+filnamn); //Spara tillbaka filen så slutbearbetningen kan använda den

  ProcessaEnXMLfilmedXSLTochSparaTillNPimport(sender,filnamn,xsltfilnamn); //Anropa slutbearbetningen med filter för TTNITF i XML-version
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
  xmldocument1.ParseOptions := [];  //Nollställ detta för säkerhetsskull
  xmldocument1.FileName := datapath+filnamn; //Sätt in filnamnet på XML-filen som ska bearbetas i xmldoc-komponenten
  xmldocument1.Active := true; //Aktivera den
  xslpp.FileName := exepath+xsltfil; //Plocka in xslfilen som ska användas för bearbetningen
  xslpp.Active := true; //Aktivera xsl-komponenten, då körs transformeringen
  temptext := xslpp.Content; //Hämta ut det färdiga resultatet
  xslpp.Active := false; //stäng av xsl-komponenten
  xmldocument1.Active := false; //Stäng av xml-komponenten

  infil.text := UTF8Decode(temptext);
  if infil.text = '' then infil.text := temptext;
  
  infil.Text := stringreplace(infil.text,'encoding="UTF-16"','');
  infil.Text := stringreplace(infil.text,'encoding="utf-16"','');
  infil.Text := stringreplace(infil.text,'encoding="UTF-8"','');
  infil.Text := stringreplace(infil.text,'encoding="utf-8"','');

  //Eftersom XSLT 1.0 inte har någon funktion för att ta fram aktuellt datum och tid så fixar vi det här
  infil.Text := fastreplace(infil.Text,'[#currentDateTime]',copy(idag,1,4)+'-'+copy(idag,5,2)+'-'+copy(idag,7,2)+'T'+copy(klockannu,1,2)+':'+copy(klockannu,3,2)+':'+copy(klockannu,5,2)+'+0'+KollaSommartid+':00');
  infil.Text := fastreplace(infil.Text,'[#tomorrowDateTime]',copy(julian2date(date2julian(idag)+1),1,4)+'-'+copy(julian2date(date2julian(idag)+1),5,2)+'-'+copy(julian2date(date2julian(idag)+1),7,2)+'T'+copy(klockannu,1,2)+':'+copy(klockannu,3,2)+':'+copy(klockannu,5,2)+'+0'+KollaSommartid+':00');
  infil.Text := fastreplace(infil.Text,'xmlns=""',''); //Rensa eventuellt tomma namespaces som xslt lämnat efter sig

  rentfilnamn := stringreplace(filnamn,ExtractFileExt(filnamn),''); //Ta bort ändelsen från filnamnet på filen vi bearbetat

{                   <image id="-a000" refType="Image">
                     <name>[#BILD:a000]</name>
                     <data src="[#BILD:a000]"/>
                  </image>
}

  while pos('[#BILD:',infil.text)  > 0 do begin  //Gå igenom alla ställen där vi lagt variabeln [#BILD:
    enbild := hamtastrengink(infil.text,'[#BILD:',']'); //Hämta själva bildinfon
    nummer := hamtastrengmellan(enbild,'[#BILD:a',']');  //Plocka ut numret
    inummer := strtointdef(nummer,0)+1;   //Omvandla till en integer och lägg på 1
    nummer := rightstr('0'+inttostr(inummer),2); //Skapa ett nytt tresiffrigt nummer
    nybild := rentfilnamn+'-'+nummer+'nh.jpg';  //Skapa ett nytt filnamn för bilden
    infil.text := stringreplace(infil.text,enbild,nybild); //Lägg in det istället för bildinfon vi plockade ut
    if fileexists(datapath+nybild) then begin  //Om vi har bilden tillgänglig
      try
        PjerMoveFile(datapath+nybild,sparpath+nybild,true);  //Flytta bilden till mappen där den ska importeras av NP, men NP bryr sig inte om jpg förrän en npdoc som refererar den kommer dit
      except
        on e: exception do begin
          rapportera('Fel vid bildflytt: '+e.Message,sender);
        end;
      end;
    end;
  end;

  infil.SaveToFile(exepath+'testfil_steg2.xml'); //Spara filen i samma mapp som instansen. OBS - bara för teständamål

  while pos('<image ',infil.text) > 0 do begin //Gå igenom alla image-element efter att de städats enligt ovan
    enimage := hamtastrengink(infil.Text,'<image ','</image>');
    nyimage := stringreplace(enimage,'<image ','<IMAGE '); //Ifall vi ska ha kvar bilden vill vi inte skapa en loop
    enbild := hamtastrengmellan (enimage,'<name>','</name>'); //Hämta ut själva bildnamnet
    if fileexists(sparpath+enbild) then begin //Om bildfilen finns tillgänglig för NP-importen
      infil.text := stringreplace(infil.text,enimage,nyimage); //Då byter vi bara ut så vi inte loopar
    end
    else begin
      infil.text := stringreplace(infil.text,enimage,'');  //Fins inte bilden tar vi bort bildreferensen för annars spricker importen
    end;

  end;

  infil.text := fastreplace(infil.text,'<IMAGE ','<image '); //När vi gått igenom alla image så kan vi återställa till gement på de som är kvar.

  infil.Text := stringreplace(infil.text,'?>',' encoding="UTF-8"?>');
  infil.Text :=  UTF8Encode(infil.text);    //Se till att det är UTF8-encodat

  infil.SaveToFile(sparpath+filnamn+'.npdoc');  //Spara till mappen för att NP ska importera
  infil.SaveToFile(exepath+'testfil_ut.xml'); //Bara för TEST-ändamål

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

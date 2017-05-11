unit synedittext;
{
      Original by Kiriakos Vlahos (kvlahos.@lbs.lon.ac.uk)
}

interface

{$mode objfpc}

uses
  SynEdit;

  procedure AssignSynEdit(var T: Text; NewSynEditComponent: TCustomSynEdit);

implementation

uses
  Forms,
  StrUtils,
  SysUtils;

type

  SynEditData = record
    SynEdit: TCustomSynEdit;
    {$ifdef CPU64}
    Filler: array [1..8] of char;
    {$else}
    Filler: array [1..12] of char;
    {$endif}
  end;
  PSynEditData = ^SynEditData;

  TSynEditHelper = class helper for TCustomSynEdit
    procedure SetSelTextBuf(aBuf: PChar); inline;
  end;

var
  linestore:ansistring;

procedure TSynEditHelper.SetSelTextBuf(aBuf: PChar);
var
  i,j,k:cardinal;
  lineready:boolean;
  subline,line:ansistring;
begin
  lineready:=false;
  subline:=StrPas(aBuf);
  linestore:=linestore+subline;

  i:=1;
  j:=Length(linestore);

  while (i<=j) do
  begin
    case DefaultTextLineBreakStyle of
      tlbsLF:
      begin
        lineready:=(linestore[i]=#10);
      end;
      tlbsCRLF:
      begin
        lineready:=((i>1) AND (linestore[i]=#10) AND (linestore[i-1]=#13));
      end;
      tlbsCR:
      begin
        lineready:=(linestore[i]=#13);
      end;
    end;

    if lineready then
    begin

      line:=Copy(linestore,1,i);
      Delete(linestore,1,i);
      i:=0;
      j:=Length(linestore);

      while true do
      begin
        // to be absolutely sure not to miss errors and fatals !!
        // will be a bit redundant , but just to be sure !
        if (AnsiContainsText(line,'error:')) OR (AnsiContainsText(line,'fatal:')) then
        begin
          lineready:=false;
          break;
        end;
        // remove hints and other trivial warnings from output
        // these line are not that interesting for the average user of fpcupdeluxe !
        if AnsiContainsText(line,'hint: ') then break;
        if AnsiContainsText(line,'verbose: ') then break;
        if AnsiContainsText(line,'warning: ') then
        begin
          if AnsiContainsText(line,'is not portable') then break;
          if AnsiContainsText(line,'is deprecated') then break;
          if AnsiContainsText(line,'implicit string type conversion') then break;
          if AnsiContainsText(line,'function result does not seem to be set') then break;
          if AnsiContainsText(line,'comparison might be always') then break;
          if AnsiContainsText(line,'unreachable code') then break;
          if AnsiContainsText(line,'converting pointers to signed integers') then break;
          if AnsiContainsText(line,'does not seem to be initialized') then break;
          if AnsiContainsText(line,'an inherited method is hidden') then break;
          if AnsiContainsText(line,'with abstract method') then break;
          if AnsiContainsText(line,'comment level 2 found') then break;
        end;
        {$ifdef MSWINDOWS}
        if AnsiContainsText(line,'rm.exe ') then break;
        {$endif}
        {$ifdef UNIX}
        if AnsiContainsText(line,'rm -f ') then break;
        if AnsiContainsText(line,'rm -rf ') then break;
        {$endif}
        lineready:=false;
        break;
      end;

      if (NOT lineready) then
      begin
        Self.InsertTextAtCaret(line,scamBegin);
        Self.CaretX:=0;
        Self.SelStart:=Length(Self.Text);
        //Self.SelStart:=Self.SelStart+i;
      end;
      lineready:=false;
    end;
    Inc(I);
  end;

end;

function EditWrite(var F: TTextRec): Integer; far;
begin
  try
    with F do
    begin
      BufPtr^[BufPos] := #0;
      with TSynEdit(PSynEditData(@F.UserData)^.SynEdit) do
      begin
        Lines.BeginUpdate;
        try
          SetSelTextBuf(PChar(BufPtr));
          //SelStart:=Length(Text);
        finally
          Lines.EndUpdate;
        end;
      end;
    end;
  finally
    F.BufPos := 0;
    EditWrite := 0;
  end;
  Application.ProcessMessages;
end;

function EditFlush(var F: TTextRec): Integer; far;
begin
  F.BufPos := 0;
  F.BufEnd := 0;
  EditFlush := 0;
end;


function EditOpen(var F: TTextRec): Integer; far;
begin
  with F do
  begin
    BufPos:=0;
    BufEnd:=0;
    if Mode <> fmInput then
    begin
      Mode := fmOutput;
      InOutFunc := @EditWrite;
      FlushFunc := @EditWrite;
    end;
    EditOpen := 0;
  end;
end;

function EditIgnore(var F: TTextRec): Integer; far;
begin
  EditIgnore := 0;
end;

procedure AssignSynEdit(var T: Text; NewSynEditComponent: TCustomSynEdit);
begin
  FillChar(T,SizeOf(TextRec),0);
  {$ifdef FPC_HAS_CPSTRING}
  SetTextCodePage(T,TTextRec(T).CodePage);
  {$endif}
  with TTextRec(T) do
  begin
    Handle := UnusedHandle;
    Mode := fmClosed;
    BufSize := SizeOf(Buffer)-1;
    BufPtr := @Buffer;
    OpenFunc := @EditOpen;
    CloseFunc := @EditIgnore;
    case DefaultTextLineBreakStyle of
      tlbsLF: LineEnd := #10;
      tlbsCRLF: LineEnd := #13#10;
      tlbsCR: LineEnd := #13;
    end;
    Name[0] := #0;
    PSynEditData(@UserData)^.SynEdit:= NewSynEditComponent;
  end;
end;

end.




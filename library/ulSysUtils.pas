{
Copyright (C) 2006-2009 Matteo Salvi and Shannara

Website: http://www.salvadorsoftware.com/

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
}

unit ulSysUtils;

{$MODE Delphi}

interface

uses
  AppConfig, Windows, ShellApi, SysUtils, Classes, ulEnumerations, Registry,
  ShlObj, ActiveX, ComObj, Forms, Dialogs, FileUtil;

{ Browse }
function  BrowseCallbackProc(hwnd: HWND; uMsg: UINT; lParam, lpData: LPARAM): Integer; stdcall;
function  BrowseForFolder(const Caption, InitialDir: String): String;

{ Check functions }
function CharInSet(C: WideChar; const CharSet: TSysCharSet): Boolean;
function HasDriveLetter(const Path: String): Boolean;
function IsAbsolutePath(const Path: String): Boolean;
function IsDirectory(const Path: String): Boolean;
function IsDriveRoot(const Path: String): Boolean;
function IsUrl(Path: String): Boolean;
function FileFolderPageWebExists(Path: String): Boolean;

{ Files }
procedure DeleteFiles(PathDir, FileName: String);
procedure DeleteOldBackups(MaxNumber: Integer);

{ Desktop shortcut }
procedure CreateShortcutOnDesktop(FileName: String;TargetFilePath, Params, WorkingDir: String);
procedure DeleteShortcutOnDesktop(FileName: String);
function  GetShortcutTarget(LinkFileName:String;ShortcutType: TShortcutField):String;

{ Relative & Absolute path }
function AbsoluteToRelative(APath: String): string;
function RelativeToAbsolute(APath: String): string;

{ Registry }
procedure SetASuiteAtWindowsStartup;
procedure DeleteASuiteAtWindowsStartup;

{ Misc }
function ExtractDirectoryName(const Filename: string): string;
function GetExeVersion(FileName: String): String;
function GetCorrectWorkingDir(Default: string): string;
procedure ShowSysFilePropertiesDlg(const FileName: WideString);

implementation

uses
  ulStringUtils;

function BrowseCallbackProc(hwnd: HWND; uMsg: UINT; lParam, lpData: LPARAM): Integer; stdcall;
begin
  //Set initial directory
  if uMsg = BFFM_INITIALIZED then
    SendMessage(hwnd, BFFM_SETSELECTION, 1, lpData);
  Result := 0;
end;

function BrowseForFolder(const Caption, InitialDir: String): String;
var
  BrowseInfo: TBrowseInfo;
  Buffer: PChar;
  ItemIDList: PItemIDList;
  ShellMalloc: IMalloc;
  Windows: Pointer;
  Path: string;
  SelectDirectoryDialog: TSelectDirectoryDialog;
begin
  Result := '';
  Path  := InitialDir;
  //Delete \ in last char. Example c:\xyz\ to c:\xyz
  if (Length(Path) > 0) and (Path[Length(Path)] = PathDelim) then
    Delete(Path, Length(Path), 1);

{ TODO : Check this code  *Lazarus Porting* }
  SelectDirectoryDialog := TSelectDirectoryDialog.Create(nil);
  try
    SelectDirectoryDialog.InitialDir := Path;
    SelectDirectoryDialog.Execute;
  finally
    Result := SelectDirectoryDialog.FileName;
  end;
end;

function CharInSet(C: WideChar; const CharSet: TSysCharSet): Boolean;
begin
  Result := C in CharSet;
end;

function HasDriveLetter(const Path: String): Boolean;
var P: PChar;
begin
  if Length(Path) < 2 then
    Exit(False);
  P := Pointer(Path);
  if not CharInSet(P^, DriveLetters) then
    Exit(False);
  Inc(P);
  if not CharInSet(P^, [':']) then
    Exit(False);
  Result := True;
end;

function IsAbsolutePath(const Path: String): Boolean;
begin
  if Path = '' then
    Result := False
  else if HasDriveLetter(Path) then
    Result := True
  else if CharInSet(PChar(Pointer(Path))^, ['\', '/']) then
    Result := True else
  Result := False;
end;

function IsDirectory(const Path: String): Boolean;
var
  L: Integer;
  P: PChar;
begin
  L := Length(Path);
  if L = 0 then
    Result := False
  else if (L = 2) and HasDriveLetter(Path) then
    Result := True
  else
    begin
      P := Pointer(Path);
      Inc(P, L - 1);
      Result := CharInSet(P^, SLASHES);
    end;
end;

function IsDriveRoot(const Path: String): Boolean;
begin
  Result := (Length(Path) = 3) and HasDriveLetter(Path) and (Path[3] = PathDelim);
end;

function IsUrl(Path: String): Boolean;
begin
  if (pos('http://',Path) = 1) or (pos('https://',Path) = 1) or
     (pos('ftp://',Path) = 1) or (pos('www.',Path) = 1) or
     (pos('%',Path) = 1) then
    Result := True
  else
    Result := False;
end;

function FileFolderPageWebExists(Path: String): Boolean;
begin
  if ((FileExistsUTF8(Path)) or (DirectoryExistsUTF8(Path)) or
      IsUrl(Path)) then
    Result := true
  else
    Result := false;
end;

procedure DeleteFiles(PathDir, FileName: String);
var
  Search : TSearchRec;
begin
  //Delete file with FileName in folder PathDir (path relative)
  if FindFirstUTF8(SUITE_WORKING_PATH + PathDir + FileName,faAnyFile,Search) = 0 then
  begin
    repeat
      DeleteFileUTF8(PathDir + Search.Name); 
    until
      FindNextUTF8(Search) <> 0;
    FindCloseUTF8(Search); 
  end;
end;

procedure DeleteOldBackups(MaxNumber: Integer);
var
  BackupList   : TStringList;
  BackupSearch : TSearchRec;
  I            : Integer;
begin
  BackupList := TStringList.Create;
  if FindFirstUTF8(SUITE_BACKUP_PATH + 'ASuite_*' + EXT_SQLBCK,faAnyFile,BackupSearch) = 0 then
  begin
    repeat
      BackupList.Add(BackupSearch.Name);
    until
      FindNextUTF8(BackupSearch) <> 0;
    FindCloseUTF8(BackupSearch); 
  end;
  BackupList.Sort;
  for I := 1 to BackupList.Count - MaxNumber do
    DeleteFileUTF8(SUITE_BACKUP_PATH + BackupList[I - 1]);
  BackupList.Free;
end;

procedure CreateShortcutOnDesktop(FileName: String;TargetFilePath, Params, WorkingDir: String);
var
  IObject  : IUnknown;
  ISLink   : IShellLink;
  IPFile   : IPersistFile;
  PIDL     : PItemIDList;
  InFolder : array[0..MAX_PATH] of Char;
  LinkName : WideString;
begin
  //Relative path to Absolute path
  if pos(':',TargetFilePath) = 0 then
    TargetFilePath := SUITE_WORKING_PATH + TargetFilePath;
  //Create objects
  IObject := CreateComObject(CLSID_ShellLink);
  ISLink  := IObject as IShellLink;
  IPFile  := IObject as IPersistFile;
  //Create link
  ISLink.SetPath(pChar(TargetFilePath));
  ISLink.SetArguments(pChar(Params));
  if WorkingDir = '' then
    ISLink.SetWorkingDirectory(pChar(ExtractFilePath(TargetFilePath)))
  else
    ISLink.SetWorkingDirectory(pChar(RelativeToAbsolute(WorkingDir)));
  //DesktopPath
  SHGetSpecialFolderLocation(0, CSIDL_DESKTOPDIRECTORY, PIDL);
  SHGetPathFromIDList(PIDL, InFolder);
  //Save link
  LinkName := InFolder + PathDelim + FileName;
  IPFile.Save(PWChar(LinkName), false);
end;

procedure DeleteShortcutOnDesktop(FileName: String);
var
  PIDL        : PItemIDList;
  DesktopPath : array[0..MAX_PATH] of Char;
  LinkName    : String;
begin
  SHGetSpecialFolderLocation(0, CSIDL_DESKTOPDIRECTORY, PIDL);
  SHGetPathFromIDList(PIDL, DesktopPath);
  LinkName := DesktopPath + PathDelim + FileName;
  if (FileExistsUTF8(LinkName)) then
    DeleteFileUTF8(LinkName);
end;

function GetShortcutTarget(LinkFileName:String;ShortcutType: TShortcutField):String;
var
  ISLink    : IShellLink;
  IPFile    : IPersistFile;
  WidePath  : PWideChar;
  Info      : Array[0..MAX_PATH] of Char;
  wfs       : TWin32FindData;

{ TODO : Workaround: function StringToWideChar (FPC 2.6.x) is bugged.
         In FPC 2.7.1 (actually work in progress), this function is fixed,
         so I copied it here }
function StringToWideChar(Src : AnsiString;Dest : PWideChar;DestSize : SizeInt) : PWideChar;
  var
    temp:widestring;
    Len: SizeInt;
  begin
      widestringmanager.Ansi2WideMoveProc(PChar(Src),temp,Length(Src));
      Len := Length(temp);
      if DestSize<=Len then
        Len := Destsize-1;
      move(temp[1],Dest^,Len*SizeOf(WideChar));
      Dest[Len] := #0;
      result := Dest;
  end;

begin

   if UpperCase(ExtractFileExt(LinkFileName)) <> '.LNK' Then
   begin
     Result := LinkFileName;
     Exit;
   end;
   CoCreateInstance(CLSID_ShellLink,nil,CLSCTX_INPROC_SERVER,IShellLink,ISLink);
   if ISLink.QueryInterface(IPersistFile, IPFile) = 0 then
   begin
     //Initialize WidePath, if not conversion doesn't work
     WidePath := 'emptypath';
     //AnsiString -> WideChar
     StringToWideChar(LinkFileName,WidePath,MAX_PATH);
     //Get pathexe, parameters or working directory from shortcut
     IPFile.Load(WidePath, STGM_READ);
     case ShortcutType of
       sfPathExe    : ISLink.GetPath(@info,MAX_PATH,wfs,SLGP_UNCPRIORITY);
       sfParameter  : ISLink.GetArguments(@info,MAX_PATH);
       sfWorkingDir : ISLink.GetWorkingDirectory(@info,MAX_PATH);
     end;
     Result := info
   end
   else
     Result := LinkFileName;
end;

function AbsoluteToRelative(APath: String): string;
begin
  APath := LowerCase(APath);
  if (pos(ExcludeTrailingBackslash(SUITE_WORKING_PATH),APath) <> 0) then
    APath := StringReplace(APath, ExcludeTrailingBackslash(SUITE_WORKING_PATH), CONST_PATH_ASUITE, [rfReplaceAll])
  else
    if pos(SUITE_DRIVE,APath) <> 0 then
      APath := StringReplace(APath, SUITE_DRIVE, CONST_PATH_DRIVE, [rfReplaceAll]);
  Result := APath;
end;

function RelativeToAbsolute(APath: String): string;
var
  EnvVar: String;
begin
  APath := LowerCase(APath);
  //CONST_PATH_ASuite = Launcher's path
  APath := StringReplace(APath, CONST_PATH_ASUITE, SUITE_WORKING_PATH, [rfReplaceAll]);
  //CONST_PATH_DRIVE = Launcher's Drive (ex. ASuite in H:\Software\asuite.exe, CONST_PATH_DRIVE is H: )
  APath := StringReplace(APath, CONST_PATH_DRIVE, SUITE_DRIVE, [rfReplaceAll]);
  //Remove double slash (\)
  APath := StringReplace(APath, '\\', PathDelim, [rfReplaceAll]);
  //Replace environment variable
  if (pos('%',APath) <> 0) then
  begin
    EnvVar := APath;
    Delete(EnvVar,1,pos('%',EnvVar));
    EnvVar := Copy(EnvVar,1,pos('%',EnvVar) - 1);
    APath := StringReplace(APath, '%' + EnvVar + '%', GetEnvironmentVariable(EnvVar), [rfReplaceAll]);
  end;
  //If APath exists, expand it in absolute path (to avoid the "..")
  if (FileExistsUTF8(APath) or DirectoryExistsUTF8(APath)) and (Length(APath) <> 2) then
    Result := ExpandFileNameUTF8(APath)
  else
    Result := APath;
end;

function ExtractDirectoryName(const Filename: string): string;
var
  AList : TStringList;
begin
	AList := TStringList.create;
	try
    StrToStrings(Filename,PathDelim,AList);
		if AList.Count > 1 then
			result := AList[AList.Count - 1]
		else
			result := '';
	finally
		AList.Free;
	end;
end;

function GetExeVersion(FileName: String): String;
var
  VerInfoSize: DWORD;
  VerInfo: Pointer;
  VerValueSize: DWORD;
  VerValue: PVSFixedFileInfo;
  Dummy: DWORD;
begin
  VerInfoSize := GetFileVersionInfoSize(PChar(ParamStr(0)), Dummy);
  if VerInfoSize = 0 then Exit('');
  GetMem(VerInfo, VerInfoSize);
  GetFileVersionInfo(PChar(FileName), 0, VerInfoSize, VerInfo);
  VerQueryValue(VerInfo, PathDelim, Pointer(VerValue), VerValueSize);
  with VerValue^ do
  begin
    Result := IntToStr(dwFileVersionMS shr 16);
    Result := Result + '.' + IntToStr(dwFileVersionMS and $FFFF);
    Result := Result + '.' + IntToStr(dwFileVersionLS shr 16);
    Result := Result + '.' + IntToStr(dwFileVersionLS and $FFFF);
  end;
  FreeMem(VerInfo, VerInfoSize);
end;

procedure SetASuiteAtWindowsStartup;
var
  Registry : TRegistry;
begin
  Registry := TRegistry.Create;
  try
    with Registry do
    begin
      RootKey := HKEY_LOCAL_MACHINE;
      if OpenKey('SOFTWARE\Microsoft\Windows\CurrentVersion\Run',False) then
        if Not(ValueExists(APP_NAME)) then
          WriteString(APP_NAME,(Application.ExeName));
    end
  finally
    Registry.Free;
  end;
end;

procedure DeleteASuiteAtWindowsStartup;
var
  Registry : TRegistry;
begin
  Registry := TRegistry.Create;
  try
    with Registry do
    begin
      RootKey := HKEY_LOCAL_MACHINE;
      if OpenKey('SOFTWARE\Microsoft\Windows\CurrentVersion\Run',False) then
        DeleteValue(APP_NAME)
    end
  finally
    Registry.Free;
  end;
end;

function GetCorrectWorkingDir(Default: string): string;
var
  sPath: String;
begin
  Result := Default;
  sPath := IncludeTrailingBackslash(SUITE_PATH + sPath);
  if DirectoryExistsUTF8(sPath) then
    Result := sPath;
end;
procedure ShowSysFilePropertiesDlg(const FileName: WideString);
var
  sei: TShellExecuteinfoW;
begin
  { TODO : Check Code *Lazarus Porting* }
  FillChar(sei,sizeof(sei),0);
  sei.cbSize := sizeof(sei);
  sei.lpFile := PWideChar(FileName);
  sei.lpVerb := 'properties';
  sei.fMask  := SEE_MASK_INVOKEIDLIST;
  ShellExecuteExW(@sei);
// Send "Tab" to switch from dialog's pages
//  keybd_event( VK_CONTROL, Mapvirtualkey( VK_CONTROL, 0 ), 0, 0);
//  keybd_event( VK_TAB, Mapvirtualkey( VK_TAB, 0 ), 0, 0);
//  keybd_event( VK_TAB, Mapvirtualkey( VK_TAB, 0 ), KEYEVENTF_KEYUP, 0);
//  keybd_event( VK_CONTROL, Mapvirtualkey( VK_CONTROL, 0 ), KEYEVENTF_KEYUP, 0);
end;


end.
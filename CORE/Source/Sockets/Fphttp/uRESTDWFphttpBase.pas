unit uRESTDWFphttpBase;

{$I ..\..\Includes\uRESTDW.inc}

{
  REST Dataware .
  Criado por XyberX (Gilbero Rocha da Silva), o REST Dataware tem como objetivo o uso de REST/JSON
  de maneira simples, em qualquer Compilador Pascal (Delphi, Lazarus e outros...).
  O REST Dataware tamb�m tem por objetivo levar componentes compat�veis entre o Delphi e outros Compiladores
  Pascal e com compatibilidade entre sistemas operacionais.
  Desenvolvido para ser usado de Maneira RAD, o REST Dataware tem como objetivo principal voc� usu�rio que precisa
  de produtividade e flexibilidade para produ��o de Servi�os REST/JSON, simplificando o processo para voc� programador.

  Membros do Grupo :

  XyberX (Gilberto Rocha)    - Admin - Criador e Administrador  do pacote.
  A. Brito                   - Admin - Administrador do desenvolvimento.
  Alexandre Abbade           - Admin - Administrador do desenvolvimento de DEMOS, coordenador do Grupo.
  Fl�vio Motta               - Member Tester and DEMO Developer.
  Mobius One                 - Devel, Tester and Admin.
  Gustavo                    - Criptografia and Devel.
  Eloy                       - Devel.
  Roniery                    - Devel.
}


interface

Uses
  SysUtils,  Classes,  DateUtils, SyncObjs, ExtCtrls, sslbase,
  uRESTDWComponentEvents, uRESTDWBasicTypes, uRESTDWJSONObject, uRESTDWBasic,
  uRESTDWBasicDB, uRESTDWParams, uRESTDWBasicClass, uRESTDWAbout,
  uRESTDWConsts, uRESTDWDataUtils, uRESTDWTools, uRESTDWAuthenticators,
  fphttpserver, HTTPDefs, fpwebclient, base64, httpprotocol;

Type
  TRESTDWFphttpServicePooler = class;

  { TRESTDWFpHttpThread }

  TRESTDWFpHttpThread = class(TThread)
  private
    FParent : TRESTDWFphttpServicePooler;
    FMustDie : Boolean;
    FServer : TFPHTTPServer;
    FStartServer : Boolean;
    FEvent : TSimpleEvent;
  protected
    procedure Execute; override;

    Procedure ExecRequest(Sender: TObject;
                          Var ARequest: TFPHTTPConnectionRequest;
                          Var AResponse : TFPHTTPConnectionResponse);

    function getActive: boolean;
    function getCertificateData: TCertificateData;
    function getPort: word;
    function getUseSSL: boolean;
    procedure setActive(AValue: boolean);
    procedure setPort(AValue: word);
    procedure setUseSSL(AValue: boolean);
  public
    constructor Create(AOwner: TRESTDWFphttpServicePooler);
    destructor Destroy; override;

    procedure Start;
    procedure Stop;
  published
    property UseSSL : boolean read getUseSSL write setUseSSL;
    property Active : boolean read getActive write setActive;
    property Port : word read getPort write setPort;
    property CertificateData : TCertificateData read getCertificateData;
  end;

  { TRESTDWFphttpServicePooler }

  TRESTDWFphttpServicePooler = Class(TRESTServicePoolerBase)
  Private
    FFpServer : TRESTDWFpHttpThread;

    // SSL Params
    vSSLRootCertFile, vSSLPrivateKeyFile, vSSLPrivateKeyPassword, vSSLCertFile: String;
    vSSLVerMethodMin, vSSLVerMethodMax: TSSLVersion;
    vSSLVerifyDepth: Integer;
    vSSLVerifyPeer: boolean;
    vSSLTimeoutSec: Cardinal;

    // HTTP Params
    vMaxClients: Integer;
    vServiceTimeout: Integer;
    vBuffSizeBytes: Integer;
    vBandWidthLimitBytes: Cardinal;
    vBandWidthSampleSec: Cardinal;
    vListenBacklog: Integer;

    Procedure ExecRequest(Var ARequest: TFPHTTPConnectionRequest;
                          Var AResponse : TFPHTTPConnectionResponse);
  protected
    function getUseSSL: boolean;
    procedure setUseSSL(AValue: boolean);
  Public
    Constructor Create(AOwner: TComponent); Override;
    Destructor Destroy; override;

    Procedure SetActive(Value: boolean); Override;

    Procedure EchoPooler(ServerMethodsClass: TComponent; AContext: TComponent;
      Var Pooler, MyIP: String; AccessTag: String; Var InvalidTag: boolean); Override;
  Published
    // SSL Params
    Property SSLRootCertFile: String Read vSSLRootCertFile Write vSSLRootCertFile;
    Property SSLPrivateKeyFile: String Read vSSLPrivateKeyFile Write vSSLPrivateKeyFile;
    Property SSLPrivateKeyPassword: String Read vSSLPrivateKeyPassword Write vSSLPrivateKeyPassword;
    Property SSLCertFile: String Read vSSLCertFile Write vSSLCertFile;
    Property SSLVerifyDepth: Integer Read vSSLVerifyDepth Write vSSLVerifyDepth default 9;
    Property SSLVerifyPeer: boolean Read vSSLVerifyPeer Write vSSLVerifyPeer default false;
    Property SSLVersionMin: TSSLVersion Read vSSLVerMethodMin Write vSSLVerMethodMin default svTLSv12;
    // SSL TimeOut in Seconds
    property UseSSL : boolean Read getUseSSL Write setUseSSL;
  End;


Implementation

Uses uRESTDWJSONInterface, Dialogs;

{ TRESTDWFpHttpThread }

function TRESTDWFpHttpThread.getUseSSL: boolean;
begin
  Result := FServer.UseSSL;
end;

function TRESTDWFpHttpThread.getActive: boolean;
begin
  Result := FServer.Active;
end;

function TRESTDWFpHttpThread.getCertificateData: TCertificateData;
begin
  Result := FServer.CertificateData;
end;

function TRESTDWFpHttpThread.getPort: word;
begin
  Result := FServer.Port;
end;

procedure TRESTDWFpHttpThread.setActive(AValue: boolean);
begin
  FServer.Active := AValue;
end;

procedure TRESTDWFpHttpThread.setPort(AValue: word);
begin
  FServer.Port := AValue;
end;

procedure TRESTDWFpHttpThread.setUseSSL(AValue: boolean);
begin
  FServer.UseSSL := AValue;
end;

procedure TRESTDWFpHttpThread.Execute;
begin
  while not Terminated do
  begin
    FEvent.WaitFor(INFINITE);

    if FMustDie then begin
      Terminate;
      Break;
    end;

    if (FStartServer) and (not FServer.Active) then
      FServer.Active := FStartServer;
  end;
end;

procedure TRESTDWFpHttpThread.ExecRequest(Sender: TObject;
  var ARequest: TFPHTTPConnectionRequest;
  var AResponse: TFPHTTPConnectionResponse);
begin
  FParent.ExecRequest(ARequest,AResponse);
end;

constructor TRESTDWFpHttpThread.Create(AOwner: TRESTDWFphttpServicePooler);
begin
  FParent := AOwner;

  FreeOnTerminate := False;
  FMustDie := False;
  FEvent := TSimpleEvent.Create;
  FEvent.ResetEvent;

  FServer := TFPHttpServer.Create(nil);
  FServer.OnRequest := @ExecRequest;
  FServer.QueueSize := 15;
  FServer.Threaded := False;

  inherited Create(False);
end;

destructor TRESTDWFpHttpThread.Destroy;
begin
  FMustDie := True;
  FEvent.SetEvent;

  FEvent.Free;

  FServer.Active := False;
  FServer.Free;
end;

procedure TRESTDWFpHttpThread.Start;
begin
  FStartServer := True;
  FEvent.SetEvent;
end;

procedure TRESTDWFpHttpThread.Stop;
begin
  FStartServer := False;
  FServer.Active := FStartServer;
  FEvent.ResetEvent;
end;

{TRESTDWFphttpServicePooler}

procedure TRESTDWFphttpServicePooler.ExecRequest(
  var ARequest: TFPHTTPConnectionRequest;
  var AResponse: TFPHTTPConnectionResponse);
var
  vContentType,
  vAuthRealm,
  sCharSet,
  ErrorMessage,
  vResponseString     : String;
  StatusCode,
  I                   : Integer;
  vResponseHeader,
  HeaderList,
  CORSCustomHeaders   : TStringList;
  ResultStream,
  ContentStringStream : TStream;
  mb                  : TStringStream;
  vRedirect           : TRedirect;

  aUserName,
  aPassword : String;

  procedure ParseHeader;
  var
    I: Integer;
    s: string;
    sl: TStringList;

    begin
    sl := nil;

    HeaderList.NameValueSeparator:= ':';
    for I := 0 to Pred(ARequest.FieldCount) do
      HeaderList.AddPair(ARequest.FieldNames[I], ARequest.FieldValues[I]  );

    for I := 0 to Pred(ARequest.CustomHeaders.Count) do
      HeaderList.AddPair(ARequest.CustomHeaders.Names[I], ARequest.CustomHeaders.ValueFromIndex[I]  );

    s :=  ARequest.GetHTTPVariable(hvQuery);
    sl := TStringList.Create;
    try
      if (Pos('?', s) > 0)then
      begin
        s := StringReplace(s, '?', '', [rfReplaceAll]);
        s := StringReplace(s, '/', '', []);
        sl.Delimiter := '&';
        sl.StrictDelimiter := True;
        sl.DelimitedText := s;
        for i := 0 to sl.Count - 1 do
        begin
          s := sl[i];
          if Pos('=', s) > 0 then
            HeaderList.AddPair(Copy(s, 1, Pos('=', s) - 1) , Copy(s, Pos('=', s) + 1, Length(s) - Pos('=', s)));
        end;
    end;
    finally
      FreeAndNil(sl);
    end;
  end;

  procedure SetReplyCORS;
  var
    i: Integer;
   begin
     if ARequest.CustomHeaders.Count > 0 then
     begin
      for i := 0 To ARequest.CustomHeaders.Count - 1 Do
        vResponseHeader.AddPair(ARequest.CustomHeaders.Names[i],
          ARequest.CustomHeaders.ValueFromIndex[i]);
     end
     else
       vResponseHeader.AddPair('Access-Control-Allow-Origin', '*');

     if Assigned(CORSCustomHeaders) then
     begin
       if CORSCustomHeaders.Count > 0 Then
         begin
           for i := 0 To CORSCustomHeaders.Count - 1 Do
             vResponseHeader.AddPair(CORSCustomHeaders.Names[i], CORSCustomHeaders.ValueFromIndex[i]);
         end;
     end;
   end;

  Procedure DestroyComponents;
  Begin
   { if assigned(vResponseHeader)then
      FreeAndNil(vResponseHeader); }
    vResponseHeader.Free;
   { if assigned(ResultStream)then
      FreeAndNil(ResultStream); }
      ResultStream.Free;

   { if assigned(CORSCustomHeaders)then
      FreeAndNil(CORSCustomHeaders);}
      CORSCustomHeaders.Free;

   { if assigned(ContentStringStream)then
      FreeAndNil(ContentStringStream);}
      ContentStringStream.Free;

  {  if assigned(HeaderList)then
      FreeAndNil(HeaderList); }
      HeaderList.Free;

  End;

  procedure Redirect(Url: String);
  begin
    AResponse.SendRedirect(Url);
  end;

  Procedure WriteError;
  Begin
    mb                               := TStringStream.Create(ErrorMessage);
    try
      AResponse.Code                   := StatusCode;
      mb.Position                      := 0;
      AResponse.FreeContentStream      := True;
      AResponse.ContentStream          := mb;
      AResponse.ContentStream.Position := 0;
      AResponse.ContentLength          := -1;//mb.Size;
      AResponse.SendContent;
    finally
      if assigned(mb)then
        FreeAndNil(mb);
    end;
  End;

begin
  aUserName:= EmptyStr;
  aPassword:= EmptyStr;
  HeaderList := nil;
  vResponseHeader     := nil;
  ResultStream        := nil;
  CORSCustomHeaders   := nil;
  ContentStringStream := nil;

  HeaderList := TStringList.Create;

  ParseHeader;

  vRedirect       := TRedirect(@Redirect);
  vContentType    := ARequest.ContentType;
  vAuthRealm      := AResponse.WWWAuthenticate;
  sCharSet        := aRequest.AcceptCharset;
  ErrorMessage    := '';
  vResponseString := '';
  StatusCode      := 200;

  vResponseHeader     := TStringList.Create;
  ResultStream        := TStream.Create;
  CORSCustomHeaders   := TStringList.Create;
  ContentStringStream := TStringStream.Create;
  try
    if CommandExec(TComponent(aRequest)                                           , //AContext
                   RemoveBackslashCommands(ARequest.GetHTTPVariable(hvPathInfo) ) , //Url
                   ARequest.GetHTTPVariable(hvMethod) + ' ' +
                   ARequest.GetHTTPVariable(hvURL) + ' HTTP/' +
                   ARequest.GetHTTPVariable(hvHTTPVersion)                        , //RawHTTPCommand
                   vContentType                                                   , //ContentType
                   ARequest.GetHTTPVariable(hvRemoteAddress)                      , //ClientIP
                   aRequest.GetFieldByName('User-Agent')                          , //UserAgent
                   aUserName                                                      , //AuthUsername
                   aPassword                                                      , //AuthPassword
                   ''                                                             , //Token
                   aRequest.CustomHeaders                                         , //RequestHeaders
                   StrToInt( aRequest.GetHTTPVariable(hvServerPort) )             , //ClientPort
                   HeaderList                                                     , //RawHeaders
                   aRequest.CustomHeaders                                         , //Params
                   aRequest.GetHTTPVariable(hvQuery)                              , //QueryParams
                   ContentStringStream                                            , //ContentStringStream
                   vAuthRealm                                                     , //AuthRealm
                   sCharSet                                                       , //sCharSet
                   ErrorMessage                                                   , //ErrorMessage
                   StatusCode                                                     , //StatusCode
                   vResponseHeader                                                , //ResponseHeaders
                   vResponseString                                                , //ResponseString
                   ResultStream                                                   , //ResultStream
                   TStrings(CORSCustomHeaders)                                    , //CORSCustomHeaders
                   vRedirect                                                        //Redirect
                   ) then
      begin
        SetReplyCORS;

        if (vAuthRealm <> '') then
          AResponse.SetHeader(hhWWWAuthenticate, 'Basic realm="API"');  // Aqui estava o vAuthRealm, mas no caso do FPHTTP precisa ser diferente do Indy

        AResponse.ContentType    := vContentType;

        If Encoding = esUtf8 Then
          AResponse.AcceptCharset := 'utf-8'
        else
          AResponse.AcceptCharset := 'ansi';

        AResponse.Code            := StatusCode;



        if (vResponseString <> '') Or (ErrorMessage    <> '')   Then
        begin
          if Assigned(ResultStream)  then
            FreeAndNil(ResultStream);

          if (vResponseString <> '') then
            ResultStream  := TStringStream.Create(vResponseString)
          else
            ResultStream  := TStringStream.Create(ErrorMessage);
        end;


        for I := 0 To vResponseHeader.Count -1 Do
          AResponse.CustomHeaders.AddPair(vResponseHeader.Names [I], vResponseHeader.Values[vResponseHeader.Names[I]]);

        if vResponseHeader.Count > 0 then
          AResponse.SendHeaders;
          //AResponse.WriteContent;

        if Assigned(ResultStream)    then
        begin
          AResponse.ContentStream := ResultStream;
          AResponse.SendContent;  //SendContent � necess�rio para devolver o conte�do
          AResponse.ContentStream := Nil;
          AResponse.ContentLength := ResultStream.Size;
        end;
      end
      else
      begin
        SetReplyCORS;

        if (vAuthRealm <> '') then
          AResponse.SetHeader(hhWWWAuthenticate, 'Basic realm="API"');

        AResponse.Code            := StatusCode;

        if Assigned(ResultStream)    then
        begin
          AResponse.ContentStream          := ResultStream;
          AResponse.SendContent;  //SendContent � necess�rio para devolver o conte�do
          AResponse.ContentStream := Nil;
          AResponse.ContentLength := ResultStream.Size;
        end;
      end;
  finally
    DestroyComponents;
  end;
end;

function TRESTDWFphttpServicePooler.getUseSSL: boolean;
begin
  Result := FFpServer.UseSSL;
end;

procedure TRESTDWFphttpServicePooler.setUseSSL(AValue: boolean);
begin
  FFpServer.UseSSL := AValue;
end;

constructor TRESTDWFphttpServicePooler.Create(AOwner: TComponent);
begin
  Inherited Create(AOwner);
  FFpServer := TRESTDWFpHttpThread.Create(Self);
  FSocketKind := 'fpHttp';
end;


destructor TRESTDWFphttpServicePooler.Destroy;
Begin
  FFpServer.Stop;
  FFpServer.Free;
  Inherited Destroy;
End;

procedure TRESTDWFphttpServicePooler.EchoPooler(ServerMethodsClass: TComponent;
  AContext: TComponent; var Pooler, MyIP: String; AccessTag: String;
  var InvalidTag: boolean);
Var
  Remote: THTTPHeader;
  i: Integer;
Begin
  InvalidTag := false;
  MyIP := '';

  If ServerMethodsClass <> Nil Then
  Begin
    For i := 0 To ServerMethodsClass.ComponentCount - 1 Do
    Begin
      If (ServerMethodsClass.Components[i].ClassType = TRESTDWPoolerDB) Or
         (ServerMethodsClass.Components[i].InheritsFrom(TRESTDWPoolerDB)) Then
      Begin
        If Pooler = Format('%s.%s', [ServerMethodsClass.ClassName, ServerMethodsClass.Components[i].Name]) Then
        Begin
          If Trim(TRESTDWPoolerDB(ServerMethodsClass.Components[i]).AccessTag) <> '' Then
          Begin
            If TRESTDWPoolerDB(ServerMethodsClass.Components[i]).AccessTag <>
              AccessTag Then
            Begin
              InvalidTag := true;
              exit;
            End;
          End;
          If AContext <> Nil Then
          Begin
            Remote := THTTPHeader(AContext);
            MyIP := Remote.RemoteAddress;
          End;
          Break;
        End;
      End;
    End;
  End;
  If MyIP = '' Then
    Raise Exception.Create(cInvalidPoolerName);
End;

procedure TRESTDWFphttpServicePooler.SetActive(Value: boolean);
Begin
  If (Value) Then
  Begin
    Try
      if not(Assigned(ServerMethodClass)) and (Self.GetDataRouteCount = 0) then
        raise Exception.Create(cServerMethodClassNotAssigned);

       FFpServer.Port := ServicePort;

       if UseSSL and (SSLRootCertFile <> EmptyStr) then begin
         FFpServer.CertificateData.KeyPassword          := SSLPrivateKeyPassword;//fCertificatePassword;
         FFpServer.CertificateData.HostName             := SSLRootCertFile;//fCertificateHostName;
         FFpServer.CertificateData.Certificate.FileName := SSLCertFile;//fCertificateFileName;
         FFpServer.CertificateData.PrivateKey.FileName  := SSLPrivateKeyFile;//fCertificatePrivateKey;
       end;

       FFpServer.Start;
    Except
      On E: Exception do
      Begin
        Raise Exception.Create(E.Message);
      End;
    End;
  End
  Else
   If Not(Value) Then
   Begin
    Try
      FFpServer.Stop;
    Except
    End;
  End;
  Inherited SetActive(Value);
End;

End.

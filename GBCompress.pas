unit GBCompress;

interface

uses MainLib, SysUtils;

type
  EGBCompress = class(Exception);

function GBCompressBuf( inBuf : PByteMem;  InSize  : integer;
                        outBuf : PByteMem; MaxSize : integer ): integer;

implementation

const
  EOFMarker : byte = 0;

var
  FInBuf         : PByteMem;
  FInSize        : integer;
  FOutBuf        : PByteMem;
  FOutIndex      : integer;
  FMaxSize       : integer;


procedure write_end;
begin
  if ((FOutIndex+1) >= FMaxSize) then raise EGBCompress.Create('OutBuf too small');

  FOutBuf[FOutIndex] := EOFMarker;
  Inc(FOutIndex);
end;


procedure write_byte( len : byte; data : byte );
begin
  if ((FOutIndex+2) >= FMaxSize) then raise EGBCompress.Create('OutBuf too small');

  len := ((len-1) and 63);
  FOutBuf[FOutIndex]   := len;
  FOutBuf[FOutIndex+1] := data;
  Inc(FOutIndex,2);
end;


procedure write_word( len : byte; data : SmallInt );
begin
  if ((FOutIndex+3) >= FMaxSize) then raise EGBCompress.Create('OutBuf too small');

  len := (((len-1) and 63) or 64);
  FOutBuf[FOutIndex]   := len;
  FOutBuf[FOutIndex+1] := byte(data shr 8);
  FOutBuf[FOutIndex+2] := byte(data);
  Inc(FOutIndex, 3);
end;


procedure write_string( len : byte; data : Cardinal );
var i : integer;
begin
  if ((FOutIndex+3) >= FMaxSize) then raise EGBCompress.Create('OutBuf too small');

  i := (((len-1) and 63) or 128);
  FOutBuf[FOutIndex]   := i;
  FOutBuf[FOutIndex+1] := byte(data);
  FOutBuf[FOutIndex+2] := byte(data shr 8);
  Inc(FOutIndex, 3);
end;


procedure write_trash( len : byte; pos : PByteMem );
var c : byte;
    i : integer;
begin
  if ((FOutIndex + len) >= FMaxSize) then raise EGBCompress.Create('OutBuf too small');
  c := (((len-1) and 63) or 192);
  FOutBuf[FOutIndex]   := c;
  Inc(FoutIndex);

  for i := 0 to len-1 do
  begin
    FOutBuf[FOutIndex] := pos[i];
    Inc(FOutIndex);
  end;
end;




function GBCompressBuf( inBuf : PByteMem;  InSize  : integer;
                        outBuf : PByteMem; MaxSize : integer ): integer;
var bp, tb          : integer;
    x               : byte;
    y               : Cardinal;
    rr,sr,rl        : Integer;
    r_rb,r_rw,r_rs  : integer;

begin

  FInBuf := InBuf;
  FOutBuf := OutBuf;
  FInSize := InSize;
  FMaxSize := MaxSize;

  bp := 0;
  tb := 0;
  FOutIndex := 0;


  while (bp < FInSize) do
  begin

    x := FInBuf[bp];
    r_rb := 1;
    while (FInBuf[bp+r_rb] = x) and ((bp + r_rb) < FInSize) and (r_rb < 64) do Inc(r_rb);

    y := Cardinal((FInBuf[bp] shl 8) + FInBuf[bp+1]);
    r_rw := 1;
    while ( Cardinal((FInbuf[bp + (r_rw*2)] shl 8) + FInBuf[bp + 1 + (r_rw*2)]) = y) and
          ((bp + (r_rw*2)) < FInSize) and (r_rw < 64) do Inc(r_rw);


    rr := 0;
    sr := 0;
    r_rs := 0;
    while (rr < bp) do
    begin
      rl := 0;
      while ((bp+rl) < FInsize) and (FInBuf[rr+rl] = FInbuf[bp+rl]) and ((rr+rl) < bp) and (rl < 64) do Inc(rl);

      if (rl > r_rs) then
      begin
        sr := rr-bp;
        r_rs := rl;
      end;

      Inc(rr);
    end;




    if (r_rb > 2) and (r_rb > r_rw) and (r_rb > r_rs) then
    begin
      if (tb > 0) then
      begin
        write_trash(tb, @FInBuf[bp-tb]);
        tb := 0;
      end;

      write_byte(r_rb, x);
      bp := bp + r_rb;
    end

    else
      if (r_rw > 2) and ((r_rw*2) > r_rs) then
      begin
        if (tb > 0) then
        begin
          write_trash(tb, @FInBuf[bp-tb]);
          tb := 0;
        end;

        write_word(r_rw, y);
        bp := bp + r_rw*2;
      end

      else
        if (r_rs > 3) then
        begin

          if (tb > 0) then
          begin
            write_trash(tb, @FInBuf[bp-tb]);
            tb := 0;
          end;

          write_string(r_rs, sr);
          bp := bp + r_rs;
        end
        else
        if (tb >= 64) then
        begin
          write_trash(tb, @FInBuf[bp-tb]);
          tb := 0;
        end
        else
          begin
            Inc(tb);
            Inc(bp);
          end;
  end;

  if (tb > 0) then
    write_trash(tb, @FInBuf[bp-tb]);

  write_end;

  Result := FOutIndex;

end;






end.

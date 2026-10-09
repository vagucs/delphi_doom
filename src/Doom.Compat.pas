unit Doom.Compat;

{
  DOOM generic portado do python_doom para Delphi FireMonkey.

  Por Wagner Nunes da Silva

  vagucs@bol.com.br
  vagucs@vagucs.com.br
  vagucs@gmail.com

  www.vagucs.com.br

  Estouro de 32 bits e ponto fixo 16.16, iguais a doom/compat.py.
}

interface

const
  FRACBITS = 16;
  FRACUNIT = 65536;

function AsU32(N: Int64): Cardinal;
function AsI32(N: Int64): Integer;
function UShr32(N: Int64; Bits: Integer): Cardinal;
function SHar32(N: Integer; Bits: Integer): Integer;
function FixedMul(A, B: Integer): Integer;
function FixedDiv(A, B: Integer): Integer;

implementation

function AsU32(N: Int64): Cardinal;
begin
  Result := Cardinal(N and $FFFFFFFF);
end;

function AsI32(N: Int64): Integer;
begin
  Result := Integer(AsU32(N));
end;

function UShr32(N: Int64; Bits: Integer): Cardinal;
begin
  if Bits <= 0 then
    Exit(AsU32(N));
  if Bits >= 32 then
    Exit(0);
  Result := AsU32(N) shr Bits;
end;

function SHar32(N: Integer; Bits: Integer): Integer;
begin
  if Bits <= 0 then
    Exit(N);
  if Bits >= 31 then
  begin
    if N < 0 then
      Result := -1
    else
      Result := 0;
    Exit;
  end;
  Result := N shr Bits;
  if N < 0 then
    Result := Result or Integer($FFFFFFFF shl (32 - Bits));
end;

function FloorShr16(V: Int64): Int64;
begin
  if V >= 0 then
    Result := V shr FRACBITS
  else
    Result := -(((-V) + (FRACUNIT - 1)) shr FRACBITS);
end;

function FixedMul(A, B: Integer): Integer;
begin
  Result := AsI32(FloorShr16(Int64(A) * Int64(B)));
end;

function FixedDiv(A, B: Integer): Integer;
var
  AbsA, AbsB: Int64;
  Quot: Int64;
begin
  if B = 0 then
  begin
    if A >= 0 then
      Result := $7FFFFFFF
    else
      Result := Integer($80000000);
    Exit;
  end;
  AbsA := Abs(Int64(A));
  AbsB := Abs(Int64(B));
  if (AbsA shr 14) >= AbsB then
  begin
    if (Int64(A) xor Int64(B)) < 0 then
      Result := Integer($80000000)
    else
      Result := $7FFFFFFF;
    Exit;
  end;
  Quot := Int64(A) shl FRACBITS;
  if B < 0 then
  begin
    Quot := -Quot;
    B := -B;
  end;
  if Quot >= 0 then
    Result := AsI32(Quot div B)
  else
    Result := AsI32(-(((-Quot) + (B - 1)) div B));
end;

end.

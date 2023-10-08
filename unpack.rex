/* REXX */
/*

Function:
         Unpack file packed by CMS COPYFILE or TSO/ISPF EDIT.

Syntax:
         UNPACK [-binary|-text] [-ascii codepage] [-ebcdic codepage] pack file 

Usage:
         See unpack.htm

(C) 2023 Gregori Bliznets GregoryTwin@gmail.com
(C) 2009-2010 https://ibmmainframes.com/about59768.html

*/
trace off   
call rxfuncadd 'sysloadfuncs', 'rexxutil', 'sysloadfuncs'
call sysloadfuncs
parse arg args
opt = '-'
source = ''
target = ''
ebcdic = ''
ascii = ''
binary = 0
args = strip(args, 'L')
do while (args <> '' & left(args, 1) = opt)
  parse var args option args
  parse upper var option +1 keyword
  select
  when abbrev('BINARY', keyword, 1)
  then binary = 1
  when abbrev('TEXT', keyword, 1)
  then binary = 0
  when abbrev('EBCDIC', keyword, 1)
  then do
    parse var args ebcdic args
    /* ask for test translation to validate code page */
    call SysFromUnicode '6F006B003F00'X, ebcdic, , ,stem.
    if result <> 0
    then call msg '004T Code page "'ebcdic'" is incorrect or unsupported'
    end
  when abbrev('ASCII', keyword, 1)
  then do
    parse var args ascii args
    if ascii = ''
    then call msg '002T Missed value of option "'option'"'
    /* ask for test translation to validate code page */
    call SysToUnicode 'ok?', ascii, , stem.
    if result <> 0
    then call msg '004T Code page "'ascii'" is incorrect or unsupported'
    end
  when kwd = opt
  then leave /* Explicit fence */
  otherwise
    call msg '003T Invalid option "'Option'"'
  end
end
parse var args source target other 
if source = ''
then call msg '004T Source file was not specified'
if target = ''
then call msg '004T Target file was not specified'
if other <> ''
then call msg '006T Extraneous parameters: "'other'"'
if stream(source, 'c', 'query exists') = ''
then call msg '007T File "'source'" not found'
total = stream(source, 'c', 'query size')
if total = 0 
then call msg '008T File "'source'" is empty'

select
when ebcdic = '' & ascii = ''
then do /* use internal translation table from code page 1025 to code page 1251 */
  xlate = '00010203EC09D37FDAC2E50B0C0D0E0F'x ,
       || '10111213EB0A08D11819D8901C1D1E1F'x ,
       || 'D4C3D0E9CF0A171BC4D2D5C0C1050607'x ,
       || 'DDCA16CCCBD9DC04C9DBDEEF1415A21A'x ,
       || '20A09083B8BABEB3BFBC5B2E3C282B21'x ,
       || '269A9C9E9DA29FDAB9805D242A293B5E'x ,
       || '2D2FA5A8AABDB2AFA38A7C2C255F3E3F'x ,
       || '8C8E8DADA28FFEE0E1603A2340273D22'x ,
       || 'F6616263646566676869E4E5F4E3F5E8'x ,
       || 'E96A6B6C6D6E6F707172EAEBECEDEEEF'x ,
       || 'FF7E737475767778797AF0F1F2F3E6E2'x ,
       || 'FCFBE7F8FDF9F7FADEC0C1D6C4C5D4C3'x ,
       || '7B414243444546474849D5C8C9CACBCC'x ,
       || '7D4A4B4C4D4E4F505152CDCECFDFD0D1'x ,
       || '5CA7535455565758595AD2D3C6C2DCDB'x ,
       || '30313233343536373839C7D8DDD9D71A'x 
  end
when ebcdic <> '' & ascii <> ''
then do /* bit a kludge: use SysToUniCode/SysFromUniCode to build translate table from EBCDIC to ASCII */
  rc = SysToUnicode(xrange('00'x, 'FF'x), ebcdic, , u.)
  rc = max(rc, SysFromUnicode(u.!text, ascii, , , a.))
  if rc <> 0
  then call msg '030T Cannot create translation table from 'ebcdic' to 'ascii', rc 'rc
  xlate = a.!text
  drop u. a.
  end
when ebcdic = '' & ascii <> ''
then call msg '033T Option -ascii specified, but -ebcdic missed'
when ebcdic <> '' & ascii = ''
then call msg '033T Option -ebcdic specified, but -ascii missed'
end
rc = stream(source, 'c', 'open read')
rc = stream(target, 'c', 'open write replace')

header = charin(source,,8)
select
when left(header,4) = '000140E5'x
then recfm = 'V'
when left(header,4) = '000140C6'x
then recfm = 'F'
otherwise
  call msg '011T Not a packed format: wrong header:' c2x(header)
end
fill = substr(header,3,1)
lrecl = c2d(substr(header,5,4))
call msg '022I Data set attributes: RECFM='recfm',LRECL='lrecl
line = ''
do forever
  c = charin(source,,1)
  select
  when c = 'FF'x
  then leave
  when c = '78'x
  then line = line || repeat(1, fill)
  when c = '79'x 
  then line = line || repeat(2, fill)
  when c = '7A'x,       
  then line = line || repeat(1)
  when c = '7B'x,       
  then line = line || repeat(2)
  when c = '7C'x 
  then do
    l = charin(source,,1)
    call write target, line
    end
  when c = '7D'x 
  then line = line || repeat(2, fill)
  when c = '7E'x
  then line = line || repeat(1)
  when c = '7F'x
  then line = line || repeat(2)
  when c = 'F8'x | c = 'FC'x
  then line = line || repeat(1)
  when c = 'F9'x | c = 'FD'x
  then line = line || repeat(2)
  when c >= '80'x
  then line = line || charin(source,,c2d(c)-127)
  otherwise
    line = line || copies(fill, c2d(c)+1)
  end
  do while length(line) >= lrecl
    call write target, left(line, lrecl)
    line = substr(line, lrecl+1)
  end
end
do while length(line) >= lrecl
  call write target, left(line, lrecl)
  line = substr(line, lrecl+1)
end

quit:
rc = stream(source, 'c', 'close')
rc = stream(target, 'c', 'close')
exit

repeat:
  l = charin(source,,arg(1))
  if arg() = 1
  then r = charin(source,,1)
  else r = arg(2)
  return copies(r, c2d(l)+1)

write:
  if binary = 0
  then call lineout arg(1), ASCII(arg(2))
  else call charout arg(1), arg(2)
  if result <> 0
  then call msg '029T Error 'result' writing file' arg(1)
  return

ASCII:
  return translate(arg(1), xlate)

EBCDIC: /* currently unused */
  return translate(arg(1), xrange('00'x, 'FF'x), xlate)

msg:
  say arg(1)
  if substr(arg(1),4,1) = 'T' /* message severity code */
  then signal quit
  return ''


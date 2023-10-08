/* REXX */
/*

Function:
         Restore member(s) from IEHOVE unloaded data set.

Syntax:
         UNMOVE [-binary|-text] [-ascii codepage] [-ebcdic codepage] file [{member|*} [rename]] 

Usage:
         See unmove.htm

(C) 1996-2023 Gregori Bliznets GregoryTwin@gmail.com

*/
trace off
call rxfuncadd 'sysloadfuncs', 'rexxutil', 'sysloadfuncs'
call sysloadfuncs
parse arg args
opt = '-'
source = ''
ebcdic = ''
ascii = ''
binary = 0
rename = ''
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
parse var args source member rename other 
if source = ''
then call msg '004T File was not specified'
if other <> ''
then call msg '006T Extraneous parameters: "'other'"'
if stream(source, 'c', 'query exists') = ''
then call msg '007T File "'source'" not found'
total = stream(source, 'c', 'query size')
if total = 0 
then call msg '008T File "'source'" is empty'
parse upper var member member

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

data = ''
seq = 1
call getblock
token = 'THIS IS AN UNLOADED DATA SET PRODUCED BY'
l = length(token)
if ASCII(left(block,l)) <> token
then call msg '011T Not an unloaded IEHMOVE format: wrong token 'c2x(left(block,l))
call getblock /* this block in DSCB F1 of the original data set */
parse var block udsn +44 . +1 uvolid +6 . +31 udsorg +1 . +1 urecfm +1 . +1 ublksz +2 ulrecl +2 ukeylen +2 143 flags +1
udsn = strip(ASCII(udsn))
uvolid = ASCII(uvolid)
parse value attr(udsorg, urecfm, ublksz, ulrecl) with dsorg recfm blksize lrecl 
call msg '021I Data set 'udsn' from 'uvolid
call msg '022I Data set attributes: DSORG='dsorg',RECFM='recfm',LRECL='lrecl',BLKSIZE='blksize
if dsorg <> 'PO' 
then do
  if member <> ''
  then call msg '031W Member specified for DSORG='dsorg' data set, ignored'
  if pos('%M%', translate(rename)) > 0
  then call msg '009T Invalid rename pattern "'rename'"'
  target = rename
  target = changestr('%D%', target, udsn)
  end
if dsorg = 'UN'
then call msg '031W Data set was DSORG='dsorg', original data structure lost'
if recfm = 'U' & binary = 1
then call msg '032W Data set was RECFM=U, original data structure lost'
if bitand(FLAGS, '20'X) = '20'X
then call msg '034W Data set was written by OC PB IEHMOVE'
if bitand(FLAGS, '10'X) = '10'X
then call msg '034W Data set was written by OC PB IEHMOVE using data compression'
load = 0
done = 0
name = ''
do forever
  call getblock
  select
  when I = '08'x
  then do
    if (name <> '') & (load = 1)
    then do
      rc = stream(target, 'c', 'close')
      call msg '018I Member 'name' extracted to 'target
      done=1
      end
    load = 0
    name = strip(ASCII(left(block, 8)))
    if member = ''
    then call msg '020I Member' left(name,8) 'TTR' c2x(ttr)
    if (member = '*') | (member = name)
    then load = 1
    target = rename
    target = changestr('%D%', target, udsn)
    target = changestr('%M%', target, name)
    end
  when (I = '10'x) & (load = 1)
  then call msg '025W Member 'name' notelist ignored'
  when (I = '20'x) & (load = 1)
  then call store
  when I = '02'x
  then call store
  when I = '04'x
  then call msg '026W Dummy record of DSORG=DA data set ignored'
  when I = '01'x
  then leave /* Pseudo-EOF */
  otherwise nop
  end
end
if (dsorg = 'PO') & (done = 0) & (member <> '*') & (member <> '')
then call msg '016T Member 'member' not found in 'udsn
if dsorg <> 'PO'
then call msg '024I Data set 'udsn' extracted to 'target

quit:
if source <> ''
then rc = stream(source, 'c', 'close')
exit

store:
  select
  when recfm = 'FB'
  then do
    l = lrecl+1
    do while block <> ''
      parse var block record =(l) block
      call write target, record
    end
    end
  when recfm = 'VB'
  then do
    parse var block BDW +2 . +2 block
    do while block <> ''
      parse var block RDW +2 . +2 block
      l = c2x(RDW)+1
      parse var block record =(l) block
      call write target, record
    end
    end
  when recfm = 'V'
  then do
    parse var block BDW +2 .+2 block
    call write target, block
    end
  otherwise /* recfm = 'F' or recfm = 'U' */
    call write target, block
  end
  return

getblock:
  block = ''
  if length(data) < 4
  then data = data || getpiece()
  parse var data LLI +3 data
  parse var LLI LL +2 I +1
  if bitand(I, '80'x) = '80'x
  then do /* TTR follow LLI */
    if length(data) < 3
    then data = data || getpiece()
    parse var data TTR +3 data
    end
  else TTR = ''
  LL = c2d(LL)
  do while LL > length(data)
    LL = LL - length(data)
    block = block || data
    data = getpiece()
  end
  if LL > 0
  then do
    block = block || substr(data, 1, LL)
    data = substr(data, LL+1)
    end
  I = bitand(I, '3F'x)
  return

/* read unloaded card images */
getpiece:
  data = charin(source,,80)
  if length(data) <> 80
  then call msg '015T File 'source' premature end of data'
  parse var data s +2 data
  if seq <> c2d(s)
  then do
    if seq = 1
    then call msg '009T Not an unloaded IEHMOVE format: wrong' c2x(s)
    else call msg '012T Unloaded IEHOVE data set incomplete or in error: found' c2x(s) 'expected' d2x(seq)
    end
  seq = (seq+1)//65536
  return data

/* decode data set attributes to visible */
attr: procedure
  parse arg dsorg, recfm, blksize, lrecl
  select
  when bitand(dsorg, '0200'x) = '0200'x
  then dsorg = 'PO'
  when bitand(dsorg, '2000'x) = '2000'x
  then dsorg = 'DA'
  when bitand(dsorg, '4000'x) = '4000'x
  then dsorg = 'PS'
  otherwise
    dsorg = 'UN'
  end
  format=''
  select
  when bitand(recfm, 'C0'x) = 'C0'x
  then format = 'U'
  when bitand(recfm, '80'x) = '80'x
  then format = 'F'
  when bitand(recfm, '40'x) = '40'x
  then format = 'V'
  otherwise
    format = '0'
  end
  if bitand(recfm, '10'x) = '10'x 
  then format = format'B'
  if bitand(recfm, '08'x) = '08'x 
  then format = format'S'
  if bitand(recfm, '04'x) = '04'x 
  then format = format'A'
  if bitand(recfm, '02'x) = '02'x 
  then format = format'M'
  lrecl = c2d(lrecl)
  blksize = c2d(blksize)
  return dsorg format blksize lrecl

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

/* Case-independent changestr function */
ChangeStr: procedure
  parse arg needle, haystack, newneedle
  parse upper arg upper_needle, upper_haystack, upper_newneedle
  result = ''
  x = 1;
  do forever
    y = pos(upper_needle,upper_haystack,x)
    if y = 0
    then leave
    result=result''substr(haystack,x,y-x)''newneedle
    x = y+length(needle)
  end
  result=result''substr(haystack,x)
  return result

msg:
  say arg(1)
  if substr(arg(1),4,1) = 'T' /* message severity code */
  then signal quit
  return ''

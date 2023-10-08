/* Load file(s) from AWSTAPE tape image to flat disk file */
/*

Function:
         Load AWS tape files to disk.

Syntax:
         AWSLOAD [options] awsfile {fileno|*} [rename]

Options:
         -binary | -text
         -reblock length
         -ascii codepage
         -ebcdic codepage
         -blp 

Usage:
         See awsload.htm

(C) 1996-2023 Gregori Bliznets GregoryTwin@gmail.com

*/
trace off
call rxfuncadd 'sysloadfuncs', 'rexxutil', 'sysloadfuncs'
call sysloadfuncs
parse arg args
file = ''
reblock = ''
binary = 0
ebcdic = ''
ascii = ''
blp = 0
rename = ''
target = ''
opt = '-'
args = strip(args, 'L')
do while (args \= '' & left(args, 1) = opt)
  parse var args option args
  parse upper var option +1 Keyword
  select
  when abbrev('BINARY', keyword, 1)
  then binary = 1
  when abbrev('TEXT', keyword, 1)
  then binary = 0
  when abbrev('BLP', keyword, 3)
  then blp = 1
  when abbrev('EBCDIC', keyword, 1)
  then do
    parse var args ebcdic args
    if ascii = ''
    then call msg '001T Missed value of option "'option'"'
    /* ask for test translation to validate code page */
    call SysFromUnicode '6F006B003F00'X, ebcdic, , ,stem.
    if result <> 0
    then call msg '004T Code page "'ebcdic'" is incorrect or unsupported'
    end
  when abbrev('ASCII', keyword, 1)
  then do
    parse var args ascii args
    if ascii = ''
    then call msg '001T Missed value of option "'option'"'
    /* ask for test translation to validate code page */
    call SysToUnicode 'ok?', ascii, , stem.
    if result <> 0
    then call msg '004T Code page "'ascii'" is incorrect or unsupported'
    end
  when abbrev('REBLOCK', Keyword, 1)
  then do
    parse var args reblock args
    if lrecl = ''
    then call msg '001T Missed value of option "'Option'"'
    if datatype(reblock, 'N') = 0
    then call msg '002T Invalid value of option "'Option'": 'reblock
    end
  when kwd = opt
  then leave /* Explicit fence */
  otherwise
    call msg '003T Invalid option "'Option'"'
  end
end
parse var args awsfile file rename other 
if awsfile = ''
then call msg '004T AWS file was not specified'
if file = ''
then call msg '005T File sequential number was not specified'
if (file <> '*') & (datatype(file, 'W') = 0)
then call msg '009T File sequential number 'file' is not a whole number'
if other <> ''
then call msg '006T Extraneous parameters: "'other'"'
if stream(awsfile, 'c', 'query exists') = ''
then call msg '007T File "'awsfile'" not found'
if stream(awsfile, 'c', 'query size') = 0 
then call msg '008T File "'awsfile'" is empty'

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
nfile = 1
nbyte = 0
nblks = 0
dsn = ''
if blp = 0
then label = label()
if left(label,2) = 'SL'
then call msg '013I Tape has standard labels, volume is' substr(label,4)
if rename = ''
then do
  if left(label,2) = 'SL'
  then rename = '%D%'
  else rename = 'FILE%F%'
  end
do forever
  rc = read()
  select
  when rc = 0
  then do /* Data block */
    nblks = nblks+1
    lfile = nfile
    skip = 0
    if blp = 0 & left(label,2) = 'SL'
    then do
      lfile = (nfile-1)%3+1
      skip = (nfile//3 <> 2)
      if (nblks = 1) & (nfile//3 = 1)
      then parse value(ASCII(data)) with . +4 dsn +17 .
      end
    if (skip = 0) & (file = '*' | file = lfile)
    then do
      if nblks = 1
      then do
        target = rename
        target = changestr('%D%', target, strip(dsn))
        target = changestr('%F%', target, right(lfile,3,'0'))
        target = changestr('%N%', target, lfile)
        target = changestr('%L%', target, strip(substr(label,4)))
        rc = stream(target, 'c', 'open write replace')
        end
      call write
      end
    end
  when rc = -1
  then do
    if (skip = 0) & (file = '*' | file = lfile)
    then do
      call stream target, 'c', 'close'
      call msg '010I Tape file 'right(lfile,3,'0')'('right(nfile,3,'0')') copied to 'target
      end
    if (file = lfile) & (skip = 0)
    then leave
    nfile = nfile+1
    nblks = 0
    end
  when rc = -2
  then leave
  end
end /* do forever */

quit:
if target <> ''
then call stream target, 'c', 'close'
if awsfile <> ''
then call stream awsfile, 'c', 'close'
exit 0

/* read awstape block */
read:
  data = ''
  f = '00'x /* flags */
  rc = 0
  do while bitand(f,'20'x) = '00'x
    h = charin(awsfile,,6) /* header */
    nbyte = nbyte + 6
    if length(h) = 0
    then do /* End of tape encountered */
      rc = -2
      leave
      end
    parse var h l +2 . +2 f +1 . +1
    l = c2d(reverse(l))
    if bitand(f,'40'x) = '40'x
    then do /* End of file encountered */
      rc = -1
      leave
      end
    data = data || charin(awsfile,,l)
    nbyte = nbyte + length(data)
  end
  return rc

/* recognize label type (SL, NL) */
label:
  call stream awsfile, 'c', 'seek 1 read'
  label = 'NL'
  rc = read()
  if rc = 0 & length(data) = 80
  then do
    data = ASCII(data)
    if left(data,4) = 'VOL1'
    then do /* There could be extra volume labels VOL2-VOL9, just ignore */
      label = 'SL,'substr(data,5,6)
      p = stream(awsfile, 'c', 'query position')
      do until rc <> 0
        rc = read()
        if rc <> 0
        then leave
        data = ASCII(data)
        if left(data,3) <> 'VOL'
        then leave
        p = stream(awsfile, 'c', 'query position')
      end
      call stream awsfile, 'c', 'seek 'p' read'
      end
    end
  if label = 'NL'
  then call stream awsfile, 'c', 'seek 1 read'
  /* for SL leave tape after volume label(s), before HDR1 */
  return label

write:
  if binary = 0
  then data = ASCII(data) /* Translate EBCDIC -> ASCII */
  l = length(data)
  if reblock <> ''
  then do
    if l // reblock <> 0 
    then call msg '011W Tape file 'nfile' record 'nblks' wrong length 'l
    n = l % reblock
    l = reblock
    end
  else n = 1
  do i = 1 to n
    record = substr(data, (i-1)*l+1, l)
    if binary = 1
    then call charout target, record /* Write raw data */
    else call lineout target, record /* Append with CRLF */
  end i
  return 0

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

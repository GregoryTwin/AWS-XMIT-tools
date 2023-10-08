/* Write disk file to AWSTAPE file */
/*

Function:
         Write disk file to AWSTAPE file. 

Syntax:
         AWSDUMP [options] source_file awsfile n {F[B] | V[B][S] | U} lrecl [blksize]

         options:
         -binary | -text
         -ascii codepage
         -ebcdic codepage
         -blp 
         --

Usage:
         See awsdump.htm

(C) 2022-2023 Gregori Bliznets GregoryTwin@gmail.com

*/
trace off
call rxfuncadd 'sysloadfuncs', 'rexxutil', 'sysloadfuncs'
call sysloadfuncs
parse arg args
debug = 0
binary = 0
ebcdic = ''
ascii = ''
blp = 0
label = ''
opt = '-'
nbyte = 0
awsfile = ''
source = ''
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
  when abbrev('DEBUG', Keyword, 1)
  then debug = 1
  when kwd = opt
  then leave /* Explicit fence */
  otherwise
    call msg '003T Invalid option "'Option'"'
  end
end

parse var args source awsfile file recfm lrecl blksize other 
if source = ''
then call msg '004T Source file name is missed'
if awsfile = ''
then call msg '005T AWS file name is missed'
if file = ''
then call msg '005T Data set sequential number is missed'
if recfm = ''
then call msg '010T Record format (RECFM) is missed'
parse upper var recfm recfm
if wordpos(recfm, 'F FB V VB VS VBS U') = 0
then call msg '009T Invalid record format "'recfm'"'
if lrecl = ''
then call msg '011T Record length (LRECL) is missed'
if datatype(lrecl, W) = 0
then call msg '009T Invalid record length "'lrecl'"'
if wordpos(recfm, 'FB VB VBS') > 0
then do
  if blksize = ''
  then call msg '011T Block size (BLKSIZE) is missed'
  if datatype(blksize, W) = 0
  then call msg '009T Invalid block size "'blksize'"'
  end
else blksize = lrecl
if (recfm = 'FB') & (blksize // lrecl <> 0)
then call msg '009T Invalid block size "'blksize'"'
if (recfm = 'VB') & (blksize < lrecl+4)
then call msg '009T Invalid block size "'blksize'"'
if other <> ''
then call msg '006T Extraneous parameters: "'other'"'
if stream(source, 'c', 'query exists') = ''
then call msg '007T File "'source'" not found'
if stream(source, 'c', 'query size') = 0 
then call msg '008T File "'source'" is empty'
if datatype(file, 'W') = 0
then call msg '009T Invalid data set sequential number "'file'"'
select
when recfm = 'FB'
then blkattr = 'B'
when recfm = 'VB'
then blkattr = 'B'
when recfm = 'VS'
then blkattr = 'S'
when recfm = 'VBS'
then blkattr = 'R'
otherwise
  blkattr = ' '
end

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
if stream(awsfile, 'c', 'query exists') = ''
then label = 'NL'
p = 1
if blp = 0 & label = ''
then label = label()
if file > 1
then do
  rc = fsf(file)
  if rc = -2
  then call msg '035T Premature end of tape'
  end
rc = stream(awsfile, 'c', 'close')
rc = stream(awsfile, 'c', 'open write')
call stream awsfile, 'c', 'seek ='p' write char'
size=0
psize=0
total = 0
count = 0
if left(label,2) = 'SL'
then do /* write header labels */
  if file = 1
  then psize = 80 /* VOL1 */
  dsn = translate(filespec('name', source))
  yyyymmdd = date('S')
  c = substr(yyyymmdd,1,2) - 19
  if c < 0
  then c = ' '
  ddd = date('D')
  cyyddd = c''substr(yyyymmdd,3,2) || right(ddd,3,'0')
  call write EBCDIC('HDR1' || left(dsn,17) || substr(label,4,6) || '0001' || '0001' || '      ' || cyyddd || '000000' || '0' || '000000' || left('AWSDUMP 1.0', 13) || '       ')
  call write EBCDIC('HDR2' || left(recfm,1) || right(blksize,5,'0') || right(lrecl,5,'0') || '30' || copies(' ',21) || blkattr || copies(' ',41))
  call WTM
  end
if binary = 0
then do /* text mode */
  do n = 1 while lines(source) > 0
    block = ''
    record = linein(source)
    select
    when left(recfm,1) = 'F'
    then do
      if length(record) > lrecl
      then call msg '020W Record 'n' truncated:' length(record)
      record = EBCDIC(left(record, lrecl))
      if (length(block) + length(record)) > blksize
      then do
        call write block
        block = record
        end
      else block = block || record 
      end
    when left(recfm,1) = 'V'
    then do
      if length(record) > lrecl-4
      then call msg '020W Record 'n' truncated:' length(record)
      select
      when recfm = 'V'
      then do
        RDW =  d2c(length(record)+4, 2) || '0000'x
        block = RDW || EBCDIC(record)
        call write block
        end
      when recfm = 'VB'
      then do
        RDW = d2c(length(record)+4, 2) || '0000'x
        record = RDW || EBCDIC(record)
        if (length(block) + length(record)) > (blksize - 4)
        then do
          BDW = d2c(length(block)+4, 2) ||'0000'x
          block = BDW || block /* add BDW */
          call write block
          block = record
          end  
        else block = block || record
        end
      when recfm = 'VBS'
      then do
        if length(record) + 4 + length(block) + 4 < blksize
        then do /* record fit block */
          RDW = d2c(length(record)+4, 2) || '0000'x
          block = block || RDW || record
          if length(block) + 4 = blksize
          then do
            BDW = d2c(length(block)+4, 2) ||'0000'x
            block = BDW || block /* add BDW */
            call write block
            block = ''
            end
          end
        else do /* segmentation required */
          r = blksize - length(block) - 4 
          if r > 0
          then do
            SDW = d2c(r+4, 2) ||'0000'x
            block = block || SDW || left(record, r)
            BDW = d2c(length(block)+4, 2) ||'0001'x
            call write block
            record = substr(record, r+1)
            if length(record) + 8 < blksize
            then SDW = d2c(length(record)+4, 2) ||'0002'x
            else SDW = d2c(length(record)+4, 2) ||'0003'x 
            block = SDW || record
            end
          end
        end
      end
      end
    when left(recfm,1) = 'U'
    then do
      if length(record) > lrecl
      then call msg '020W Record 'n' truncated:' length(record)
      record = EBCDIC(record)
      call write record
      end
    end
  end /* do while */
  if block <> ''
  then call write block /* residual block */
  end
else do /* binary mode */
  do n = 1 while chars(source) > 0
    select
    when left(recfm,1) = 'F'
    then block = charin(source,,blksize)
    when left(recfm,1) = 'V'
    then do
      BDW = charin(source,,4)
      if length(BDW) = 0
      then leave
      if bitand(BDW, '80000000'x) = '80000000'x
      then do
        say n c2x(BDW)
        LL = bitand(BDW, '7FFFFFFF'x) /* Extended BDW?! */
        ZZ = '0000'x
        end
      else parse var BDW LL +2 ZZ +2
      LL = c2d(LL)
      select
      when LL = 0
      then block = BDW
      when ZZ <> '0000'x
      then call BDW! 'rightmost bytes not zero'
      when LL > blksize
      then call BDW! 'wrong length (too long)'
      when LL < 5
      then call BDW! 'wrong length (too small)'
      otherwise
        block = BDW || charin(source,,LL-4)
        if LL <> length(block)
        then call BDW! 'unexpected end of data'
      end
      end
    when left(recfm,1) = 'U'
    then block = charin(source,,lrecl)
    end
    call write block
  end
  end
call WTM
if left(label,2) = 'SL'
then do /* write header labels */
  dsn = translate(filespec('name', source))
  yyyymmdd = date('S')
  c = substr(yyyymmdd,1,2) - 19
  if c < 0
  then c = ' '
  ddd = date('D')
  cyyddd = c''substr(yyyymmdd,3,2) || right(ddd,3,'0')
  call write EBCDIC('EOF1' || left(dsn,17) || substr(label,4,6) || '0001' || '0001' || '      ' || cyyddd || '000000' || '0' || right(count,6,'0') || left('AWSDUMP 1.0', 13) || '       ')
  call write EBCDIC('EOF2' || left(recfm,1) || right(blksize,5,'0') || right(lrecl,5,'0') || '30' || copies(' ',21) || blkattr || copies(' ',41))
  call WTM
  end
call WTM

quit:
if source <> ''
then call stream source, 'c', 'close'
if awsfile <> ''
then call stream awsfile, 'c', 'close'
exit 0

BDW!:
  parse arg reason
  p = stream(source, 'c', 'query position read')
  p = d2x(p-5) /* BDW already received */
  call msg '020S Block 'n '(offset 'p'): incorrect BDW' c2x(BDW) reason
  signal quit
  return /* never reached */

/* recognize label type (SL, NL) */
label:
  call stream awsfile, 'c', 'seek 1 read'
  p = 1
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
      end
    end
  /* for SL leave tape after volume label(s), before HDR1 */
  return label

/* read awsfile block */
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

/* write awsfile block */
write:
  count = count + 1
  parse arg data
  l = length(data)
  awsflg = '8000'x /* new record bit on */
  if debug
  then call msg '013D Recieved data (Block 'count', size 'l c2x(left(data,8)) || ')'
  total = total + l
  chunk = 32760 /* IBM recommend 4096 */
  do while l > chunk
    awshdr = reverse(d2c(chunk,2)) || reverse(d2c(psize,2)) || awsflg
    if debug
    then call msg '014D Write data (Header' c2x(awshdr) || ')'
    call charout awsfile, awshdr || substr(data,1,chunk)
    awsflg = bitand(awsflg, '7FFF'x) /* new record bit off */
    data = substr(data, chunk+1)
    psize = chunk
    l = l - chunk
  end
  awsflg = bitor(awsflg, '2000'x) /* end record bit on */
  awshdr = reverse(d2c(l,2)) || reverse(d2c(psize,2)) || awsflg
  if debug
  then call msg '015D Write data (Header' c2x(awshdr) || ')'
  call charout awsfile, awshdr || substr(data,1,l)
  data = ''
  awsflg = bitand(awsflg, '5FFF'x) /* off new record and end record bits */ 
  psize = l
  return 0

/* Forward Skip File */
FSF:
  parse arg n /* logical file */
  rc = 0
  call stream awsfile, 'c', 'seek =1 read'
  if left(label,2) = 'SL'
  then n = 3*(n-1)
  else n = n-1
  if n = 0
  then return 0
  f = '00'x
  do i = 1 to n
    do forever
      h = charin(awsfile,,6)
      if length(h) = 0
      then do
        rc = -2 /* EOT */
        leave i
        end
      parse var h l +2 . +2 f +1 . +1
      l = c2d(reverse(l))
      if bitand(f, '40'x) = '40'x /* EOF */
      then leave
      call stream awsfile, 'c', 'seek +'l' read'
    end
  end i
  p = stream(awsfile, 'c', 'query position')
  return rc

/* Write Tape Mark */
WTM:
  awshdr ='0000'x || reverse(d2c(psize,2)) || '4000'x /* end of file bit on */
  if debug
  then call msg '016D Write EOF (Header' c2x(awshdr) || ')'
  call charout awsfile, awshdr
  count = 0
  return 0

ASCII:
  return translate(arg(1), xlate)

EBCDIC:
  return translate(arg(1), xrange('00'x, 'FF'x), xlate)

msg:
  say arg(1)
  if substr(arg(1),4,1) = 'T' /* message severity code */
  then signal quit
  return ''

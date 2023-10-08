/* REXX */
/*

Function:
         Restore member(s) from IEBCOPY unloaded data set.

Syntax:
         UNCOPY [-binary|-text] [-ascii codepage] [-ebcdic codepage] file [{member|*} [rename]] 

Usage:
         See uncopy.htm

(C) 2023 Gregori Bliznets GregoryTwin@gmail.com

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
target = ''
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
    call msg '003T Invalid option "'option'"'
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
if rename = ''
then rename = '%M%'

call read
/* decode IEBCOPY cntl record COPYR1 */
if substr(data,10,3) <> 'CA6D0F'x;
then call msg '011T Not an unloaded IEBCOPY format: wrong token 'c2x(substr(COPYR1,10,3))
flags = substr(data,9,1)
select
when bitand(flags,'C0'x) = '00'x
then pdse = 0 /* valid PDS data set */
when bitand(flags,'C0'x) = '40'x
then pdse = 1 /* valid PDSE data set */
when bitand(flags,'C0'x) = '80'x
then call msg '012T Unloaded IEBCOPY data set incomplete or in error'
otherwise
  call msg '013T Unknown unloaded IEBCOPY data set format'
end
parse var data 13 udsorg +2 ublksz +2 ulrecl +2 urecfm +1 ukeyln +1 ,
                  uoptcd +1 udfsms +1 tblksz +2 udevt +20 ncopyr +2
parse value attr(udsorg, urecfm, ublksz, ulrecl) with dsorg recfm blksize lrecl 
call msg '022I Data set attributes: DSORG='dsorg',RECFM='recfm',LRECL='lrecl',BLKSIZE='blksize
ublksz = c2d(ublksz)
ulrecl = c2d(ulrecl)
urecfm = bitand(urecfm,'C0'x)
if urecfm = '00'x
then call msg '014T Unsupported record format in original PDS/PDSE'

call read
/* decode IEBCOPY cntl record COPYR2 */
p = 9 /* skip BDW+RDW */
deb.0 = c2d(substr(data,p,1)) /* number of extents in this DEB */
p = p+16
if pdse = 1
then trkscyl = 256
else trkscyl = c2d(substr(udevt,11,2))
rel = 0
do i = 1 to deb.0
  start = c2d(substr(data,p+6,2))*trkscyl+c2d(substr(data,p+8,2))
  end = c2d(substr(data,p+10,2))*trkscyl+c2d(substr(data,p+12,2))
  deb.i = start end rel
  rel = rel+end-start+1 /* adjust relative for next pass */
  p = p+16
end i

/* read and decode IEBCOPY directory records */
dir. = ''
ttr.0 = 0
do n = 1
  call read
  data = substr(data,9) /* discard BDW+RDW */
  c = length(data)%276 /* 276 = 256 dir block + 12 byte count + 8 byte key */
  do c
    parse var data . +20 l +2 dirblock +254 data  /* ignore FMBBCCHHRKDD 12, key 8, byte count 2 */
    l = c2d(l) /* byte count */
    p = 1
    do while (p<l-1)
      if substr(dirblock,p,8) = copies('FF'x,8)
      then leave n /* end of directory */
      ttr = c2x(substr(dirblock,p+8,3))
      i = ttr.0 + 1
      ttr.i = ttr
      dir.ttr = strip(ASCII(substr(dirblock,p,8)))
      ttr.0 = i
      if member = ''
      then call msg '020I Member' left(dir.ttr,8) 'TTR' ttr
      ul = c2d(bitand(substr(dirblock,p+11,1),'1F'x))
      p = p+8+3+1+ul*2
    end
  end 
end n

if member = ''
then signal quit
found = 0
if member <> '*'
then do
  do i = 1 to ttr.0
    ttr = ttr.i
    if dir.ttr = member
    then found = 1
  end i
  if found = 0
  then call msg '016T Member 'member' not found in unloaded data set'
  end

/* read and decode IEBCOPY member records */
skip = 1
do n = 1
  call read
  p = 9 /* skip BDW+RDW */
  if skip = 1
  then do
    cchhr = substr(data,p+4,5) /* CCHHR of this block */
    if cchhr = '0000000000'x
    then iterate
    ttr = ttr(cchhr)
    if (dir.ttr <> member) & (member <> '*')
    then iterate
    if dir.ttr = ''
    then iterate
    if member = '*'
    then name = dir.ttr
    else name = member
    target = rename
    target = changestr('%M%', target, name)
    rc = stream(target, 'c', 'open write replace')
    skip = 0
    dir.ttr = '' /* member extracted */
    end
  do while p < length(data)
    blklen = c2d(substr(data,p+10,2)) /* get length DD from original dasd count MBBCCHHRKDD */
    if blklen=0
    then leave /* end of current member */
    p = p+12 /* skip F+MBBCCHHRKDD */
    select
    when bitand(urecfm,'C0'x) = '80'x
    then do /* RECFM=F */
      do blklen%ulrecl
        call write target, substr(data,p,ulrecl)
        p = p+ulrecl
      end
      end
    when bitand(urecfm,'C0'x) = '40'x
    then do /* RECFM=V */
      ll = c2d(substr(data,p,2)) /* block size from BDW */
      p = p+4 /* skip BDW */
      do while p < length(data)
        l = c2d(substr(data,p,2)) /* record size from RDW */
        if l = 0
        then do
          blklen = 0
          leave
          end
        call write target, substr(data,p+4,l-4)
        p = p+l
      end
      end
    otherwise /* RECFM=U */
      call write target, substr(data,p)
    end
  end
  if blklen=0 /* end of current member */
  then do
    rc = stream(target, 'c', 'close')
    call msg '018I Member 'name' extracted to 'target
    if member = '*'
    then skip = 1
    else leave
    end
end

quit:
if source <> ''
then rc = stream(source, 'c', 'close')
exit

/* Calculate a relative TTR for an absolute CCHHR */
TTR: procedure expose deb. trkscyl
  parse arg cc +2 hh +2 r +1
  tt = c2d(cc)*trkscyl+c2d(hh)
  do i = 1 to deb.0
    parse var deb.i tt1 tt2 rel
    if (tt>=tt1) & (tt<=tt2)
    then leave
  end i
  return right(d2x(tt-tt1+rel)c2x(r),6,'0')

read:
  descriptor = charin(source,,8)
  if length(descriptor) <> 8
  then do
    if member <> '*'
    then call msg '015T File 'source' premature end of data'
    else signal quit
    end
  l = c2d(substr(descriptor,1,2))
  data = descriptor''charin(source,,l-8)
  if length(data) <> l
  then do
    if member <> '*'
    then call msg '015T File 'source' premature end of data'
    else signal quit
    end
  return  

write:
  if binary = 0
  then call lineout arg(1), ASCII(arg(2))
  else call charout arg(1), arg(2)
  if result <> 0
  then call msg '029T Error 'result' writing file' arg(1)
  return

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

/* REXX */
/*

Function:
         Restore member(s) from TRANSMIT unloaded data set.
         Here used a code written by Danal Estes for VM/CMS and
         code written by David Alcock.
         Completely rewritten by Gregori Bliznets using OOREXX
         to support TRANSMIT up to z/OS 2.4

Syntax:
         UNXMIT [-binary|-text] [-ascii codepage] [-ebcdic codepage] xmit [{member|*} [rename]] 

Usage:
         See unxmit.htm

(C) 2021-2023 Gregori Bliznets GregoryTwin@gmail.com
(C) 1990-1994 Danal Estes
(C) 1998 David Alcock

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
rename = ''
done = 0
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
if stream(source, 'c', 'query size') = 0 
then call msg '008T File "'source'" is empty'
parse upper var member member
name = '' /* new member */

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

/* Establish symbolic names for key fields */
inmddnam = '0001' /* ddname for file */
inmdsnam = '0002' /* dataset name (in pieces) */
inmmembr = '0003' /* member list */
inmsecnd = '000B' /* secondary spqce quantity */
inmdir   = '000C' /* directory spac quantity */
inmexpdt = '0022' /* exiration date */
inmterm  = '0028' /* mail file */
inmblksz = '0030' /* block size */
inmdsorg = '003C' /* data set organization */
inmlrecl = '0042' /* logical record length */
inmrecfm = '0049' /* record format */
inmtnode = '1001' /* target node name */
inmtuid  = '1002' /* target user id */
inmfnode = '1011' /* origin node */
inmfuid  = '1012' /* origin user id */
inmlref  = '1020' /* last reference date */
inmlchg  = '1021' /* last change date */
inmcreat = '1022' /* creation date */
inmfvers = '1023' /* origin version number */
inmftime = '1024' /* origin time stamp */
inmttime = '1025' /* destination time stamp */
inmfack  = '1026' /* acknowlegement request */
inmerrcd = '1027' /* receive error code */
inmutiln = '1028' /* name of utility program */
inmuserp = '1029' /* user parameter string */
inmrecct = '102A' /* transmitted record count */
inmsize  = '102C' /* file size in bytes */
inmnumf  = '102F' /* number of files in transmission */
inmtype  = '8012' /* data set type */

dir. = ''
dir.0 = 0
d = 0 /* data record count */
/* Read logical records, handle according to type */
do r = 1 /* INMR06 will cause exit */
  rec = read()
  flg = substr(rec,2,1)
  ctl = ASCII(substr(rec,3,6))
  c = (bitand(flg,'20'x) = '20'x)
  select
  when (r = 1) & (ctl <> 'INMR01')
  then call msg '011T Not an TSO XMIT format: wrong token 'c2x(substr(rec,3,6))
  when c & ctl = 'INMR06'
  then leave
  when c
  then call cntl
  when d = 0
  then do /* first data record */
    d = 1 
    /* change broken up dsn into one string */
    udsn = ''
    do i = 1 to 22
      if symbol('key.'inmdsnam'.'i) = 'LIT'
      then leave
      udsn = udsn'.'ASCII(key.inmdsnam.i)
    end
    udsn = substr(udsn,2)
    call msg '021I Data set 'udsn' from 'ASCII(Key.inmfuid.1)' at 'ASCII(Key.inmfnode.1)
    if bitand(key.inmdsorg.1,'0200'x) = '0200'x
    then do /* PDS[E] */ 
      if rename = ''
      then rename = '%D%(%M%)'
      if (member = '*') & (pos('%M%', translate(rename)) = 0)
      then call msg '009T Invalid rename pattern "'rename'"'
      end
    else do
      if rename = ''
      then rename = '%D%'
      if pos('%M%', translate(rename)) > 0
      then call msg '009T Invalid rename pattern "'rename'"'
      end
    select
    when ASCII(key.inmutiln.1) = 'IEBCOPY'
    then call iebcopy /* reads and understands IEBCOPY header recs */
    when ASCII(key.inmutiln.1) = 'INMCOPY'
    then call inmcopy
    otherwise
      call msg '011T Unknown program was used for transformation:' ASCII(key.inmutiln.1)
    end
    end
  otherwise
    if ASCII(key.inmutiln.1) = 'IEBCOPY'
    then call pds
    else call seq
  end
end r
if member <> '' & done = 0
then call msg '016T Member 'member' not found in 'udsn

quit:
exit 0

/* Process a control record */
cntl:
  if ctl = 'INMR02'
  then rec = delstr(rec,1,12)
  else rec = delstr(rec,1,8)
  /* loop and extract all keys from this record */
  do while length(rec) > 0
    c = c2d(substr(rec,3,2))
    p = 4
    do i = 1 to c
      p = p+2+c2d(substr(rec,p+1,2))
    end i
    k = left(rec,p) /* key */
    n = c2x(substr(k,1,2))
    c = c2d(substr(k,3,2))
    p = 5
    do i = 1 to c
      l = c2d(substr(k,p,2))
      p = p+2
      if symbol('key.'n'.'i) = 'LIT'
      then key.n.i = substr(k,p,l)
      p = p+l
    end i
    rec = delstr(rec,1,min(length(rec),length(k)))
  end
  return

/* Process PDS data record */
pds:
  if name = ''
  then do
    cchhr = substr(rec,7,5) /* cchhr of first data rec */
    ttr = ttr(cchhr)
    name = dir.ttr
    if name = ''
    then return
    skip = 1
    select
    when member = ''
    then call msg '020I Member' left(dir.ttr,8) 'TTR' ttr
    when (member <> '*') & (member <> name) 
    then skip = 1
    when dir.name = 1
    then skip = 2 /* attribute records */
    otherwise
      skip = 0
    end
    dir.name = 1
    end
  target = rename
  target = changestr('%D%', target, udsn)
  target = changestr('%M%', target, name)
  p = 3 /* skip IDTF length & flags */
  do while p < length(rec)
    blklen = c2d(substr(rec,p+10,2)) /* get length from original dasd count */
    if blklen=0
    then leave /* end of current member */
    p = p+12 /* skip count field */
    select
    when left(urecfm,1) = 'F'
    then do /* RECFM=F */
      do blklen%ulrecl
        if skip = 0
        then call write name, substr(rec,p,ulrecl)
        p = p+ulrecl
      end
      end
    when left(urecfm,1) = 'V'
    then do /* RECFM=V */
      ll = c2d(substr(rec,p,2)) /* block size from BDW */
      p = p+4 /* skip BDW */
      do while p < length(rec)
        l = c2d(substr(rec,p,2)) /* record size from RDW */
        if l = 0
        then do
          blklen = 0
          leave
          end
        if skip = 0
        then call write target, substr(rec,p+4,l-4)
        p = p+l
      end
      end
    otherwise /* RECFM=U */
      if skip = 0
      then call write target, substr(rec,p)
    end
  end
  if blklen = 0
  then do
    rc = stream(target, 'c', 'close')
    if skip = 0 
    then do
      call msg '018I Member 'name' extracted to 'target
      done = 1
      end
    name = ''
    end
  return

seq:
  target = rename
  target = changestr('%D%', target, udsn)
  p = 3 /* skip IDTF length & flags */
  select
  when left(urecfm,1) = 'F'
  then call write name, substr(rec,p,ulrecl) /* RECFM=F */
  when left(urecfm,1) = 'V'
  then do /* RECFM=V */
    ll = c2d(substr(rec,p,2)) /* block size from BDW */
    p = p+4 /* skip BDW */
    call write udsn, substr(rec,p,ulrecl)
    end
  otherwise /* RECFM=U */
    call write target, substr(rec,p)
  end
  return

inmcopy:
  udsorg = key.inmdsorg.1
  urecfm = left(key.inmrecfm.1,1)
  ulrecl = key.inmlrecl.1
  ublksz = key.inmblksz.1
  parse value attr(udsorg, urecfm, ublksz, ulrecl) with udsorg urecfm ublksize ulrecl 
  call msg '023I Original data set attributes: DSORG='udsorg',RECFM='urecfm',LRECL='ulrecl',BLKSIZE='ublksize
  call seq
  return

/* Handle IEBCOPY header records */
iebcopy:
  /* extract info from first IEBCOPY cntl record COPYR1 */
  flags = substr(rec,3,1)
  if substr(rec,4,3) <> 'CA6D0F'x
  then call msg '011T Not an unloaded IEBCOPY format: wrong token' substr(rec,4,3)
  select
  when bitand(flags,'C0'x) = '00'x
  then pdse = 0 /* valid PDS data set in old format */
  when bitand(flags,'C0'x) = '40'x
  then pdse = 1 /* valid PDSE data set in new format */
  when bitand(flags,'C0'x) = '80'x
  then call msg '012T Unloaded IEBCOPY data set incomplete or in error'
  otherwise
    call msg '013T Unknown unloaded IEBCOPY data set format'
  end
  parse var rec 7 udsorg +2 ublksz +2 ulrecl +2 urecfm +1 ,
                  ukeyln +1 uoptcd +1 udfsms +1 tblksz +2 ,
                  udevt +20 ncopyr +2
  if bitand(urecfm,'C0'x) = '00'x
  then call msg '014T Unsupported record format in original PDS/PDSE'
  parse value attr(udsorg, urecfm, ublksz, ulrecl) with udsorg urecfm ublksz ulrecl 
  call msg '023I Original data set attributes: DSORG='udsorg',RECFM='urecfm',LRECL='ulrecl',BLKSIZE='ublksz

  /* now read control record 2 COPYR2 */
  rec = read()
  p = 3 /* skip IDTF stuff */
  deb.0 = c2d(substr(rec,p,1)) /* number of extents in this DEB */
  p = p+16
  if pdse = 1
  then trkscyl = 256
  else trkscyl = c2d(substr(udevt,11,2))
  rel = 0
  do i = 1 to deb.0
    start = c2d(substr(rec,p+6,2))*trkscyl+c2d(substr(rec,p+8,2))
    end = c2d(substr(rec,p+10,2))*trkscyl+c2d(substr(rec,p+12,2))
    deb.i = start end rel
    rel = rel+end-start+1 /* adjust relative for next pass */
    p = p+16
  end i

  /* read and decode directory records */
  do forever
    rec = read()
    rec = substr(rec,3) /* discard IDTF stuff */
    c = length(rec)%276 /* 276=256+12 byte count+8 byte key */
    do i = 1 to c
      dirblock = substr(rec,1+(i-1)*276,276)
      p = 23 /* ignore count, key, 1st hwd */
      l = c2d(substr(dirblock,22,1))
      do while (p<l) & (substr(dirblock,p,8) <> copies('FF'x,8))
        ttr = c2x(substr(dirblock,p+8,3)) /* drop name in ttr indexed bucket */
        dir.ttr = strip(ASCII(substr(dirblock,p,8)))
        /* say 'Debug: name 'dir.ttr' TTR 'ttr */
        dir.0 = dir.0+1
        ul = c2d(bitand(substr(dirblock,p+11,1),'1F'x))
        p = p+12+ul*2
      end
    end i
    if substr(dirblock,13,8) = copies('FF'x,8)
    then leave /* last dir block */
  end
  return

/* Read a logical IDTF record */
read: procedure expose source
  l = charin(source,,1)
  f = charin(source,,1)
  rec = l''f''charin(source,,c2d(l)-2)
  do while bitand(f,'40'x) = '00'x /* end of segment yet? */
    l = charin(source,,1)
    f = charin(source,,1)
    rec = rec''charin(source,,c2d(l)-2)
  end
  return rec

write:
  if binary = 0
  then call lineout arg(1), ASCII(arg(2))
  else call charout arg(1), arg(2)
  if result <> 0
  then call msg '029T Error 'result' writing file' arg(1)
  return

/* Change a absolute volume CCHHR to a relative TTR */
TTR: procedure expose deb. trkscyl
  parse arg cc +2 hh +2 r +1
  tt = c2d(cc)*trkscyl+c2d(hh)
  do i = 1 to deb.0
    parse var deb.i tt1 tt2 rel
    if (tt>=tt1) & (tt<=tt2)
    then leave
  end i
  return right(d2x(tt-tt1+rel)c2x(r),6,'0')

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

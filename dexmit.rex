/* REXX */
/*

Function:
         Restore IEBCOPY unloaded data set from XMIT archieve.

Syntax:
         DEXMIT xmit

Usage:
         See dexmit.htm

(C) 2021-2023 Gregori Bliznets GregoryTwin@gmail.com

*/
trace off
parse arg args
opt = '-'
source = ''
udsn = ''
args = strip(args, 'L')
do while (args <> '' & left(args, 1) = opt)
  parse var args option args
  parse upper var option +1 keyword
  select
  when kwd = opt
  then leave /* Explicit fence */
  otherwise
    call msg '003T Invalid option "'Option'"'
  end
end
parse var args source target other 
if source = ''
then call msg '004T Source (XMIT) file was not specified'
if other <> ''
then call msg '006T Extraneous parameters: "'other'"'
if stream(source, 'c', 'query exists') = ''
then call msg '007T File "'source'" not found'
if stream(source, 'c', 'query size') = 0 
then call msg '008T File "'source'" is empty'

/* use internal translation table from code page 1025 to code page 1251 */
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

data = 0
nrec = 0
lrecl = 0

/* Read logical records, handle according to type */
do r = 1 /* INMR06 will cause exit */
  rec = read()
  flg = substr(rec,2,1)
  ctl = ASCII(substr(rec,3,6))
  if (substr(ctl,1,4) = 'INMR') & (bitand(flg,'20'x) = '20'x)
  then do /* control record */
    if (r = 1) & (ctl <> 'INMR01')
    then call msg '011T Not an TSO XMIT format: wrong token 'c2x(substr(rec,3,6))
    if ctl = 'INMR06'
    then leave
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
    end
  else do /* data record */
    if data = 0
    then do /* first data record - IEBCOPY COPYR1 record */
      /* change broken up dsn into one string */
      udsn = ''
      do i = 1 to 22
        if symbol('key.'inmdsnam'.'i) = 'LIT'
        then leave
        udsn = udsn'.'ASCII(key.inmdsnam.i)
      end
      udsn = substr(udsn,2)
      if target = ''
      then target = udsn
      rc = stream(target, 'c', 'open write replace')
      call msg '021I Data set 'udsn' from 'ASCII(Key.inmfuid.1)' at 'ASCII(Key.inmfnode.1)
      if ASCII(key.inmutiln.1) <> 'IEBCOPY'
      then call msg '011T Not an unloaded IEBCOPY format: wrong key' ASCII(key.inmutiln.1)
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
      parse var rec 7 udsorg +2 ublksz +2 ulrecl +2 urecfm +1 ukeyln +1 ,
                      uoptcd +1 udfsms +1 tblksz +2 udevt +20 ncopyr +2
      parse value attr(udsorg, urecfm, ublksz, ulrecl) with udsorg urecfm ublksize ulrecl 
      call msg '023I Original data set attributes: DSORG='udsorg',RECFM='urecfm',LRECL='ulrecl',BLKSIZE='ublksize
      bytes = c2d(key.INMSIZE.1)
      blks = bytes % ublksize + 1
      call msg '024I Original data set allocation: SPACE=(' || ublksize || ',(' || blks || ',' || blks%2 || ',' || c2d(key.INMDIR.1) || '))'
      data = 1
      end
    call write target, substr(rec,3)
    end
end
call msg '022I Unloaded data set attributes: DSORG=PS,RECFM=VS,LRECL=' || (lrecl+4) || ',BLKSIZE=' || (lrecl+8)
if c2d(tblksz) < lrecl+8
then do /* fix COPYR1 */
  p = stream(target, 'c', 'query position')
  call stream target, 'c', 'seek = 23 write char'
  call charout target, d2c(lrecl+8,2)
  if debug = 1
  then call msg '025D IEBCOPY COPYR1 record fixed:' c2d(tblksz) 'replaced to' lrecl+8
  call stream target, 'c', 'seek = 'p' write char'
  end
call msg '018I Data set 'target' extracted'

quit:
if source <> ''
then rc = stream(source, 'c', 'close')
if target <> ''
then rc = stream(target, 'c', 'close')
exit 0

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
  l = length(arg(2))
  nrec = nrec+1
  lrecl = max(lrecl,l)
  BDW = x2c(d2x(l+8,4)) || '0000'x
  RDW = x2c(d2x(l+4,4)) || '0000'x
  call charout arg(1), BDW || RDW || arg(2)
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

msg:
  say arg(1)
  if substr(arg(1),4,1) = 'T' /* message severity code */
  then signal quit
  return ''

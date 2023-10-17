/* Fullscreen XMIT archive browser in "filelist"-style */
/*

Function:
         Fullscreen browse XMIT archive content.

Syntax:
         XMITLIST [-ascii codepage] [-ebcdic codepage] xmitfile

Dependancy:
         THE (The Hessler Editor) is used to provide user interface

Usage:
         See xmitlist.htm

(C) 2023 Gregori Bliznets GregoryTwin@gmail.com

*/
trace off
xmitlist = 'XMITLIST 1.3'
nbyte = 0
nfile = 1
maxblksz = 0
lrecl = 0
/*
The following is a bit of kludge. Prinically, here should be several REXX
files rather than this single file - separate file for procedure, another
one for THE profile and separate file for each THE macro.  However, it is
possible to merge all together, using address() and parameters passed.
*/ 
if address() = 'THE'
then signal the /* We are called by THE */
cmd: /* We are called by shell (command interpreter) */
call rxfuncadd 'sysloadfuncs', 'rexxutil', 'sysloadfuncs'
call sysloadfuncs
parse arg args
/* don't check system environment, let suppose REXX and THE are here */
opt = '-'
xmitfile = ''
mapfile = ''
hlpfile = 'xmitlist.htm'
ebcdic = ''
ascii = ''
args = strip(args, 'L')
do while (args <> '' & left(args, 1) = opt)
  parse var args option args
  parse upper var option +1 keyword
  select
  when keyword = '?' | abbrev('HELP', keyword, 2)
  then do /* help requested */
    'start 'hlpfile /* that's OK for Windows, but for Unix we need another command */
    exit 0
    end
  when abbrev('EBCDIC', keyword, 1)
  then do
    parse var args ebcdic args
    if ebcdic = ''
    then call msg '002T Missed value of option "'option'"'
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
parse var args xmitfile other 
if xmitfile = ''
then call msg '004T XMIT file was not specified'
if other <> ''
then call msg '006T Extraneous parameters: "'other'"'
if stream(xmitfile, 'c', 'query exists') = ''
then call msg '007T XMIT file "'xmitfile'" not found'
total = stream(xmitfile, 'c', 'query size')
if total = 0 
then call msg '008T XMIT file "'xmitfile'" is empty'
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
mapfile = xmitfile'.map'
/* pass key data to THE profile and macro */
call value 'XMITXLT', c2x(xlate), 'ENVIRONMENT' 
call value 'XMITFILE', xmitfile, 'ENVIRONMENT'
call value 'XMITLIST', xmitlist, 'ENVIRONMENT'
'chcp 'ascii
cc = 0
rc = stream(mapfile, 'c', 'open write replace')

call proc ''

quit:
  if xmitfile <> ''
  then call stream xmitfile, 'c', 'close'
  if mapfile <> ''
  then call stream mapfile, 'c', 'close'
  if cc = 0 
  then do
    if ASCII(key.inmutiln.1) = 'IEBCOPY'
    then item = mapfile
    else item = target
    'the -a profile 'item
    'del 'item
    end
  exit 0

/* Read logical records, handle according to type */
proc:
  parse arg target, mode
  parse var target dsname '(' member ')'
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
  inmftime = '1024' /* origin time */
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

  rc = stream(xmitfile, 'c', 'open read')
  dir. = ''
  dir.0 = 0
  name = ''
  d = 0 /* data record count */
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
      end i
      udsn = substr(udsn,2)
      /* call msg '021I Data set 'udsn' from 'ASCII(Key.inmfuid.1)' at 'ASCII(Key.inmfnode.1) */
      select
      when ASCII(key.inmutiln.1) = 'IEBCOPY'
      then call iebcopy /* reads and understands IEBCOPY header recs */
      when ASCII(key.inmutiln.1) = 'INMCOPY'
      then call inmcopy
      otherwise
        call msg '011T Unknown program was used for transformation:' ASCII(key.inmutiln.1)
      end
      title = udsn','udsorg','ASCII(Key.inmfuid.1)'.'ASCII(Key.inmfnode.1)
      call value 'XMITITLE', title, 'ENVIRONMENT'
      end
    otherwise
      if ASCII(key.inmutiln.1) = 'IEBCOPY'
      then call pds
      else call seq
    end
  end r
  return

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
    when member <> name 
    then skip = 1
    when dir.name = 1
    then skip = 2 /* attribute records */
    otherwise
      skip = 0
    end
    dir.name = 1
    end
  p = 3 /* skip IDTF length & flags */
  target = udsn'('name')'
  do while p < length(rec)
    blklen = c2d(substr(rec,p+10,2)) /* get length from original dasd count */
    if blklen=0
    then leave /* end of current member */
    p = p+12 /* skip count field */
    select
    when bitand(urecfm,'C0'x) = '80'x
    then do /* RECFM=F */
      do blklen%ulrecl
        if skip = 0
        then call write target, substr(rec,p,ulrecl)
        p = p+ulrecl
      end
      end
    when bitand(urecfm,'C0'x) = '40'x
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
    name = ''
    end
  return

seq:
  p = 3 /* skip IDTF length & flags */
  mode = 'TEXT'
  select
  when left(urecfm,1) = 'F'
  then call write target, substr(rec,p,ulrecl) /* RECFM=F */
  when left(urecfm,1) = 'V'
  then do /* RECFM=V */
    ll = c2d(substr(rec,p,2)) /* block size from BDW */
    p = p+4 /* skip BDW */
    call write target, substr(rec,p,ulrecl)
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
  parse value attr(udsorg, urecfm, ublksz, ulrecl) with udsorg urecfm ublksz ulrecl 
  target = udsn
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
  ublksz = c2d(ublksz)
  ulrecl = c2d(ulrecl)
  urecfm = bitand(urecfm,'C0'x)
  if urecfm = '00'x
  then call msg '014T Unsupported record format in original PDS/PDSE'

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
    end = c2d(Substr(rec,p+10,2))*trkscyl+c2d(Substr(rec,p+12,2))
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
        call lineout mapfile, left(dir.ttr,8) right(ttr,6)
        ul = c2d(bitand(substr(dirblock,p+11,1),'1F'x))
        p = p+12+ul*2
      end
    end i
    if substr(dirblock,13,8) = copies('FF'x,8)
    then leave /* last dir block */
  end
  return

/* Read a logical IDTF record */
read: procedure expose xmitfile
  l = charin(xmitfile,,1)
  f = charin(xmitfile,,1)
  rec = l''f''charin(xmitfile,,c2d(l)-2)
  do while bitand(f,'40'x) = '00'x /* end of segment yet? */
    l = charin(xmitfile,,1)
    f = charin(xmitfile,,1)
    rec = rec''charin(xmitfile,,c2d(l)-2)
  end
  return rec

write:
  if translate(mode) = 'TEXT'
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

the: /* We are inside THE and called as a profile or macro */
  parse arg action parms
  action = translate(action) 
  xmitlist = value('XMITLIST', ,'ENVIRONMENT')
  xmitfile = value('XMITFILE', ,'ENVIRONMENT')
  mapfile = xmitfile'.map'
  xlate = x2c(value('XMITXLT', ,'ENVIRONMENT'))
  title = value('XMITITLE', ,'ENVIRONMENT')
  parse var title dsname ',' dsorg ',' source
  if action = 'PROFILE'
  then signal profile
  if action = 'CMDLINE'
  then do
    'extract /cmdline/'
    if cmdline.1 = 'OFF'
    then 'set cmdline bottom'
    else 'set cmdline off'
    exit 0
    end
  'sos makecurr'
  if \modifiable()
  then do
    'emsg Invalid cursor position'
    exit 1
    end
  'extract /fname/fext/'
  'extract /curline/'
  if left(curline.3, 4) = ' ***'
  then do
    'emsg Invalid cursor position'
    exit 1
    end
  select
  when pos('(',fname.1) = 0
  then do
    parse var curline.3 member ttr
    name = dsname'('member')'
    select
    when action = 'BROWSE'
    then call browse name
    when action = 'KEEP'
    then call keep name, parms
    otherwise
      'emsg Invalid action 'action
    end
    end
  otherwise nop
  end
  return

browse:
  'msg Please wait...'
  parse arg item
  rc = stream(item, 'c', 'open write replace')
  call proc item, 'text'
  rc = stream(item, 'c', 'close')
  'x 'item
  return

keep:
  'msg Please wait...'
  parse arg item, mode
  rc = stream(item, 'c', 'open write replace')
  call proc item, mode
  rc = stream(item, 'c', 'close')
  'msg 'item' kept as 'mode
  return

profile:
  'set compat xedit xedit xedit'
  'set statusline off'
  'set msgline on 2'
  'set msgline clear'
  'set cmdline off'
  'set scale off'
  'set tofeof off'
  'set prefix nulls left 6 1'
  'set prefix off'
  'set macroext rex'
  'set reprofile on'
  'set curline on 4'
  'set color curline green on black'
  'set color cursorline black on green'
  'set ctlchar ! escape'
  'set ctlchar [ protect yellow on black'
  'set ctlchar ] protect green on black'
  'set readonly on'
  'set statusline off'
  'set idline off'
  'set linend off ;'
  'extract /fname/fext/'
  'editv get title'
  'editv get xmitline'
  parse var xmitline member ttr
  if pos('(', fname.1'.'fext.1) = 0
  then name = dsname
  else name = fname.1'.'fext.1
  c = max(length(xmitlist),length(xmitfile))
  'set reserved 2 'copies(' ',80)'.'
  'define F2 macro xmitlist.rex cmdline'
  'define F3 qquit'
  'define F12 ccancel'
  ':1'
  if pos('(', name) = 0 & dsorg <> 'PS'
  then do
    title = left(xmitlist,c)''center(name,80-c-c)''right(xmitfile,c)
    'define F10 macro xmitlist.rex browse'
    'define A-F10 macro xmitlist.rex keep text'
    'define C-F10 macro xmitlist.rex keep binary'
    'set reserved 3 Member   TTR'
    'set reserved -1 ![ F1=help  F2=cmdline  F3=quit  F7=backward  F8=forward  F10=browse  F12=cancel!]'
    end
  else do /* inside member or sequential data set */
    title = left(xmitlist,c)''center(name,80-c-c)''right(xmitfile,c)
    'set curline on 3'
    'set reserved -1 ![ F1=help  F2=cmdline  F3=quit  F7=backward  F8=forward              F12=cancel'
    'verify 1 80'
    end
  'set reserved 1 !['title
  'sos current'
  exit

ASCII:
  return translate(arg(1), xlate)

EBCDIC: /* currently unused */
  return translate(arg(1), xrange('00'x, 'FF'x), xlate)

msg:
  say arg(1)
  if substr(arg(1),4,1) = 'T' /* message severity code */
  then signal quit
  return ''

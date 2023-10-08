/* Fullscreen AWS tape browser "filelist"-style */
/*

Function:
         Fullscreen browse AWS tape content.

Syntax:
         AWSLIST [-batch] [-blp] [-ascii codepage] [-ebcdic codepage] awsfile

Dependancy:
         THE (The Hessler Editor) is used to provide user interface

Usage:
         See awslist.htm

(C) 2022-2023 Gregori Bliznets GregoryTwin@gmail.com

*/
trace off
awslist = 'AWSLIST 1.4'
nbyte = 0
nfile = 1
nblks = 0
maxblksz = 0
blp = 0
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
batch = 0
opt = '-'
awsfile = ''
mapfile = ''
hlpfile = 'awslist.htm'
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
  when abbrev('BATCH', keyword, 2)
  then batch = 1
  when abbrev('BLP', keyword, 2)
  then blp = 1
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
parse var args awsfile other 
if awsfile = ''
then call msg '004T AWS file was not specified'
if other <> ''
then call msg '006T Extraneous parameters: "'other'"'
if stream(awsfile, 'c', 'query exists') = ''
then call msg '007T AWS file "'awsfile'" not found'
total = stream(awsfile, 'c', 'query size')
if total = 0 
then call msg '008T AWS file "'awsfile'" is empty'

/* Please see https://docs.microsoft.com/en-us/windows/win32/intl/code-page-identifiers for valid codepage identifiers */
/* Especially CP 20880 IBM 880, EBCDIC Cyrillic, CP 1251 ANSI Cyrillic */
select
when ebcdic = '' & ascii = ''
then do /* use internal translation table from code page 1025 to code page 866 */
  xlate = '00010203EC09D37FDAC2E50B0C0D0E0F'x ,
       || '10111213ABAA0891181998001C1D1E1F'x ,
       || '948390A98F0A171B8492958081050607'x ,
       || '9D8A168C8B999C04899B9EAF1415F71A'x ,
       || '20000000F1F300F9F5005B2E3C282B21'x ,
       || '2600000000F7009A00005D242A293B5E'x ,
       || '2D2F00F0F200F8F400007C2C255F3E3F'x ,
       || '00000000F600EEA0A1603A2340273D22'x ,
       || 'E6616263646566676869A4A5E4A3E5A8'x ,
       || 'A96A6B6C6D6E6F707172AAABACADAEAF'x ,
       || 'EF7E737475767778797AE0E1E2E3A6A2'x ,
       || 'ECEBA7E8EDE9E7EA9E80819684859483'x ,
       || '7B4142434445464748499588898A8B8C'x ,
       || '7D4A4B4C4D4E4F5051528D8E8F9F9091'x ,
       || '5C00535455565758595A929386829C9B'x ,
       || '3031323334353637383987989D99971A'x
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

/* pass key data to THE profile and macro */
call value 'AWSXLT', c2x(xlate), 'ENVIRONMENT' 
call value 'AWSFILE', awsfile, 'ENVIRONMENT'
call value 'AWSLIST', awslist, 'ENVIRONMENT'
'chcp 'ascii
call spell
mapfile = awsfile'.map'
cc = 0
rc = stream(mapfile, 'c', 'open write replace')
if blp = 1
then label = 'BLP'
else label = label()
call value 'label', label, 'ENVIRONMENT'
eof = 0 /* end of file, tape mark detected after data */ 
eot = 0 /* logical end of tape, tape mark detected after tape mark */
do forever
  rc = read()
  /* show progress indicator */
  percent = (nbyte * 100) % total
  call charout , '0d'x || 'Please wait 'percent'% complete' || '0d'x
  select
  when rc = 0
  then do /* some data */
    eof = 0
    nblks = nblks + 1
    if (left(label,2) = 'SL') & (eot = 0) 
    then do
      select
      when (nfile // 3) = 1
      then do /* Process header labels (HDR1, HDR2, HDR3-HDR9, UHL1-UHL9) */
        data = ASCII(data)
        select
        when nblks = 1
        then do /* HDR1 */
          parse var data hdr1labi +4 hdr1id +17 hdr1filsr +6 hdr1volsq +4 hdr1filsq +4 hdr1gno +4 hdr1vng +3 hdr1credt +5 hdr1expdt +6 hdr1fsec +1 hdr1blkct  +6 hdr1syscd .
          if hdr1labi <> 'HDR1'
          then call msg '010E Tape file 'nfile' block 'nblks': HDR1 expected 'hdr1labi' found'
          end 
        when nblks = 2
        then do /* HDR2 */
          parse var data hdr2labi +4 hdr2recfm +1 hdr2blkl +5 hdr2lrecl +5 hdr2den +1 hdr2filp +1 hdr2jobd +8 . +1 hdr2stepd +8 hdr2trtch +2 hdr2cntrl +1 . +1 hdr2blka +1 . +1 . +2 hdr2id +5 . +13 hdr2owner +20
          if hdr2labi <> 'HDR2'
          then call msg '010E Tape file 'nfile' block 'nblks': HDR2 expected 'hdr2labi' found'
          if hdr2blka = 'R'
          then hdr2blka = 'BS'
          if hdr2blka = ' '
          then hdr2blka = ''
          recfm = hdr2recfm || hdr2blka || hdr2cntrl
          end
        when nblks > 2
        then nop /* Extra data set labels HDR3-HDR9, user labels UHL1-UHL9, just ignore */
        end
        iterate
        end
      when (nfile // 3) = 0
      then do /* Process trailer labels (EOF1-EOF9, EOV1-EOV9, UTL1-UTL9 */
        data = ASCII(data)
        select
        when nblks = 1
        then do /* EOF1/EOV1 */
          parse var data trl1labi +4 trl1id +17 trl1filsr +6 trl1volsq +4 trl1filsq +4 trl1gno +4 trl1vng +3 trl1credt +5 trl1expdt +6 trl1fsec +1 trl1blkct  +6 trl1syscd .
          if trl1labi <> 'EOF1' & trl1labi <> 'EOV1'
          then call msg '010E Tape file 'nfile' block 'nblks': EOF1/EOV1 expected, 'trl1labi' found'
          end
        when nblks = 2
        then do /* EOF2/EOV2 */
          parse var data trl2labi +4 trl2recfm +1 trl2blkl +5 trl2lrecl +5 trl2den +1 trl2filp +1 trl2jobd +8 . +1 trl2stepd +8 trl2trtch +2 trl2cntrl +1 . +1 trl2blka +1 . +1 . +2 trl2id +5 . +13 trl2owner +20
          if trl2labi <> 'EOF2' & fl1labi <> 'EOV2'
          then call msg '010E Tape file 'nfile' block 'nblks': EOF2/EOV2 expected, 'trl2labi' found'
          end
        when nblks > 2
        then nop /* Extra data set labels EOF3-EOF9, user labels UTL1-UTL9, just ignore */
        end
        iterate
        end
      otherwise nop /* data file */
      end
      end
    /* data block */
    blksz = length(data)
    maxblksz = max(maxblksz, blksz)
    if nblks = 1
    then do /* first data block, recognize special formats */
      what = ''
      do i = 1 to spell.0 until what <> ''
        parse var spell.i id ',' pgm ',' loc ',' token 
        if substr(data, loc, length(token)) = token
        then what = pgm
      end i
      if what = '' & pos('A', recfm) > 1
      then what = 'WTR' 
      lrecl = maxblksz
      end
    /* Guess lrecl for unlabelled tape */
    if label = 'NL' & lrecl > 1
    then lrecl = gcd(lrecl, blksz)
    end
  when rc = -2
  then leave /* end of tape */
  when eof = 1
  then do /* two consequtive TM */
    eot = 1 /* logical end of tape */
    call lineout mapfile, left(' *** LOGICAL END OF TAPE ***',80)
    end
  otherwise /* TM found */
    eof = 1
    nblks = nblks + 1
    if left(label,2) = 'SL'
    then do
      lfile = nfile%3 + nfile//3 - 1
      dsname = hdr1id
      lrecl = hdr2lrecl
      blksz = hdr2blkl
      credt = ddmmyyyy(hdr1credt)
      end
    else do
      recfm = ''
      select
      when what = 'IEBCOPY'
      then do
        recfm = 'VBS'
        lrecl = maxblksz - 4
        end
      when what = 'IEHMOVE'
      then do
        recfm = 'FB'
        lrecl = 80
        end
      when what = 'VMFPLC2'
      then do
        recfm = 'U'
        lrecl = ''
        end
      otherwise
        if lrecl > 5
        then recfm = 'FB'
        else do
          recfm = 'U'
          lrecl = ''
          end 
      end
      lfile = nfile
      dsname = ''
      blksz = maxblksz
      credt = ''
      end
    b = (left(label,2) = 'SL') + 1 /* 1 for NL, 2 for SL */
    if (batch = 1) & (nfile = b)
    then do /* write title in batch mode */
      b = max(length(awslist),length(label)) 
      call lineout mapfile, left(awslist,b)''center(mapfile,80-b-b)''right(label,b)
      call lineout mapfile, ' '
      call lineout mapfile, ' File  Block Name              Recfm Lrecl Blksize Created    Content'
      end
    select
    when (left(label,2) <> 'SL') & nblks = 1
    then call lineout mapfile, left(' *** TAPE MARK ***',80)
    when ((left(label,2) = 'SL') & ((nfile // 3) <> 2))
    then nop
    otherwise
      call lineout mapfile, right(lfile,5) right(nblks,6) left(dsname,17) left(recfm,3) right(lrecl,7) right(blksz,7) left(credt,10) left(what,17)
    end
    if (left(label,2) = 'SL') & (eot = 0)
    then do /* Check for missed labels */
      select
      when ((nfile // 3) = 1) & (nblks = 1)
      then call msg '010E Tape file 'nfile' block 'nblks': HDR1 expected, TM found' 
      when ((nfile // 3) = 1) & (nblks = 2)
      then do
        if hdr1id = copies('00'x,17)
        then call msg '013E Empty SL tape (after IEHINITT/AWSINIT), volume label' substr(label,4) ''
        call msg '010E Tape file 'nfile' block 'nblks': HDR2 expected, TM found'
        end
      when ((nfile // 3) = 0) & (nblks = 1)
      then call msg '010E Tape file 'nfile' block 'nblks': EOF1/EOV1 expected, TM found' 
      when ((nfile // 3) = 0) & (nblks = 2)
      then call msg '010E Tape file 'nfile' block 'nblks': EOF2/EOV2 expected, TM found'
      otherwise nop
      end
      end
    nfile = nfile+1
    nblks = 0
    maxblksz = 0
    data = ''
  end
end /* do until eod = 1 */
cc = 0

Quit:
  if awsfile <> ''
  then call stream awsfile, 'c', 'close'
  if mapfile <> ''
  then call stream mapfile, 'c', 'close'
  if cc = 0 & batch = 0
  then 'the -a profile 'mapfile
  exit 0

/* convert date from yyddd to dd.mm.yyyy */
ddmmyyyy: procedure
  parse arg yyddd .
  if yyddd = '' | yyddd = '0000000000'x
  then return copies(' ',10)
  parse var yyddd yy +2 ddd +3
  if yy > 50 /* century window: 1951-1999 */
  then yyyy = '19'yy
  else yyyy = '20'right(yy,2,'0')
  if ((yyyy//4=0 & yyyy//100<>0) | yyyy//400=0)
  then dm = '29' /* leap year */
  else dm = '28'
  dm = '31 'dm' 31 30 31 30 31 31 30 31 30 31'
  d = 0
  do i = 1 by 1 until d > ddd
    d = d + word(dm,i)
  end i
  return right(ddd-d+word(dm,i),2,0)'.'right(i,2,0)'.'yyyy

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
      p = stream(awsfile, 'c', 'query position read')
      do until rc <> 0
        rc = read()
        if rc <> 0
        then leave
        data = ASCII(data)
        if left(data,3) <> 'VOL'
        then leave
        p = stream(awsfile, 'c', 'query position read')
      end
      call stream awsfile, 'c', 'seek 'p' read'
      end
    end
  if label = 'NL'
  then call stream awsfile, 'c', 'seek 1 read'
  /* for SL leave tape after volume label(s), before HDR1 */
  return label

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

/* tape positioning */
seek:
  parse arg n /* logical file */
  rc = 0
  call stream awsfile, 'c', 'seek =1 read'
  if left(label,2) = 'SL'
  then n = 3*(n-1)+1
  else n = n-1
  if n = 0
  then return
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
  return rc

/* magical spells :) */
spell:
  /* enumerated array */
  i=0
  i=i+1; spell.i = 'IEBCP,IEBCOPY,10,' || 'CA6D0F'x;
  i=i+1; spell.i = 'IEHMV,IEHMOVE,6,' || 'E3C8C9E240C9E240C1D540E4D5D3D6C1C4C5C4'x; /* THIS IS AN UNLOADED */
  i=i+1; spell.i = 'PLCH,VMFPLC2,1,' || '02D7D3C3C8'x; /* .PLCH */
  i=i+1; spell.i = 'PLCD,VMFPLC2,1,' || '02D7D3C3C4'x; /* .PLCD */
  i=i+1; spell.i = 'RDR,RDR,1,' || '6161'x; /* // */
  i=i+1; spell.i = 'UPDT,IEBUPDTE,1,' || '4B61'x; /* ./ */
  i=i+1; spell.i = 'ESD,IEWL,1,' || '02C5E2C4'x; /* .ESD */
  i=i+1; spell.i = 'RLD,IEWL,1,' || '02D9D3C4'x; /* .RLD */
  i=i+1; spell.i = 'TXT,IEWL,1,' || '02E3E7E3'x; /* .TXT */
  i=i+1; spell.i = 'DMPRS,IBCDMPRS,13,' || 'F47006016663B24D'x;
  i=i+1; spell.i = 'DASDR,IEHDASDR,13,' || 'F4701D16FB63B24D'x;
  i=i+1; spell.i = 'DASDX,DASDR-5133,13,' || 'F470C4D9E263B24D'x;
  i=i+1; spell.i = 'FOLKF,DSF-4.2,16,' || 'C6D6D3D2C6'x; /* FOLKF */
  i=i+1; spell.i = 'FOLKS,FDR-4.5,16,' || 'C6D6D3D2E2'x; /* FOLKS */
  i=i+1; spell.i = 'THATS,FDR-4.5,6,' || 'E3C8C1E3E240C1D3D340C6D6D3D2'x; /* THATS ALL FOLK */
  i=i+1; spell.i = 'VHR,DDR,1,' || 'E5C8D9'x; /* VHR */
  i=i+1; spell.i = 'THR,DDR,1,' || 'E3C8D9'x; /* THR */
  i=i+1; spell.i = 'EOJ,DDR,1,' || 'C5D6D1'x; /* EOJ */
  i=i+1; spell.i = 'CMSN,CMS TAPE,1,' || '02C3D4E2D5'x; /* .CMS */
  i=i+1; spell.i = 'PTSN,PTS TAPE,1,' || '02D7E3E2D5'x; /* .PTS */
  i=i+1; spell.i = 'CMSF,CMS TAPE,1,' || '02C3D4E2C6'x; /* .CMS */
  i=i+1; spell.i = 'PTSF,PTS TAPE,1,' || '02D7E3E2C6'x; /* .PTS */
  i=i+1; spell.i = 'CMSV,CMS TAPE,1,' || '02C3D4E2E5'x; /* .CMS */
  i=i+1; spell.i = 'PTSV,PTS TAPE,1,' || '02D7E3E2E5'x; /* .PTS */
  i=i+1; spell.i = 'VOL1,TAPE LABELS,1,' || 'E5D6D3F1'x; /* VOL1 */
  i=i+1; spell.i = 'HDR1,TAPE LABELS,1,' || 'C8C4D9F1'x; /* HDR1 */
  i=i+1; spell.i = 'EOF1,TAPE LABELS,1,' || 'C5D6C6F1'x; /* EOF1 */
  i=i+1; spell.i = 'EOV1,TAPE LABELS,1,' || 'C5D6E5F1'x; /* EOV1 */
  spell.0 = i
  /* associative array */
  do i = 1 to spell.0
    parse var spell.i id ',' . ',' . ',' token
    spell.id = token
  end i
  return

ASCII:
  return translate(arg(1), xlate)

EBCDIC: /* currently unused */
  return translate(arg(1), xrange('00'x, 'FF'x), xlate)

the: /* We are inside THE and called as a profile or macro */
  parse arg action parms
  action = translate(action) 
  awslist = value('AWSLIST', ,'ENVIRONMENT')
  awsfile = value('AWSFILE', ,'ENVIRONMENT')
  xlate = x2c(value('AWSXLT', ,'ENVIRONMENT'))
  label = value('label', ,'ENVIRONMENT')
  call spell /* Reinitialize global data */
  'editv set label 'label
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
  'extract /line/'
  if left(curline.3, 4) = ' ***'
  then do
    'emsg Invalid cursor position'
    exit 1
    end
  select
  when fext.1 = 'map'
  then do
    /* use positional parse because some field may be blank for NL tape */
    parse var curline.3 1 file 6 7 blks 13 14 name 31 32 recfm 35 38 lrecl 43 46 blksize 51 52 credt 62 63 what 80
    call seek file
    'editv setl awsline 'curline.3
    name = strip(name)
    if name = ''
    then name = 'File.'strip(file)
    select
    when action = 'BROWSE'
    then do
      select
      when what = 'IEBCOPY'
      then call iebcopy_directory name
      when what = 'IEHMOVE'
      then call iehmove_directory name
      when what = 'VMFPLC2'
      then call vmfplc2_directory
      when what = 'CMS TAPE'
      then call cmstape_directory 
      when what = 'PTS TAPE'
      then call cmstape_directory
      otherwise
        call browse name
      end
      end
    when action = 'WRITE'
    then call write name
    otherwise
      'emsg Invalid action 'action
    end
    end
  when fext.1 = 'directory'
  then do
    'editv get awsline'
    parse var awsline 1 file 6 7 blks 13 14 name 31 32 recfm 35 38 lrecl 43 46 blksize 51 52 credt 62 63 what 80
    call seek file
    name = strip(name)
    if name = ''
    then name = 'File.'strip(file)
    if action = 'BROWSE'
    then do
      select
      when what = 'IEBCOPY'
      then call iebcopy_member
      when what = 'IEHMOVE'
      then call iehmove_member
      when what = 'VMFPLC2'
      then call vmfplc2_file
      when what = 'CMS TAPE'
      then call cmstape_file
      when what = 'PTS TAPE'
      then call cmstape_file
      otherwise nop
      end
      end
    end
  otherwise nop
  end
  return

browse:
  'msg Please wait...'
  parse arg name
  name = name'.data'
  rc = stream(name, 'c', 'open write replace')
  do forever
    rc = read()
    if rc <> 0
    then leave
    select
    when left(recfm,1) = 'F'
    then do
      if left(recfm,2) = 'FB'
      then do
        l = lrecl+1  
        do while data <> ""
          parse var data record =(l) data
          call ASA ASCII(record)
        end
        end
      else call ASA ASCII(data)
      end
    when left(recfm,1) = 'V'
    then do
      parse var data BDW +2 . +2 data
      if left(recfm,2) = 'VB'
      then do
        do while data <> ""
          parse var data RDW +2 . +2 data
          L = c2d(RDW)-3
          parse var data record =(L) data
          call ASA ASCII(record)
        end
        end
      else call ASA ASCII(data)
      end
    otherwise /* U */
      call lineout name, ASCII(data)
    end
  end
  rc = stream(name, 'c', 'close')
  'x 'name
  return

/* interpret ASA print control character */
ASA:
  parse arg record
  if pos('A', recfm) > 0 /* FB,FBA,VB,VBA */
  then do
    parse var record cc +1 record
    select
    when cc = '1'
    then nop /* new page, ignore for browsing */
    when cc = '+'
    then return /* overlay, just skip this line */
    when cc = '-'
    then call lineout name, copies(' ', lrecl) /* extra space */
    otherwise nop
    end
    end
  call lineout name, record
  return


/* Handle IEBCOPY unloaded data set */
iebcopy_directory:
  'msg Please wait...'
  parse arg name
  name = name'.directory'
  rc = stream(name, 'c', 'open write replace')
  call iebcopy_r1
  call iebcopy_r2
  call iebcopy_dir
  do i = 1 to ttr.0
    ttr = ttr.i
    call lineout name, left(dir.ttr,8) ttr /* Append with CRLF */
  end i
  rc = stream(name, 'c', 'close')
  'x 'name
  return

/* decode IEBCOPY cntl record COPYR1 */
iebcopy_r1:
  rc = read()
  flags = substr(data,9,1)
  if substr(data,10,3) <> 'CA6D0F'x;
  then do
    'emsg Not an unloaded IEBCOPY format 'c2x(substr(data,10,3))
    signal quit
    end
  select
  when bitand(flags,'C0'x) = '00'x
  then pdse = 0 /* valid PDS data set */
  when bitand(flags,'C0'x) = '40'x
  then pdse = 1 /* valid PDSE data set */
  when bitand(flags,'C0'x) = '80'x
  then do
    'emsg Unloaded data set incomplete or in error'
    signal quit
    end
  otherwise
    'emsg Unknown unloaded data set format'
    signal quit
  end
  parse var data 13 udsorg +2 ublksz +2 ulrecl +2 urecfm +1 ukeyln +1 ,
                    uoptcd +1 udfsms +1 tblksz +2 udevt +20 ncopyr +2
  ublksz = c2d(ublksz)
  ulrecl = c2d(ulrecl)
  urecfm = bitand(urecfm,'C0'x)
  if urecfm = '00'x
  then do
    'emsg Unsupported record format in original PDS/PDSE'
    signal quit
    end
  return

/* decode IEBCOPY cntl record COPYR2 */
iebcopy_r2:
  rc = read()
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
  return

/* read and decode IEBCOPY directory records */
iebcopy_dir:
  drop dir. ttr.
  dir. = ''
  ttr.0 = 0
  do n = 1
    rc = read()
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
        ul = c2d(bitand(substr(dirblock,p+11,1),'1F'x))
        p = p+8+3+1+ul*2
      end
    end 
  end n
  return

iebcopy_member:
  'msg Please wait...'
  parse var curline.3 member ttr .
  name = name'('member').data'
  rc = stream(name, 'c', 'open write replace')
  buffer = ''

  call iebcopy_r1
  call iebcopy_r2
  call iebcopy_dir

  /* process data records */
  skip = 1
  do forever
    rc = read()
    p = 9 /* skip BDW+RDW */
    if skip = 1
    then do
      cchhr = substr(data,p+4,5) /* CCHHR of this block */
      if cchhr = '0000000000'x
      then iterate
      ttr = ttr(cchhr)
      if dir.ttr <> member
      then iterate
      skip = 0
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
          call lineout name, ASCII(substr(data,p,ulrecl))
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
          call lineout name, ASCII(substr(data,p+4,l-4))
          p = p+l
        end
        end
      otherwise /* RECFM=U */
        call lineout name, ASCII(substr(data,p))
      end
    end
    if blklen=0
    then leave /* end of current member */
  end
  rc = stream(name, 'c', 'close')
  'x 'name
  return

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

/* Handle IEHMOVE unloaded data set */
iehmove_directory:
  'msg Please wait...'
  parse arg name
  name = name'.directory'
  rc = stream(name, 'c', 'open write replace')
  data = ''
  buffer = ''
  call getblock /* 1st block IEHMOVE id */
  l = length(spell.iehmv)
  if left(block, l) <> spell.iehmv
  then do
    'emsg Not an unloaded IEHMOVE format 'c2x(left(block, 20))
    signal quit
    end
  call getblock /* 2nd block DSCB F1 */
  parse var block udsn +44 . +1 uvol +6 . +31 udsorg +1 . +1 urecfm +1 . +1 ublksz +2 ulrecl +2 ukeylen +2 143 flags +1
  udsn = strip(ASCII(udsn))
  uvol = ASCII(uvol)
  ulrecl = c2d(ulrecl)
  ublksz = c2d(ublksz)
  select
  when bitand(udsorg, 'FE'x) = '02'x
  then udsorg = 'PO'
  when bitand(udsorg, 'FE'x) = '20'x
  then udsorg = 'DA'
  when bitand(udsorg, 'FE'x) = '40'x
  then udsorg = 'PS'
  otherwise udsorg = 'UN'
  end
  recfm = ''
  select
  when bitand(urecfm, 'C0'X) = 'C0'X
  then recfm = 'U'
  when bitand(urecfm, '80'X) = '80'X
  then recfm = 'F'
  when bitand(urecfm, '40'X) = '40'X
  then recfm = 'V'
  otherwise Frecfm = '0'
  end
  if bitand(urecfm, '10'X) = '10'X
  then recfm = recfm'B'
  if udsorg <> 'PO'
  then do
    'emsg Unloaded data set DSORG 'udsorg
    signal quit
    end
  do forever
    call getblock
    select
    when bitand(I, '08'X) = '08'X
    then call lineout name, left(ASCII(block), 8) c2x(TTR)
    when bitand(I, '01'X) = '01'X
    then leave /* pseudo EOF */
    otherwise nop
    end
  end
  rc = stream(name, 'c', 'close')
  'x 'name
  return

iehmove_member:
  'msg Please wait...'
  parse var curline.3 member ttr .
  name = name'('member').data'
  rc = stream(name, 'c', 'open write replace')
  buffer = ''
  call getblock /* 1st block IEHMOVE id */
  call getblock /* 2nd block DSCB F1 */
  direntry = ''
  this = 0
  do forever
    call getblock
    select
    when bitand(I, '08'X) = '08'X
    then do
      if member = left(ASCII(block), 8)
      then this = 1
      else this = 0
      end
    when (bitand(I, '60'X) <> '00'X) & this
    then do
      select
      when recfm = 'FB'
      then do
        L=LRECL+1
        do while block <> ''
          parse var block record =(L) block
          call lineout name, ASCII(record)
        end
        end
      when recfm = 'VB'
      then do
        parse var block BDW +2 . +2 block
        do while block <> ""
          parse var block RDW +2 . +2 block
          L = c2d(RDW)-3
          parse var block record =(L) block
          call lineout name, ASCII(record)
        end
        end
      when recfm = 'V'
      then do
        parse var block BDW +2 .+2 block
        call lineout name, ASCII(block)
        end
      otherwise /* recfm = F or recfm = U */
        call lineout name, ASCII(block)
      end
      end
    when bitand(I, '01'X) = '01'X
    then leave /* Pseudî EOF */
    otherwise nop /* notelists, dummy record etc. */
    end
  end
  rc = stream(name, 'c', 'close')
  'x 'name
  return

/* rebuild original data block from IEHMOVE unloaded card images */
getblock:
  block = ''
  if length(buffer) < 4
  then buffer = buffer || getpiece()
  parse var buffer LLI +3 buffer
  parse var LLI LL +2 I +1
  if bitand(I, '80'X) = '80'X
  then do /* TTR follows LLI */
    if length(buffer) < 3
    then buffer = buffer || getpiece()
    parse var buffer TTR +3 buffer
    end
  else TTR = ''
  LL = c2d(LL)
  do while LL > length(buffer)
    LL = LL - length(buffer)
    block = block || buffer
    buffer = getpiece()
  end
  if LL > 0
  then do
    block = block || substr(buffer, 1, LL)
    buffer = substr(buffer, LL+1)
    end
  I = bitand(I, '3F'x)
  return

getpiece:
  if length(data) < 80
  then call read
  /* each card image start with 2-byte seq number */
  parse var data seq +2 piece +78 data
  return piece

vmfplc2_directory:
cmstape_directory:
  'msg Please wait...'
  parse arg id
  name = name'.directory'
  rc = stream(name, 'c', 'open write replace')
  n = 0
  do forever
    rc = read()
    if rc <> 0
    then leave
    parse var data hdr +5 .
    if (what = 'VMFPLC2')
    then do
      if hdr <> spell.plch
      then iterate
      parse var data hdr +5 fname +8 ftype +8 . +8 fmode +2 nrec +2 . +2 recfm +1 plcflag1 +1 lrecl +4 db +2 year +2 lastsz +4 nblk +4 . +4 adbc +4  . +6 yymmdd +3 hhmmss +3 . +4
      nblk = c2d(nblk)*5 + c2d(lastsz) /* 5 = (PLC2 blksize 4000) / (CMS blksize 800) */
      end
    else do
      if (hdr <> spell.cmsn) & (hdr <> spell.ptsn)
      then iterate
      parse var data hdr +5 . +10 recfm +1 . +1 lrecl +4 nblk +2 . +14 nrec +4 . +2 yymmdd +3 hhmmss +3 . +20 fname +8 ftype +8 fmode +2
      nblk = c2d(nblk)
      end
    n = n+1
    ddmmyy = translate('56.34.12', c2x(yymmdd), '123456')
    hhmmss = translate('12:34:56', c2x(hhmmss), '123456')
    nrec = c2d(nrec)
    call lineout name, ASCII(fname) ASCII(ftype) ASCII(fmode) '  ' ASCII(recfm) right(c2d(lrecl),10) right(nblk,6) right(nrec,6) '' ddmmyy hhmmss
  end
  rc = stream(name, 'c', 'close')
  if n = 0
  then do
    'emsg This TAPE DUMP format ('c2x(hdr)') does not supported'
    return
    end
  'x 'name
  return

vmfplc2_file:
cmstape_file:
  parse var curline.3 fname ftype fmode recfm lrecl nblks nrecs .
  /* we cannot find VMFPLC2 header by fname/ftype/fmode, because tape file
  may contains several copies of the same cms file, so we based on the file
  sequential number */
  n = 0
  r = 0
  do while n < line.1
    if (what <> 'VMFPLC2') & (r = 0)
    then p = stream(awsfile, 'c', 'query position read')
    rc = read()
    if rc <> 0
    then leave
    r = r+1
    parse var data hdr +5 .
    if (what = 'VMFPLC2')
    then do
      if hdr = spell.plch
      then n = n+1
      end
    else do
      if hdr = spell.cmsn | hdr = spell.ptsn
      then do
        n = n+1
        r = 0
        end
      end
  end
  name = strip(fname)'.'strip(ftype)'.'strip(fmode)
  if rc <> 0
  then do
    'emsg File not found'
    return
    end
  if what <> 'VMFPLC2'
  then call stream awsfile, 'c', 'seek 'p' read'
  'msg loading 'name' 'recfm' 'lrecl' 'p
  rc = stream(name, 'c', 'open write replace')
  n = 0
  pack = 0
  residual = ''
  do i = 1 while n <= nrecs
    rc = read()
    if rc <> 0
    then leave
    parse var data hdr +5 data
    if what = 'VMFPLC2'
    then do
      if hdr = spell.plch
      then leave
      end
    else do
      if (hdr = spell.cmsn) | (hdr = spell.ptsn)
      then leave
      end
    if residual <> ''
    then do
      data = residual''data
      residual = ''
      end
    do j = 1 while data <> ''
      if recfm = 'F'
      then l = lrecl
      else l = c2d(left(data,2)) + 2
      if l <= length(data)
      then do /* we have complete record */
        parse var data record +(l) data
        if recfm = 'V'
        then record = substr(record,3) /* skip length field */
        if (n = 0) & (recfm = 'F') & (lrecl = 1024) & (left(record,1) = '00'x)
        then pack = 1 /* Seems file is packed */
        if pack = 0
        then call lineout name, ASCII(record)
        else call charout name, record
        n = n+1
        if n = nrecs
        then leave i
        end
      else do /* record incomplete */
        residual = data
        data = ''
        end      
    end
  end 
  rc = stream(name, 'c', 'close')
  if pack = 1
  then do
    rc = unpack(name, name'.unpacked')
    if rc <> 0
    then do
      'emsg Cannot unpack file 'name
      return
      end
    name = name'.unpacked'
    end
  'x 'name
  return

unpack:
  parse arg source, target
  rc = stream(source, 'c', 'open read')
  rc = stream(target, 'c', 'open write replace')
  header = charin(source,,8)
  select
  when left(header,4) = '000140E5'x
  then recfm = 'V'
  when left(header,4) = '000140C6'x
  then recfm = 'F'
  otherwise
    return 1
  end
  fill = substr(header,3,1)
  lrecl = c2d(substr(header,5,4))
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
      call lineout target, ASCII(line)
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
      call lineout target, ASCII(left(line, lrecl))
      line = substr(line, lrecl+1)
    end
  end
  do while length(line) >= lrecl
    call lineout target, ASCII(left(line, lrecl))
    line = substr(line, lrecl+1)
  end
  rc = stream(source, 'c', 'close')
  rc = stream(target, 'c', 'close')
  return 0

repeat:
  l = charin(source,,arg(1))
  if arg() = 1
  then r = charin(source,,1)
  else r = arg(2)
  return copies(r, c2d(l)+1)

write:
  'msg Please wait...'
  parse arg name
  name = name'.data'
  rc = stream(name, 'c', 'open write replace')
  do forever
    rc = read()
    if rc <> 0
    then leave
    call charout name, data
  end
  rc = stream(name, 'c', 'close')
  'emsg Write raw file 'name
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
  'editv get label'
  'editv get awsline'
  parse var awsline 1 file 6 7 blks 13 14 name 31 32 recfm 35 38 lrecl 43 46 blksize 51 52 credt 62 63 what 80
  name = strip(name)
  if name = ''
  then name = 'File.'strip(file)
  c = max(length(awslist),length(label)) 
  title = left(awslist,c)''center(fname.1'.'fext.1,80-c-c)''right(label,c)
  'set reserved 1 !['title
  'set reserved 2 'copies(' ',80)'.'
  'define F2 macro awslist.rex cmdline'
  'define F3 qquit'
  'define F12 ccancel'
  ':1'
  select
  when fext.1 = 'map'
  then do
    'define F10 macro awslist.rex browse'
    'define A-F10 macro awslist.rex write'
    'set reserved 3  File Blocks Name              Recfm Lrecl Blksize Created    Content            Seek '
    'set reserved -1 ![ F1=help  F2=cmdline  F3=quit  F7=backward  F8=forward  F10=browse  F12=cancel!]'
    end
  when fext.1 = 'directory'
  then do
    select
    when (what = 'CMS TAPE') | (what = 'PTS TAPE') | (what = 'VMFPLC2')
    then do
      'set reserved 3 Name     Type     Mode  Recfm  Lrecl  Nblks  Nrecs  Created!]'
      'set reserved -1 ![ F1=help  F2=cmdline  F3=quit  F7=backward  F8=forward  F10=browse  F12=cancel!]'
      end
    when what = 'IEHMOVE'
    then do
      'define F10 REXX awslist browse member'
      'set reserved 3 Member   TTR'
      'set reserved -1 ![ F1=help  F2=cmdline  F3=quit  F7=backward  F8=forward  F10=browse  F12=cancel!]'
      end
    when what = 'IEBCOPY'
    then do
      'define F10 REXX awslist browse member'
      'set reserved 3 Member   TTR'
      'set reserved -1 ![ F1=help  F2=cmdline  F3=quit  F7=backward  F8=forward  F10=browse  F12=cancel'
      end
    otherwise
      'set reserved 3 Member   TTR'
      'set reserved -1 ![ F1=help  F2=cmdline  F3=quit  F7=backward  F8=forward              F12=cancel'
    end
    end
  otherwise /* either member or file */
    'set curline on 3'
    'set reserved -1 ![ F1=help  F2=cmdline  F3=quit  F7=backward  F8=forward              F12=cancel'
    'verify 1 80'
  end
  'sos current'
  exit

/* Find greatest common divisor of two numbers */
/* (C) 300BC Euclid */
gcd: procedure
  parse arg x, y
  select
  when y = 0 then return x
  when x = 0 then return y
  when x <= y then return gcd(y//x, x)
  otherwise
    return gcd(x//y, y)
  end
  exit

msg:
  parse arg cc +3 severity +1 blank + 1 message
  select
  when severity = 'I'
  then say 'Info: 'message
  when severity = 'W'
  then say 'Warning: 'message
  otherwise /* severity = 'S' | severity = 'T' */
    say 'Error: 'message
    signal quit
  end
  return ''


/* Write disk file to AWSTAPE file */
/*

Function:
         Initialize AWSTAPE tape. 

Syntax:
         AWSINIT [options] awsfile volser [owner]

         options:
         {-SL | -NL}
         --

Usage:
         See awsinit.htm

(C) 1996-2023 Gregori Bliznets GregoryTwin@gmail.com

*/
trace off
call rxfuncadd 'sysloadfuncs', 'rexxutil', 'sysloadfuncs'
call sysloadfuncs
parse arg args
opt = '-'
label = ''
awsfile = ''
args = strip(args, 'L')
do while (args \= '' & left(args, 1) = opt)
  parse var args option args
  parse upper var option +1 kwd
  select
  when kwd = 'SL'
  then label = 'SL'
  when kwd = 'NL'
  then label = 'NL'
  when kwd = opt
  then leave /* Explicit fence */
  otherwise
    call msg '003T Invalid option "'Option'"'
  end
end
if label = ''
then label = 'SL'

parse var args awsfile volser owner other 
if awsfile = ''
then call msg '005T AWS file was not specified'
if volser = '' & label = 'SL'
then call msg '005T Volume serial was not specified'
if other <> ''
then call msg '006T Extraneous parameters: "'other'"'

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

rc = stream(awsfile, 'c', 'open write replace')
if label = 'SL'
then do
  volser = translate(volser) 
  /* write VOL1 label */
  call charout awsfile, '50000000A000'x || EBCDIC('VOL1'left(volser,6)''copies(' ',31)''left(owner,10)''copies(' ',29))
  /* write dummy HDR1 label */
  call charout awsfile, '50005000A000'x || EBCDIC('HDR1') || copies('00'x,76)
  end
/* write tapemark */
call charout awsfile, '000050004000'x 
quit:
if awsfile <> ''
then call stream awsfile, 'c', 'close'
exit 0

ASCII:
  return translate(arg(1), xlate)

EBCDIC:
  return translate(arg(1), xrange('00'x, 'FF'x), xlate)

msg:
  say arg(1)
  if substr(arg(1),4,1) = 'T' /* message severity code */
  then signal quit
  return ''

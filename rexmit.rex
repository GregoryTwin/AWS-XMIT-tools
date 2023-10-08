/* REXX */
/*

Function:
         Anonomyze transmit file: updates origin node, origin userid, origin
         data set name

Syntax:
         REXMIT [options] input_file output_file

         options:
         -node newnode
         -userid newuserid
         -dsname newdsname

         If new node, new userid or new dsname was not specified, existing
         value(s) remains unchanged.

(C) 2014-2023 Gregori Bliznets GregoryTwin@gmail.com
(C) David Alcock - pieces of source code of XMITINFO was used 

*/
parse arg args
parse value '' with inputfile outputfile newnode newuid newdsn buffer 
opt = '-'
do while (args <> '' & left(args, 1) = opt)
  parse var args option value args
  if value = ''
  then call msg '002T Missed value of option "'option'"'
  parse upper var option +1 keyword
  select
  when abbrev('NODE', Keyword, 1)
  then var = 'newnode'
  when abbrev('USERID', Keyword, 1)
  then var = 'newuid'
  when abbrev('DSNAME', Keyword, 1)
  then var = 'newdsn'
  otherwise
    call msg '003T Invalid option "'opt'"'
  end
  if value(translate(var)) <> ''
  then call msg '010T Duplicate option "'opt'"'
  call value translate(var), value
end
parse var args inputfile outputfile .
if newdsn <> ''
then newdsn = translate(newdsn, ' ', '.')
if inputfile = ''
then call msg '004T Input file was not specified'
if outputfile = ''
then call msg '004T Output file was not specified'
if stream(inputfile, 'c', 'query exists') = ''
then call msg '007T File "'inputfile'" not found'
if stream(inputfile, 'c', 'query size') = 0 
then call msg '008T File "'inputfile'" is empty'
if newdsn''newnode''newuid = ''
then call msg '020T Nothing to do: -node -userid -dsname are missed'

call msg '011I Retransmitting file 'inputfile' to 'outputfile
rc = stream(outputfile, 'c', 'open write replace')

/* ISO 8859-1 to CECP 1047 (Extended de-facto EBCDIC).
In this case does not matter which code page are used,
because just latin-1 characters need to be converted */
xlate = '00010203372D2E2F1605250B0C0D0E0F'x , /* 00 */
     || '101112133C3D322618193F271C1D1E1F'x , /* 10 */
     || '405A7F7B5B6C507D4D5D5C4E6B604B61'x , /* 20 */
     || 'F0F1F2F3F4F5F6F7F8F97A5E4C7E6E6F'x , /* 30 */
     || '7CC1C2C3C4C5C6C7C8C9D1D2D3D4D5D6'x , /* 40 */
     || 'D7D8D9E2E3E4E5E6E7E8E9ADE0BD5F6D'x , /* 50 */
     || '79818283848586878889919293949596'x , /* 60 */
     || '979899A2A3A4A5A6A7A8A9C04FD0A107'x , /* 70 */
     || '202122232415061728292A2B2C090A1B'x , /* 80 */
     || '30311A333435360838393A3B04143EFF'x , /* 90 */
     || '41AA4AB19FB26AB5BBB49A8AB0CAAFBC'x , /* A0 */
     || '908FEAFABEA0B6B39DDA9B8BB7B8B9AB'x , /* B0 */
     || '6465626663679E687471727378757677'x , /* C0 */
     || 'AC69EDEEEBEFECBF80FDFEFBFCBAAE59'x , /* D0 */
     || '4445424643479C485451525358555657'x , /* E0 */
     || '8C49CDCECBCFCCE170DDDEDBDC8D8EDF'x   /* F0 */

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

/* Process the segments in the XMIT file */
do n = 1
  l = charin(inputfile,,1)
  if l == ''
  then leave /* EOF */
  segmentl = c2d(l)
  segment = charin(inputfile,,segmentl-1)
  segmentd = substr(segment,1,1)
  segmentc = ASCII(substr(segment,2,6))
  /* Verify that this looks like an XMIT file */
  if (n = 1) & (segmentc <> 'INMR01')
  then call msg '011T Not an TSO XMIT format: wrong token 'c2x(substr(rec,3,6))c2x(substr(COPYR1,10,3))
  control = (bitand(segmentd,'20'x) = '20'x)
  if control & pos(segmentc' ', 'INMR01 INMR02 ') > 0
  then do
    if segmentc = 'INMR01'
    then ptr = 8
    else ptr = 12
    textend = segmentl
    output = substr(segment, 1, ptr-1)
    do while ptr < textend
      call Extract_TU
      select
      when (textui = INMFNODE) & (newnode <> '')
      then output = output || Build_TU(INMFNODE, newnode)
      when (textui = INMFUID) & (newuid <> '')
      then output = output || Build_TU(INMFUID, newuid)
      when (textui = INMDSNAM) & (newdsn <> '')
      then output = output || Build_TU(INMDSNAM, newdsn)
      otherwise
        output = output''tu
      end
      ptr = ptr + textut
    end
    segment = output
  end
  /*
    X'80' - First segment of original record
    X'40' - Last segment of original record
    X'20' - This is (part of) a control record
    X'10' - This is record number of next record
    X'0F' - Reserved
  */
  if length(segment) > 254
  then do
    call msg '012W Too long segment 'n', splitted'
    flags = left(segment,1)
    buffer = buffer || d2c(255) || bitand(flag,'BF'x) || substr(segment,2,253)
    segment = flag || substr(segment,256)
    end
  /* write segment */
  buffer = buffer || d2c(length(segment)+1,1) || segment
  do while length(buffer) > 80
    call charout outputfile, substr(buffer,1,80)
    buffer = substr(buffer, 81)
  end 
  if control & segmentc = 'INMR06'
  then leave
end
if length(buffer) > 0
then call charout outputfile, left(buffer,80,'40'x)
cc = 0

quit:
exit cc

/* Extract text unit */
Extract_TU:
  textui = substr(segment,ptr,2)
  textun = c2d(substr(segment,ptr+2,2))
  tu = substr(segment,ptr,4)
  textul = c2d(substr(segment,ptr+4,2))
  textut = 4 /* set starting length of text unit */
  tpos = ptr + 4 /* get temp position in segment */
  do j = 1 to textun
    tlen = c2d(substr(segment,tpos,2))
    value.j = substr(segment,tpos+2,tlen)
    tu = tu || substr(segment,tpos,tlen+2)
    tpos = tpos + tlen + 2
    textut = textut + 2 + tlen
  end j
  value.0 = textun
  if textun = 0 then tu = tu || '01'x 
  return

/* Build text unit */
Build_TU:
  parse arg key, units
  n = 0
  tu = ''
  do while units <> ''
    n = n + 1
    parse var units unit units
    tu = tu || d2c(length(unit),2) || EBCDIC(unit)
  end
  return key || d2c(n,2) || tu

ASCII:
  return translate(arg(1), xrange('00'x, 'FF'x), xlate)

EBCDIC: /* currently unused */
  return translate(arg(1), xlate)

msg:
  say arg(1)
  if substr(arg(1),4,1) = 'T' /* message severity code */
  then signal quit
  return ''

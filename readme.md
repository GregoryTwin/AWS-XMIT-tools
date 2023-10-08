                 AWS & XMIT processing tools on Windows/Unix

All procedures written in REXX, both OOREXX and Regina REXX are supported.
AWSLIST and XMITLIST are full-screen implemented with THE, all other procedures
are line-mode. Each procedure can be used separately. 

File extension .rex should be properly associated (see also REXLINK below).

AWSLIST  - full-screen AWS tape browser. Both standard labelled and unlabelled
           tapes supported. Several unloaded formats recognized.
           Browse tape files, directories and members of IEBCOPY or IEHMOVE
           unloaded data sets, enhanced browse of the printable data set having
           ASA control charaters. 
AWSLOAD  - extracts data from AWS tape. Entire files can be extracted as well
           as IEBCOPY/IEHMOVE unloaded members.
AWSDUMP  - write data to AWS tape. Both standard labelled and unlabelled tapes
           supported, data set standard labels created as required. Existing
           tape may be appended.
AWSINIT  - initialize AWS tape. The same as z/OS IEHINITT does.
AWSMAP   - shortcut for AWSLIST -batch. Write AWS tape map and exits.
UNCOPY   - extracts members from IEBCOPY unloaded file
UNMOVE   - extracts members from IEHMOVE unloaded file
UNISAM   - extracts data from IEBISAM unloaded file
XMITLIST - full-screen XMIT (TRANSMIT, IDTF) browser. A functional equivalent
           of well-known XMITMGR.
UNXMIT   - extracts data from XMIT file (line-mode utility)
REXMIT   - "anonimize" XMIT file
DEXMIT   - extracts IEBCOPY image from XMIT file;
REXLINK  - quickly associate .rex extension with OOREXX (REXLINK OOREXX)
           or REGINA (REXLINK REGINA); 
UNPACK   - unpack data packed by CMS COPYFILE or TSO/ISPF EDIT

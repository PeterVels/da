/*REXX**********Copyleft (C) 2019 Andrew J. Armstrong******************
**                                                                   **
** NAME     - DA                                                     **
**                                                                   **
** TITLE    - DISASSEMBLER EDIT MACRO                                **
**                                                                   **
** FUNCTION - Disassembles the AMBLIST output currently being edited.**
**                                                                   **
**            This is usually an iterative process:                  **
**                                                                   **
**            1. Run DA on the AMBLIST output. This will help to     **
**               identify which areas are data and which are code.   **
**                                                                   **
**               If you see a comment in the output like "<-- TODO   **
**               (not code)" it means that the dissassembler was in  **
**               CODE parsing mode but detected an invalid instruc-  **
**               tion. You should insert a "." to switch the dis-    **
**               assembler into DATA parsing mode at that point, and **
**               then insert a "," to revert to CODE mode at the end **
**               of that block of data.                              **
**                                                                   **
**            2. Mark the beginning of areas known to be code with a **
**               "," and those known to be data with a "." (i.e.     **
**               Comma-for-Code, Dot-for-Data).                      **
**               Run DA again until no 'TODO' comments are seen.     **
**                                                                   **
**            3. Tag the AMBLIST output (much more detail below).    **
**               Run DA again until the result is satisfactory.      **
**               Tags are enclosed in parentheses and can be used    **
**               to:                                                 **
**                                                                   **
**               - Mark data areas as having particular data types.  **
**                                                                   **
**                 For example:                                      **
**                 (F) 00000010 (H) 00220023 (X) 0102(P)19365C (B)8F **
**                                                                   **
**                 Generates:                                        **
**                           DC    F'16'                             **
**                           DC    H'34'                             **
**                           DC    H'35'                             **
**                           DC    XL2'0102'                         **
**                           DC    PL3'19365'                        **
**                           DC    B'10001111'                       **
**                                                                   **
**               - Assign a label at an offset into the code.        **
**                                                                   **
**                 For example:                                      **
**                 18CF(myLabel)47F0C010                             **
**                                                                   **
**                 Generates:                                        **
**                          LR    R12,R15                            **
**                 myLabel  B     16(,R12)                           **
**                                                                   **
**               - Explicitly assign a label to a code offset:       **
**                                                                   **
**                 For example:                                      **
**                 (myLabel=2,myData=6)18CF47F0C010.1234             **
**                                                                   **
**                 Generates:                                        **
**                          LR    R12,R15                            **
**                 myLabel  B     16(,R12)                           **
**                 myData   DC    XL2'1234'                          **
**                                                                   **
**               - Specify/drop a base register for the subsequent   **
**                 code.                                             **
**                                                                   **
**                 For example:                                      **
**                 (R12)18CF47F0C002(R12=)                           **
**                                                                   **
**                 Generates:                                        **
**                          USING *,R12                              **
**                          LR    R12                                **
**                 L2       B     L2                                 **
**                          DROP  R12                                **
**                                                                   **
**               - Specify a base register for a named DSECT. This   **
**                 is very powerful because it causes a DSECT to     **
**                 be built containing fields for each displacement  **
**                 off that base register that is referenced by the  **
**                 code. The name of each field is derived from the  **
**                 displacement.                                     **
**                                                                   **
**                 For example:                                      **
**                 (R13=>WA)5810D010 5010D044 (R13=)                 **
**                                                                   **
**                 Generates:                                        **
**                          USING WA,R13                             **
**                          L     R1,WA_10                           **
**                          ST    R1,WA_44                           **
**                          DROP  R13                                **
**                 WA       DSECT                                    **
**                          DS    XL16                               **
**                 WA_10    DS    XL4                                **
**                          DS    XL48                               **
**                 WA_44    DS    XL4                                **
**                                                                   **
**               - Do some other useful things (see below)           **
**                                                                   **
**            4. Assemble the disassembled source file. You will     **
**               likely see some assembly error messages like:       **
**                                                                   **
**               ** ASMA044E Undefined symbol - L12C                 **
**                                                                   **
**               ...which is easily resolved by going back to the    **
**               AMBLIST output and inserting a "." (for data) at    **
**               offset +12C. That will create the missing label     **
**               (L12C) at that offset.                              **
**                                                                   **
**               Rerun DA and reassemble the output until all        **
**               assembly errors are resolved.                       **
**                                                                   **
**                                                                   **
**                                                                   **
**            If DA is invoked outside of the ISPF editor then it    **
**            will generate and edit an AMBLIST job that you can     **
**            submit to produce a module listing that can be read    **
**            by the DA macro. For example, the following command    **
**            will generate JCL to list module IEFBR14:              **
**                                                                   **
**            TSO DA SYS1.LPALIB(IEFBR14)                            **
**                                                                   **
**            If DA is invoked in an ISPF edit session with the TEST **
**            option, e.g. "DA (TEST", then an assembler source file **
**            is generated containing one valid assembler statement  **
**            for each instruction. This can be assembled into a     **
**            load module, printed with AMBLIST and used to check    **
**            that DA can disassemble all instructions correctly.    **
**                                                                   **
** SYNTAX   - DA [dsn] [(options...]                                 **
**                                                                   **
**            Where,                                                 **
**            dsn     = Load module to be printed using AMBLIST. The **
**                      dataset name must be fully qualified and     **
**                      include the module name in parentheses.      **
**                                                                   **
**            options =                                              **
**                                                                   **
**            STAT    - Generate instruction format and mnemonic     **
**                      usage statistics.                            **
**                                                                   **
**            TEST    - Generate a source file to exercise the       **
**                      assembler. When assembled into a module, the **
**                      result can be used to test the disassembler. **
**                                                                   **
**                                                                   **
** NOTES    - 1. As new instructions are added to the z/Series inst- **
**               ruction set, it will be necessary to define them in **
**               the comments below marked by BEGIN-xxx and END-xxx  **
**               comments. Otherwise the new instructions will be    **
**               treated as data.                                    **
**                                                                   **
**            2. External Symbol Dictionary symbol quick reference:  **
**               CM - Common control section (COM)                   **
**               ED - Element definition (CATTR)                     **
**               ER - External reference (EXTRN)                     **
**               LD - Label definition (ENTRY)                       **
**               LR - Label reference                                **
**               PC - Private code (unnamed START, CSECT, RSECT)     **
**               PR - Part definition (CATTR PART)                   **
**               SD - Section definition (START, CSECT, RSECT)       **
**               WX - Weak external reference (WXTRN)                **
**               XD - External dummy section (DXD or Q-type addr)    **
**                                                                   **
**            3. A handy way to initially tag the AMBLIST output is  **
**               to issue the following EDIT commands:               **
**                                                                   **
**               C 90EC ("")90EC ALL; C 07FE 07FE('') ALL            **
**                                                                   **
**               This will highlight subroutines bounded by the      **
**               usual STM R14,R12,12(R13) and BR R14 instructions.  **
**                                                                   **
**                                                                   **
**                                                                   **
** USAGE    -                                                        **
**                                                                   **
BEGIN-JCL-COMMENTS
** To disassemble a load module:                                     **
**                                                                   **
** 0. Run TSO DA to generate and edit an AMBLIST job. For example:   **
**    TSO DA SYS1.LPALIB(IEFBR14)                                    **
**                                                                   **
** 1. Submit the AMBLIST job to print a dump of the selected module  **
**                                                                   **
** 2. Edit the SYSPRINT output (e.g. issue SE in SDSF)               **
**                                                                   **
** 3. Optionally, exclude areas that you do not want disassembled.   **
**    That may help speed up disassembly of large modules.           **
**                                                                   **
** 4. Optionally, mark blocks of hex using action markers.           **
**                                                                   **
**    Action markers are a quick way to mark blocks of hex as being  **
**    either CODE or DATA.                                           **
**                                                                   **
**    The following action markers can be inserted:                  **
**                                                                   **
**    Action    Meaning                                              **
**    --------- ---------------------------------------------------- **
**    ,         Scan following hex as CODE and generate a label.     **
**              Remember: Comma=Code                                 **
**                                                                   **
**    .         Scan following hex as DATA and generate a label.     **
**              Remember: Dot=Data                                   **
**                                                                   **
**    |         Scan following hex as DATA but do NOT generate a     **
**              label. This can be used to break up data into logical**
**              pieces that do not need to be addressed individually **
**              via a label.                                         **
**              Remember: Bar=Break                                  **
**                                                                   **
**    /         Reset to automatic data type detection and scan the  **
**              following hex as DATA. This is equivalent to speci-  **
**              fying a null tag () but saves a keystroke.           **
**                                                                   **
** 5. Optionally, tag the hex more rigorously:                       **
**                                                                   **
**    Tags are a way to further clarify how CODE or DATA blocks      **
**    should be interpreted. The syntax for a tag is:                **
**                                                                   **
**    (tag,...) One or more case sensitive tags separated by commas  **
**              and enclosed in parentheses. For example:            **
**                                                                   **
**              (MYCSECT,R12)                                        **
**                                                                   **
**              ...means label the data following MYCSECT and assume **
**              that R12 points to it at runtime.                    **
**                                                                   **
**              (R12=,F)                                             **
**                                                                   **
**              ...means that R12 no longer points to anything and   **
**              that the data following should be interpreted as     **
**              fullword constants.                                  **
**                                                                   **
**    The following tags can be inserted:                            **
**                                                                   **
**    (tag)     Meaning                                              **
**    --------- ---------------------------------------------------- **
**                                                                   **
**    ('comment') Inserts a comment into the generated source file   **
**              with the format:                                     **
**                                                                   **
**              *--------------------------------------------------* **
**              * comment                                            **
**              *--------------------------------------------------* **
**                                                                   **
**              A good use for this is to mark the end of subrout-   **
**              ines by making a global change to the hex input data **
**              as follows:                                          **
**              C 07FE 07FE('') ALL                                  **
**              ...which will cause an empty comment to be inserted  **
**              after every BR R14 instruction.                      **
**                                                                   **
**                                                                   **
**    ("comment") Inserts a comment into the generated source file   **
**              with the format:                                     **
**                                                                   **
**              **************************************************** **
**              *                                                  * **
**              *                    comment                       * **
**              *                                                  * **
**              **************************************************** **
**                                                                   **
**              A good use for this is to mark the start of subrout- **
**              ines by making a global change to the hex input data **
**              as follows:                                          **
**              C 90EC ("")90EC ALL                                  **
**              ...which will cause an empty section heading to be   **
**              inserted before each STM R14,R12,x(Rn) instruction.  **
**                                                                   **
**                                                                   **
**    (x)       Converts the following data to data type x, where    **
**              x can be one of the following:                       **
**                                                                   **
**              x Type      Length   Generates (for example)         **
**              - -------   ------   ------------------------------- **
**              A Address   4        AL4(L304)                       **
**              B Binary    1        B'10110011'                     **
**              C Character n        CL9'Some text'                  **
**              F Fullword  4        F'304'                          **
**              H Halfword  2        H'304'                          **
**              P Packed    n        PL2'304'                        **
**              S S-type    2        S(X'020'(R12))                  **
**              X Hex       n        XL2'0304'                       **
**                                                                   **
**    ()        Resets the data type tag so that automatic data type **
**              detection is enabled. Automatic data type detection  **
**              splits the data into either printable text or binary.**
**              Binary data is defined as fullwords if aligned on a  **
**              fullword boundary, as halfwords if aligned on a      **
**              halfword boundary, or else is output as hexadecimal. **
**              Printable text is defined as character constants.    **
**              You can instead use the "/" action marker to do this.**
**                                                                   **
**    (@xxx)    Specifies that the current location counter is to be **
**              set to the hex address specified by xxx.             **
**              By default the initial location counter is 0.        **
**              The equivalent assembler directive is:               **
**              ORG   @+X'xxx'                                       **
**                                                                   **
**    (Rn)      Specifies that register n (where n = 0 to 15) points **
**              to the immediately following code or data.           **
**              The equivalent assembler directive is:               **
**              USING *,Rn                                           **
**                                                                   **
**              For example:                                         **
**                                                                   **
**               Register 12 points to offset 0                      **
**               |   Code               Data                         **
**               |   |                  |                            **
**               V   V                  V                            **
**              (R12)18CF 5820C008 07FE . 0000000A                   **
**                   code..............   data....                   **
**                                                                   **
**              The above would be disassembled as:                  **
**                                                                   **
**                        USING *,R12                                **
**              *         -----------                                **
**              L0        LR    R12,R15                              **
**                        L     R2,L8                                **
**                        BR    R14                                  **
**              L8        DC    F'10'                                **
**                                                                   **
**    (Rn+Rm)   Specifies that register n points to the immediately  **
**              following code or data, and that register m points   **
**              4096 bytes past register n (for as many registers as **
**              you specify - each additional register extends the   **
**              coverage by a further 4096 bytes).                   **
**              The equivalent assembler directive is:               **
**              USING *,Rn,Rm                                        **
**                                                                   **
**    (Rn=>name'desc')                                               **
**              Specifies that register n (where n = 0 to 15) points **
**              to (=>) a dummy section (DSECT) called "name".       **
**              Optionally, associate a short description "desc".    **
**              A DSECT is then built to cover subsequent address    **
**              references for that base register until a (Rn=) tag  **
**              is encountered which DROPs that register.            **
**              All DSECTs so generated will be appended to the end  **
**              of the disassembled source.                          **
**              The equivalent assembler directive is:               **
**              USING name,Rn                                        **
**                                                                   **
**    (Rn=xxx)  Specifies that register n (where n = 0 to 15) points **
**              to location xxx in hexadecimal.                      **
**              The equivalent assembler directive is:               **
**              USING @+xxx,Rn                                       **
**                                                                   **
**              ...where "@" is the label assigned to offset 0.      **
**                                                                   **
**    (Rn=label)Specifies that register n (where n = 0 to 15) points **
**              to location identified by label "label".             **
**              The equivalent assembler directive is:               **
**              USING label,Rn                                       **
**                                                                   **
**    (Rn=)     Resets a base register tag.                          **
**              The equivalent assembler directive is:               **
**              DROP  Rn                                             **
**                                                                   **
**    (label)   Assigns an assembler label to the following code or  **
**              data. You may use it to name a CSECT for example.    **
**              The label cannot be R0 to R15, or A,B,C,D,F,H,P,S or **
**              X as those have special meanings as described above. **
**              The maximum length of a label assigned in this way   **
**              is 8 (for pragmatic reasons).                        **
**                                                                   **
**              For example:                                         **
**                                                                   **
**                  Data            Code                             **
**                  | Data label    | Code label                     **
**                  | |             | |                              **
**                  V V             V V                              **
**              07FE.(nSize)0000000A,(getCVT)58200010                **
**              code        data....         code....                **
**                                                                   **
**              The above would be disassembled as:                  **
**                                                                   **
**                        BR    R14                                  **
**              nSize     DC    X'0000000A'                          **
**              getCVT    L     R2,16                                **
**                                                                   **
**    (label=x) Assigns an assembler label to the location x in      **
**              hexadecimal. Use this if you know in advance the     **
**              offset of particular CSECTs. For example,            **
**                                                                   **
**              (MAIN=0,CSECTA=1C0,CSECTB=280)                       **
**                                                                   **
**              Any address constants encountered will then use the  **
**              specified name instead of a literal. For example,    **
**                                                                   **
**                        DC    A(448)                               **
**                                                                   **
**              will be generated as:                                **
**                                                                   **
**                        DC    A(CSECTA)         X'000001C0'        **
**                                                                   **
**              Some labels will be automatically created from the   **
**              External Symbol Dictionary of the AMBLIST output.    **
**                                                                   **
** 6. Issue DA to disassemble the AMBLIST output being edited.       **
**    - Spaces in the hex input are not significant (with one        **
**      exception explained below).                                  **
**    - The DA macro will disassemble AMBLIST output that has the    **
**      following format:                                            **
**                                                                   **
**              Everything after 3 consecutive spaces is ignored     **
**              (to accommodate a bug in versions of AMBLIST prior   **
**              to z/OS v2.3 - see APAR OA58170).                    **
**                                     |                             **
**                                     V                             **
**      xxxxxxxx xxxxxxxx ... xxxxxxxx   *aaaaa...aaaa*              **
**      |offset| |------hex data-----|   |---ignored----->           **
**                                                                   **
**      If AMBLIST output is not detected, then the input is         **
**      considered to be free form printable hex with no offset.     **
**      For example:                                                 **
**        18CF 5820C008 07FE 0000000A                                **
**                                                                   **
**    - The first 80 columns of the disassembly are valid assembler  **
**      statements and can be pasted into an FB80 file to be proc-   **
**      essed by the HLASM assembler. That is, you can paste all the **
**      dissassembled lines and ignore the truncation warning.       **
**                                                                   **
**    - The remaining columns contain the following information:     **
**      location counter, instruction in hex, instruction format and **
**      the target operand length if any.                            **
**                                                                   **
** 7. Examine the "Undefined labels" report at the end of the dis-   **
**    assembly to help you identify where to insert CODE and DATA    **
**    action markers. Labels will be created at each action marker   **
**    location (except for the "|" action marker).                   **
**                                                                   **
** 8. Press F3 to quit editing the disassembly and return to the     **
**    AMBLIST output - where you can adjust the tags as described    **
**    above and try again.                                           **
**                                                                   **
** 9. Submit an assembly job to verify that the disassembled code    **
**    assembles cleanly.                                             **
**                                                                   **
**                                                                   **
** AUTHOR   - Andrew J. Armstrong <androidarmstrong@gmail.com>       **
**                                                                   **
END-JCL-COMMENTS
**                                                                   **
** HISTORY  - Date     By  Reason (most recent at the top please)    **
**            -------- --- ----------------------------------------- **
**            20200106 AA  Reworked operand length hints.            **
**            20191213 AA  Allowed dsn to be specified on DA command.**
**            20191212 AA  Added description to the "=>" tag.        **
**            20191209 AA  Displayed TODO count message.             **
**            20191206 AA  Added '/' action marker and updated doc.  **
**            20191205 AA  Fixed processing of tags after the end of **
**                         the hex input.                            **
**            20191204 AA  Allocated edit dataset based on the size  **
**                         of the input hex to be decoded.           **
**            20191203 AA  Fixed (Rn=xxx) tag processing.            **
**                         Added reference support for DC A(label).  **
**            20191203 AA  Fixed implicit operand lengths.           **
**            20191202 AA  Added length to undefined labels report.  **
**            20191125 AA  Detected undefined labels.                **
**            20191119 AA  Added support for S-type addresses. They  **
**                         are commonly used for patch areas.        **
**            20191113 AA  Set flag 'c' on all instructions that set **
**                         the condition code.                       **
**            20191031 AA  Added support for DSECTs (Rn=>name) tag   **
**                     AA  Added support for comments ('comment')    **
**                     AA  Added support for sections ("comment")    **
**                     AA  Fixed extended mnemonics                  **
**            20191023 AA  Fixed operand construction by adding      **
**                         "hard" blank translation                  **
**            20191014 AA  Added z/OS SVC descriptions               **
**            20191014 AA  Added multiple register USING support     **
**            20191008 AA  Added new z15 instructions                **
**            20190625 AA  Initial version                           **
**                                                                   **
**********************************************************************/
trace o
  parse arg sDsn'('sMod')' '('sOptions
  if sDsn = '' then parse arg '('sOptions
  sDsn = strip(sDSN,'BOTH',"'")
  parse source . . me .
  address ISPEXEC 'CONTROL ERRORS RETURN'
  numeric digits 22
  call prolog
  address ISREDIT
  '(state) = USER_STATE'      /* Save current editor state           */

  if g.0OPTION.TEST = 1       /* Generate test assembler source?     */
  then do
    call generateTestBed
    call epilog
    exit 0
  end

  call emit '@        START'
  call emit '*Label   Op    Operands                'left('Comment',59),
            'Location Hex          Format'

  call setLoc 0               /* Initial location counter            */
  xMeta = readMeta()          /* Determine the input format          */
  if g.0AMBLIST
  then do
    if g.0PGMOBJ
    then xData = readProgramObject()
    else xData = readModule()
  end
  else   xData = readRawHex()

  g.0ISCODE = 1       /* 1=Code 0=Data */
  do while xData <> '' /* Disassemble the extracted hex data */
    parse var xData xChunk '('sTags')' xData
    xChunk = space(xChunk,0)
    /* Decode any hex before the next tag */
    nPos = verify(xChunk,'.,|/','MATCH') /* first action character */
    if nPos = 0       /* If no dots, commas or vertical bars found */
    then do
      call decodeChunk xChunk
    end
    else do while xChunk <> ''
      nPos = verify(xChunk,'.,|/','MATCH') /* next dot or comma */
      if nPos > 0
      then do /* decode up until the next action character */
        sAction = substr(xChunk,nPos,1) /* Get the action character */
        parse var xChunk xChunklet (sAction) xChunk
      end
      else do /* decode the complete chunk */
        xChunklet = xChunk
        sAction = ''
        xChunk = ''
      end
      if xChunklet <> ''
      then call decodeChunk xChunklet
      select
        when sAction = ',' then do /* If we are switching to code mode */
          g.0ISCODE = 1            /* Decode subsequent hex as code    */
          g.0TYPE = ''             /* Reset data type to automatic     */
        end
        when sAction = '.' then do
          g.0ISCODE = 0            /* Decode subsequent hex as data    */
                                   /* Using the existing data type     */
        end
        when sAction = '/' then do
          g.0ISCODE = 0            /* Decode subsequent hex as data    */
          g.0TYPE = ''             /* Reset data type to automatic     */
        end
        otherwise nop              /* Use existing mode and data type  */
      end
      if sAction <> '|' & getLabel(g.0XLOC) = '' /* If not already labeled */
      then call defLabel label(g.0XLOC),g.0XLOC /* Generate a label here */
    end
    /* Now process the tag, if any */
    call handleTags sTags
  end

  /* The following is a hack to ensure that any tags or action characters
     appended to the very end of the hex input data are actually processed  */
  if pos(sAction,'.,/') > 0 & isReferredTo(g.0XLOC) /* If trailing action    */
  then call saveStmt 'DS','0X'    /* Emit a label and any directives        */
  else call save ''               /* Emit only directives for this location */
  call nextLoc +1 /* Prevent repeating any directives on the last statement */

  call saveRegisterEquates
  call saveDSECTs

  /* Label all the back references found */
  do i = 1 to g.0BACKREF.0
    xLoc = g.0BACKREF.i
    nStmt = g.0STMT#.xLoc
    if nStmt <> ''
    then do
      sLabel = getLabel(xLoc)
      call defLabel sLabel,xLoc
      g.0STMT.nStmt = overlay(sLabel,g.0STMT.nStmt)
    end
  end

  if g.0OPTION.STAT
  then do
    call saveCommentBlock 'Statistics'
    call save '* Instruction format frequency ('g.0FC.0 'formats used)'
    call save '*'
    call save '*   Format     Count Mnemonics'
    call save '*   ------     ----- ---------'
    call sortStem 'g.0FC.',0
    do i = 1 to sorted.0
      n = sorted.i
      sFormat = g.0FN.n
      sMnemonics = strip(g.0ML.sFormat)
      if length(sMnemonics) <= 50
      then call save '*   'left(g.0FN.n,6) right(g.0FC.n,9) sMnemonics
      else do
        sForm = sFormat
        nFreq = g.0FC.n
        do while length(sMnemonics) > 50
          nPos = lastpos(' ',sMnemonics,50)
          if nPos = 0
          then do
            sChunk = sMnemonics
            sMnemonics = ''
          end
          else parse var sMnemonics sChunk +(nPos) sMnemonics
          call save '*   'left(sForm,6) right(nFreq,9) sChunk
          sForm = ''
          nFreq = ''
        end
        if sMnemonics \= ''
        then call save '*   'left(sForm,6) right(nFreq,9) sMnemonics
      end
    end
    call save '*'
    call save '* Instruction mnemonic frequency ('g.0MC.0 'mnemonics used)'
    call save '*'
    call save '*   Mnemonic   Count Format Description'
    call save '*   --------   ----- ------ -----------'
    call sortStem 'g.0MC.',0
    do i = 1 to g.0MC.0
      n = sorted.i
      sMnemonic = g.0MN.n
      call save '*   'left(g.0MN.n,6) right(g.0MC.n,9),
                        left(g.0MF.n,6) g.0DESC.sMnemonic
    end
  end

  nUndefinedLabels = saveUndefinedLabels()

  call save '         END'

  say 'DIS0009I Generated' g.0LINE 'statements ('g.0INST 'instructions)'
  if g.0TODO > 0
  then say 'DIS0010W There are' g.0TODO 'lines marked: TODO (not code)'
  if nUndefinedLabels > 0
  then say 'DIS0011W There are' nLabels 'references to undefined labels',
           '(see end of listing)'

  /* Post-process all the generated statements */
  do n = 1 to g.0LINE
    if left(g.0STMT.n,1) = 'L' /* If it has an auto-generated code label */
    then call emit             /* Then insert a blank line before it */
    xLoc = g.0LOC.n
    /* g.0CLENG.xLoc is the longest length actually used in an instruction
       that references this location. If it is longer than the data length
       assigned to this location then a 'DC 0XLnn' directive will be
       inserted to cover the entire field referenced by the instruction.
    */
    if g.0CLENG.xLoc <> ''     /* Length actually used in an inst */
    then do
      parse var g.0STMT.n sLabel sOp sOperand .
      if sOp = 'DC'
      then do
        sType = left(sOperand,1)
        if sType = 'A'
        then parse var sOperand 'A'nLen'('sValue')'        /* A() syntax */
        else parse var sOperand (sType) nLen"'"sValue"'"   /* X'' syntax */
        if left(nLen,1) = 'L'
        then nLen = substr(nLen,2)
        else do
          if nLen = ''
          then do
            select
              when sType = 'A' then nLen = 4
              when sType = 'F' then nLen = 4
              when sType = 'H' then nLen = 2
              when sType = 'S' then nLen = 2
              otherwise nLen = 1
            end
          end
        end
        if g.0CLENG.xLoc \= nLen
        then do
          /* Use the label from the existing statement */
          call emit left(sLabel,8) 'DC    0XL'g.0CLENG.xLoc
          g.0STMT.n = overlay(left('',8),g.0STMT.n)
        end
      end
    end
    call emit g.0STMT.n
  end


  'USER_STATE = (state)'      /* Restore editor state                */
  call epilog
return 1

readMeta: procedure expose g.
  /* Determine whether we are scanning AMBLIST output  */
  nRow = seek('*****  M O D U L E   S U M M A R Y  *****','FIRST')
  g.0AMBLIST = (nRow <> 0)
  /* Determine whether we are scanning a Program Object
     listing or a traditional module listing and then extract
     the list of CSECT names and their locations. This will be
     used to assign useful names to the assembly listing.
     If no names are extracted the assembly listing will still
     be produced, but without useful names assigned.
  */
  nRow = seek('21 PGM OBJ','FIRST')
  g.0PGMOBJ = (nRow <> 0)
  if g.0PGMOBJ
  then do
  /*
  A sample Program Object listing is as follows:
1                             ** NUMERICAL MAP OF PROGRAM OBJECT PLITST

0-------------------------------------------------------------------------------
0RESIDENT CLASS:           B_TEXT
0      CLAS LOC   ELEM LOC    LENGTH  TYPE  RMODE    ALIGNMENT             NAME
0        0                        7C   ED      31    DOUBLE WORD           CEEST
        80                       1B8   ED      31    DOUBLE WORD           **WOR
             C8         48             LD                                    WOR
       238                        28   ED      31    DOUBLE WORD           **WOR
       260                         C   ED      31    DOUBLE WORD           CEEMA
         .                         .   .       .     .                     .
         .                         .   .       .     .                     .
         .                         .   .       .     .                     .
0      CLASS LENGTH             175B
0-------------------------------------------------------------------------------
  */
    nRow = seek('NUMERICAL MAP OF PROGRAM OBJECT','FIRST')
    if nRow \= 0
    then do
      xLoc = ''
      '(nRow,nCol) = CURSOR'
      nRC = rc
      do i = nRow+3 while nRC = 0 & left(xLoc,8) <> '--------'
        '(sLine) = LINE' i
        nRC = rc
        parse var sLine 2 xLoc    . sType . 70 sName .
        if sType = 'ED'
        then do
          call attachSection xLoc,sName
          sName = translate(sName,'##','@*')
          call defLabel sName,xLoc
        end
      end
    end
  end
  else do
  /*
  A sample traditional module listing is as follows:
0RECORD# 1     TYPE 20 - CESD     ESDID 1                      ESD SIZE 48
0               CESD#    SYMBOL    TYPE     ADDRESS     R/R/A    ID/LENGTH(DEC)
                   1    IEFUTL    00(SD)     000000      0E            992
                   2    IEFUTLG   00(SD)     0003E0      06           3832
                   3    SMFCOM    00(SD)     0012D8      06           4256
  */
    nRow = seek('TYPE 20 - CESD','FIRST')
    do while nRow \= 0
      xLoc = ''
      nRC = 0
      nCESD = ''
      do i = nRow+1 while nRC = 0 & nCESD <> 'RECORD#' /* CLASS LENGTH */
        '(sLine) = LINE' i
        nRC = rc
        parse var sLine 2 nCESD sName . '('sType')' xLoc .
        if sType = 'SD' | sType = 'LR'
        then do
          sName = translate(sName,'##','@*') /* @*xxxxxx --> ##xxxxxx */
          call attachSection xLoc,sName
          call defLabel sName,xLoc
        end
      end
      nRow = seek('TYPE 20 - CESD','NEXT')
    end
  end
return ''

readProgramObject: procedure expose g.
  /* Parse the output from AMBLIST */
  /* This is a rather unfriendly format to navigate:
          .
          .
          CONTROL SECTION: <csectname>             <-- BEGIN CSECT
          CONTROL SECTION: <csectname>
     ===== TEXT =====
     <hex for csectname>                           <-- HEX OF INTEREST
     ===== TEXT =====
     <hex for csectname>                           <-- HEX OF INTEREST
          CONTROL SECTION: <nextcsectname>         <-- END CSECT
          .
          .
  */
  xData = ''
  nTop = seek('CONTROL SECTION:','FIRST NX')
  nRow = nextCSECT()
  do while nRow \= 0 /* for each TEXT block found */
    bSeekingLoc = 1
    do i = nRow+1 to nEnd-1
      '(sLine) = LINE' i
      '(sStatus) = XSTATUS' i
      if sStatus = 'NX' /* If this line is not excluded */
      then do
        parse var sLine 2 xLoc +8 sLine /* Ignore carriage control */
        xLoc = strip(xLoc)
        sLine = strip(sLine)
        parse var sLine sLine '*'   /* Discard dump on right */
        parse var sLine sLine '   ' /* ...or anything after 3 spaces */
        if length(xLoc) = 8 & isHex(xLoc)
        then do
          if bSeekingLoc
          then do
            call setLoc xLoc            /* Set the current location */
            bSeekingLoc = 0
            xData = xData'(@'xLoc')' /* Indicate where following hex starts */
          end
          xData = xData || sLine /* Append hex and/or tags */
        end
      end
    end
    nRow = nextCSECT()
  end
return xData

nextCSECT: procedure expose nBeg nEnd sCSECT
  '(r,c) = CURSOR'
  'CURSOR =' r 1
  nBeg = seek('CONTROL SECTION:','NEXT NX')
  if nBeg > 0
  then do
    '(sLine) = LINE' nBeg
    parse var sLine 'CONTROL SECTION:' sCSECT .
     nBeg = seek('===== TEXT =====','NEXT')
    nLast = seek('CONTROL SECTION:  'sCSECT,'LAST')
     nEnd = seek('CONTROL SECTION:','NEXT')
    if nEnd = 0
    then nEnd = seek('END OF PROGRAM OBJECT LISTING')
  end
return nBeg

readModule: procedure expose g.
  /* Parse the output from AMBLIST */
  xData = ''
  nRow = seek('T E X T','FIRST NX')
  nEnd = seek('******END OF LOAD MODULE LISTING')
  bSeekingLoc = 1
  if nRow \= 0
  then do i = nRow+1 to nEnd-1
    '(sLine) = LINE' i
    nRC = rc
    '(sStatus) = XSTATUS' i
    if sStatus = 'NX' /* If this line is not excluded */
    then do
      parse var sLine 2 xLoc sLine /* Ignore carriage control */
      sLine = strip(sLine)
      parse var sLine sLine '*'   /* Discard dump on right */
      parse var sLine sLine '   ' /* ...or anything after 3 spaces */
      xLoc = strip(xLoc)
      if length(xLoc) = 6 & isHex(xLoc)
      then do
        if bSeekingLoc
        then do
          call setLoc xLoc            /* Set the current location */
          bSeekingLoc = 0
          xData = xData'(@'xLoc')' /* Indicate where following hex starts */
        end
        xData = xData || sLine /* Append hex and/or tags */
      end
    end
  end
return xData

readRawHex: procedure expose g.
  xData = ''
  /* Parse raw hex with no location offsets */
  call setLoc 0
  '(sStatus) = XSTATUS 1'
  '(sLine) = LINE 1'
  do i = 2 while rc = 0
    if sStatus = 'NX'
    then do
      sLine = strip(sLine)
      parse var sLine sLine '*'   /* Discard dump on right */
      parse var sLine sLine '   ' /* ...or anything after 3 spaces */
      xData = xData || sLine
    end
    '(sStatus) = XSTATUS' i
    '(sLine) = LINE' i
  end
return xData

seek: procedure expose g.
  parse arg sString,sOptions
  'SEEK "'sString'"' sOptions
  '(nStrings,nLines) = SEEK_COUNTS'
  if nStrings > 0
  then '(nRow,nCol) = CURSOR' /* Line number on which string was found */
  else nRow = 0               /* Indicate string not found             */
return nRow

setLoc: procedure expose g.
  arg xLoc
  g.0LOC = x2d(xLoc)
  call nextLoc +0
return

nextLoc: procedure expose g.
  arg nIncrement
  g.0LOC = g.0LOC + nIncrement
  g.0XLOC = d2x(g.0LOC)
  g.0XLOC8 = right(g.0XLOC,8,0)
return

generateTestBed: procedure expose g.
  call emit '*PROCESS MACHINE(z14),FLAG(8)'
  call emit '         START'
  do i = 1 while sourceline(i) <> 'BEGIN-INSTRUCTION-DEFINITIONS'
  end
  do i = i+3 while sourceline(i) <> 'END-INSTRUCTION-DEFINITIONS'
    sLine = sourceline(i)
    parse var sLine sMnemonic xOpCode sFormat sFlag sDesc '='sHint
    if sMnemonic <> 'DIAG'
    then call genInst xOpCode,sMnemonic,sFormat,sFlag,sDesc
  end
  call emit '*'
  call emit '* General purpose register equates'
  call emit '*'
  do i = 0 to 15
    call emit left('R'i,8) 'EQU   'i
  end
  call emit '*'
  call emit '* Vector register equates'
  call emit '*'
  do i = 0 to 31
    call emit left('V'i,8) 'EQU   'i
  end
  call emit '         END'
  call epilog
return

decodeChunk: procedure expose g.
  parse arg xChunk
  nPos = verify(xChunk,'0123456789ABCDEFabcdef','NOMATCH')
  select
    when length(xChunk)//2 = 1 then do /* If it is a runt hex string */
      call ignoreChunk xChunk,,
           'DIS0007E Ignored hex with odd length at' g.0XLOC8
      call nextLoc +length(xChunk)%2+1
    end
    when nPos = 0 then do /* Valid hex with an even number of digits */
      if g.0ISCODE
      then call decodeCode xChunk
      else call decodeData xChunk
    end
    otherwise do          /* Invalid hex digit found                  */
      if nPos//2 = 0       /* If the second nibble is the invalid one */
      then nPos = nPos - 1 /* Then point to the start of the byte     */
      sWindow = substr(xChunk,nPos,8)
      xOffset = d2x(g.0LOC+(nPos-1)/2,8)
      call ignoreChunk xChunk,,
           'DIS0006E Ignored invalid hex at' xOffset
      call nextLoc +length(xChunk)%2
    end
  end
return

ignoreChunk: procedure expose g.
  parse arg xChunk,sMessage
  say sMessage
  call saveComment '*' sMessage':'
  call saveComment '* Location    +0       +4       +8       +C'
  nLoc = g.0LOC
  do i = 1 to length(xChunk) by 32
    xChunklet = substr(xChunk,i,32)
    parse var xChunklet x1 +8 x2 +8 x3 +8 x4 +8
    call saveComment '*' d2x(nLoc,8) '  ' x1 x2 x3 x4,
                     '   *'xc(x1)xc(x2)xc(x3)xc(x4)'*'
    nLoc = nLoc + 16
  end
return

xc: procedure expose g.
  arg xData
  if isHex(xData)
  then return toPrintable(xData)
return '....'

toPrintable: procedure expose g.
  parse arg xData
  sData = x2c(xData)
return translate(sData,g.0EBCDIC,g.0EBCDIC||xrange('00'x,'ff'x),'.')

handleTags: procedure expose g.
  parse arg sTags
  sTags = translate(sTags,g.0HARDBLANK,' ')
  sTags = translate(sTags,'',',')
  if sTags = ''
  then call handleTag
  else do i = 1 to words(sTags)
    call handleTag word(sTags,i)
  end
return

handleTag: procedure expose g.
  parse arg sTag1 +1 0 sTag
  sTag = translate(sTag,' ',g.0HARDBLANK) /* Soften hard blanks */
  select
    when sTag = '',                           /* ()  ...reset data type */
      | inset(sTag,'A B C F H P S X') then do /* (x) ...set data type   */
      g.0TYPE = sTag
      g.0ISCODE = 0                    /* Switch to data mode           */
    end
    when sTag1 = '"' then do           /* "section" */
      sTag = strip(sTag,'BOTH','"')
      call attachSection g.0XLOC,sTag
    end
    when sTag1 = "'" then do           /* 'comment' */
      sTag = strip(sTag,'BOTH',"'")
      call attachComment g.0XLOC,sTag
    end
    when sTag1 = '@' then do           /* @addr */
      parse var sTag '@'xLoc
      if isHex(xLoc)
      then do
        call setLoc xLoc               /* Set the current location */
        xLoc = g.0XLOC                 /* Remove leading zeros */
        if g.0ORG.xLoc = ''
        then do
          g.0ORG.xLoc = 1              /* Prevent duplicate ORG statements */
          call attachDirective g.0XLOC,''
          call attachDirective g.0XLOC,'ORG   @+'||x(g.0XLOC8)
        end
      end
    end
    when sTag1 = 'R' then do           /* (Rnn[+Rmm...][=][label]) */
      parse var sTag 'R'nn'='sLabel
      sRegisters = getRegisterList('R'nn)
      nRegisters = words(sRegisters)
      parse var sLabel sLabel"'"sDesc"'" /* Peel off the label description */
      select
        when left(sLabel,1) = '>' then do /* Rnn[+Rmm...]=>dsect */
          /* USING dsect,Rnn[,Rmm...] */
          sLabel = substr(sLabel,2)    /* Extract DSECT name */
          if g.0DSECT.sLabel = ''      /* If this is a new DSECT */
          then do
            n = g.0DSECT.0             /* Get DSECT count */
            if n = '' then n = 0       /* If none so far the count = 0 */
            n = n + 1                  /* Increment DSECT count */
            g.0DSECT.n = sLabel        /* Add this DSECT name to the array */
            g.0DSECT.sLabel = n        /* Remember DSECT has been seen */
            g.0DSECT.0 = n             /* Remember DSECT count so far */
            g.0DDESC.n = sDesc         /* Remember DSECT description */
          end
          dLoc = 0                     /* Displacement of first base register */
          do i = 1 to nRegisters
            nn = word(sRegisters,i)
            x = d2x(nn)                /* Base register (0 to F) */
            g.0DBASE.x = sLabel        /* DSECT this base points to */
            g.0DLOCN.x = dLoc          /* Offset into DSECT of this base */
            dLoc = dLoc + 4096
          end
          call attachDirective g.0XLOC,'USING' sLabel','using(sRegisters),1
        end
        when sRegisters = '' then do   /* (label) just starts with R */
          parse var sTag sLabel .
          call defLabel sLabel,g.0XLOC
        end
        when pos('=',sTag) = 0 then do /* (Rnn[+Rmm...])           */
          /* USING *,Rnn[,Rmm...] */
          xLoc = g.0XLOC               /* Get current location */
          sLabel = getLabel(xLoc)      /* Get label from location if any */
          if sLabel = '' then sLabel = '*' /* If unnamed then use '*' */
          dLoc = x2d(xLoc)             /* Displacement of first base register */
          do i = 1 to nRegisters
            nn = word(sRegisters,i)
            x = d2x(nn)                /* Base register (0 to F) */
            g.0CBASE.x = d2x(dLoc)     /* Set base register to location */
            dLoc = dLoc + 4096
          end
          call attachDirective g.0XLOC,'USING' sLabel','using(sRegisters),1
        end
        when sLabel = '' then do       /* (Rnn[+Rmm...]=)          */
          /* DROP Rnn[,Rmm...] */
          do i = 1 to nRegisters
            nn = word(sRegisters,i)
            x = d2x(nn)                /* Base register (0 to F) */
            g.0CBASE.x = ''
            g.0DBASE.x = ''
            call attachDirective g.0XLOC,'DROP  R'nn,1
          end
        end
        otherwise do                   /* (Rnn[+Rnn...]=label)     */
          /* USING label,Rnn[,Rmm...] */
          if isHex(sLabel)             /* (Rnn[+Rnn...]=offset)    */
          then do
            xLoc = d2x(x2d(sLabel))    /* Remove leading zeros */
            sLabel = getLabel(xLoc)    /* Get label from location if any */
            if sLabel = ''             /* If location has no label */
            then sLabel = getLabel(0)'+'||x(xLoc) /* Then use absolute offset */
          end
          else do
            xLoc = getLabel(sLabel)    /* Get location from label */
          end
          dLoc = x2d(xLoc)
          do i = 1 to nRegisters
            nn = word(sRegisters,i)
            x = d2x(nn)                /* Base register (0 to F) */
            g.0CBASE.x = d2x(dLoc)     /* Set base register to location */
            dLoc = dLoc + 4096
          end
          call attachDirective g.0XLOC,'USING' sLabel','using(sRegisters),1
        end
      end
    end
    otherwise do                    /* (label[=offset]) */
      parse var sTag sLabel'='xLoc .
      if isHex(xLoc)
      then call defLabel sLabel,xLoc
      else call defLabel sLabel,g.0XLOC
    end
  end
return

using: procedure
  parse arg sRegisters
  sUsing = 'R'word(sRegisters,1) /* Rnn */
  do i = 2 to words(sRegisters)
    nn = word(sRegisters,i)
    sUsing = sUsing',R'nn        /* Rnn,Rmm,... */
  end
return sUsing

getRegisterList: procedure
  /* Convert a base register list of the form 'Rxx+Ryy+...'
     to just the numeric register numbers 'xx yy ...'
     else return an empty string
  */
  parse arg sRegisters
  sRegisters = translate(sRegisters,' ','+')
  sRegisterList = ''
  do i = 1 to words(sRegisters)
    sRegister = word(sRegisters,i)
    parse var sRegister 'R'nn
    if isNum(nn) & nn >= 0 & nn <= 15
    then sRegisterList = sRegisterList nn
    else return ''
  end
return strip(sRegisterList)

attachDirective: procedure expose g. /* Attach a directive to a location */
  parse arg xLoc,sDirective,bUnderline
  if g.0DIRECTIVE.xLoc.sDirective = '' /* Already added this directive? */
  then do
    g.0DIRECTIVE.xLoc.sDirective = 1   /* Prevent future duplicates */
    call attachLine xLoc,'         'sDirective
    if bUnderline <> ''
    then call attachLine xLoc,'*        'copies('-',length(sDirective))
  end
return

attachSection: procedure expose g. /* Attach a section comment to a location */
  parse arg xLoc,sComment
  call attachLine xLoc,''
  call attachLine xLoc,'*'copies('*',69)'*'
  call attachLine xLoc,'*'copies(' ',69)'*'
  call attachLine xLoc,'*' center(sComment,67) '*'
  call attachLine xLoc,'*'copies(' ',69)'*'
  call attachLine xLoc,'*'copies('*',69)'*'
return

attachComment: procedure expose g. /* Attach a comment to a location */
  parse arg xLoc,sComment
  call attachLine xLoc,''
  call attachLine xLoc,'*'copies('-',69)'*'
  call attachLine xLoc,'*' left(sComment,69)
  call attachLine xLoc,'*'copies('-',69)'*'
  call attachLine xLoc,''
return

attachLine: procedure expose g. /* Attach text to a location */
  parse arg xLoc,sLine
  xLoc = strip(xLoc,'LEADING',0)
  if xLoc = '' then xLoc = 0
  n = g.0DIRECTIVE.xLoc.0          /* Get directive count for this loc */
  if n = ''
  then n = 1
  else n = n + 1
  g.0DIRECTIVE.xLoc.n = sLine
  g.0DIRECTIVE.xLoc.0 = n
return

saveRegisterEquates:
  call saveBanner 'R E G I S T E R S'
  call saveCommentBlock 'General purpose register equates'
  do i = 0 to 15
    call save left('R'i,8) 'EQU   'i
  end
  if g.0VECTOR
  then do
    call saveCommentBlock 'Vector register equates'
    do i = 0 to 31
      call save left('V'i,8) 'EQU   'i
    end
  end
return

saveDSECTs:
  if g.0DSECT.0 > 0
  then do
    call saveBanner 'D S E C T S'
    do i = 1 to g.0DSECT.0
      sDsectName = g.0DSECT.i
      call saveCommentBlock g.0DDESC.i
      call save asm(sDsectName,'DSECT')
      call sortStem 'g.0DDISP.'sDsectName'.' /* Sort by displacement */
      nLastDisp = 0
      do j1 = 1 to sorted.0
        j2 = j1 + 1
        n1 = sorted.j1
        n2 = sorted.j2
        sLabel  = g.0DSECT.sDsectName.n1
        nLength = g.0DLENG.sLabel
        d1      = g.0DDISP.sDsectName.n1
        d2      = g.0DDISP.sDsectName.n2
        if d2 = '' then d2 = d1 + nLength
        nGap = d1 - nLastDisp
        if nGap > 0
        then call save asm(,'DS XL'nGap)
        if nLength = 0
        then sFormat = '0X'
        else do
          if nLength <= (d2 - d1)
          then do
            sFormat = 'XL'nLength
            d1 = d1 + nLength
          end
          else do
            sFormat = '0XL'nLength
          end
        end
        call save asm(sLabel,'DS' sFormat)
        nLastDisp = d1
      end
    end
  end
return

asm: procedure
  arg sLabel,sOp sOperands sComment
  nLabel = max(length(sLabel),8)
  nOp    = max(length(sOp),5)
  nOperands = max(length(sOperands),22)
  sStmt = left(sLabel,nLabel) left(sOp,nOp) left(sOperands,nOperands) sComment
return left(sStmt,71)

saveUndefinedLabels:
  call sortStem 'g.0REFLOC.'
  /* First, detect if there are any undefined labels */
  nLabels = 0
  do i = 1 to sorted.0
    n = sorted.i
    nLoc = g.0REFLOC.n
    if g.0DEF.nLoc = ''
    then nLabels = nLabels + 1
  end
  if nLabels > 0
  then do
    call saveCommentBlock 'Undefined labels'
    call save '* Label    At       Length Ref from By instruction'
    call save '* -------- -------- ------ --------' copies('-',35)
    do i = 1 to sorted.0
      n = sorted.i
      nLoc = g.0REFLOC.n
      if g.0DEF.nLoc = ''
      then do
        xLoc = d2x(nLoc)
        sLabel = getLabel(xLoc)
        xLocRef = g.0REF.nLoc
        n = g.0STMT#.xLocRef
        sStmt = g.0STMT.n
        parse var g.0STMT.n 10 sInst sOperands .
        call save '*' left(sLabel,8) left(xLoc,8),
                  right(g.0CLENG.xLoc,6) right(xLocRef,8),
                  left(sInst,6) sOperands
      end
    end
  end
return nLabels

saveBanner:
  parse arg sComment
  call save ''
  call save copies('*',71)
  call save '*'copies(' ',69)'*'
  call save '*' centre(sComment,67) '*'
  call save '*'copies(' ',69)'*'
  call save copies('*',71)
  call save ''
return

saveCommentBlock:
  parse arg sComment
  call save ''
  call save '*'copies('-',69)'*'
  call save '*' left(sComment,69)
  call save '*'copies('-',69)'*'
  call save ''
return

save: procedure expose g.
  parse arg sStmt
  xLoc = g.0XLOC
  n = getNextStmtNumber()
  nDirectives = g.0DIRECTIVE.xLoc.0
  if isNum(nDirectives) /* If there are any directives for */
  then do /* this location, then include them before the statement */
    do i = 1 to nDirectives
      g.0STMT.n = g.0DIRECTIVE.xLoc.i
      n = getNextStmtNumber()
    end
  end
  g.0STMT#.xLoc = n
  g.0STMT.n = sStmt
  g.0LOC.n = xLoc
return

saveComment: procedure expose g.
  parse arg sStmt
  n = getNextStmtNumber()
  g.0STMT.n = sStmt
return

getNextStmtNumber: procedure expose g.
  n = g.0LINE + 1
  g.0DELTA = g.0DELTA + 1
  if g.0DELTA >= 1000
  then do
    say 'DIS0008I Generated' n 'statements'
    g.0DELTA = 0
  end
  g.0LINE = n
return n

emit: procedure expose g.
  parse arg sLine 1 s71 +71 sRest 100 sInfo
  if sRest = ''  /* if nothing to continue onto the next line */
  then queue sLine
  else do
    queue s71'-                           'sInfo
    queue left('',15)sRest
  end
return


decodeData: procedure expose g.
  arg xData
  if length(xData) = 0 then return
  sData = x2c(xData)
  do until length(sData) = 0
    select
      when g.0TYPE = 'A' then do /* Address */
        parse var sData sChunk +4 sData
        call doAddress sChunk
      end
      when g.0TYPE = 'B' then do /* Bit */
        parse var sData sChunk +1 sData
        call doBit sChunk        /* Bit */
      end
      when g.0TYPE = 'C' then do /* Character */
        call doText sData
        sData = ''
      end
      when g.0TYPE = 'F' then do /* Fullword */
        parse var sData sChunk +4 sData
        call doFullword sChunk
      end
      when g.0TYPE = 'H' then do /* Halfword */
        parse var sData sChunk +2 sData
        call doHalfword sChunk
      end
      when g.0TYPE = 'P' then do /* Packed decimal */
        xData = c2x(sData)
        nPos = verify(xData,'ABCDEF','MATCH') /* Position of sign nibble   */
        if nPos < 1 | nPos > 16 | nPos//2 = 1 /* If position is no good    */
        then do                               /* Then not packed decimal   */
          call doBinary sData                 /* Treat it as binary data   */
          sData = ''
        end
        else do                               /* Valid packed decimal      */
          nChunk = nPos / 2
          parse var sData sChunk +(nChunk) sData
          call doPacked sChunk
        end
      end
      when g.0TYPE = 'S' then do /* S-type address constant */
        call doSCON sData
        sData = ''
      end
      when g.0TYPE = 'X' then do /* Hexadecimal */
        parse var sData sChunk +24 sData
        call doHex sChunk
      end
      otherwise do /* Unspecified data type, so just guess */
        sData = doUnspecified(sData)
      end
    end
  end
return

doSCON: procedure expose g.
  parse arg sData
  xData = c2x(sData)
  nData = length(sData)
  /* If the S-type address constants are adjacent                 */
  /* Then emit: DC   nS(*)                                        */
  /* Else emit: DC   S(X'xxx'(Rnn))                               */
  dLoc = x2d(g.0XLOC)
  nDup = 0
  do i = 1 to length(xData) by 4
    xBaseDisp = substr(xData,i,4)
    nLoc = sLoc(xBaseDisp)
    if nLoc = dLoc /* If this S-type address refers to the current location */
    then do
      nDup = nDup + 1
      if nDup = 1
      then xSconLo = xBaseDisp
    end
    else do /* We have a discontiguity */
      if nDup > 0
      then do /* Emit the S-type address list so far */
        if nDup = 1
        then call saveStmt 'DC','S(*)',x(xBaseDisp),g.0XLOC8 xBaseDisp
        else call saveStmt 'DC',nDup'S(*)',x(xSconLo)'-'||x(xSconHi),g.0XLOC8
        call nextLoc +nDup*2
        nDup = 0
      end
      /* Now emit this discontiguous S-type address */
      call saveStmt 'DC',s(xBaseDisp),x(xBaseDisp),g.0XLOC8 xBaseDisp
      call nextLoc +2
    end
    dLoc = dLoc + 2
    xSconHi = xBaseDisp
  end
  if nDup > 0
  then do
    call saveStmt 'DC',nDup'S(*)',x(xSconLo)'-'||x(xSconHi),g.0XLOC8
    call nextLoc +nDup*2
  end
return

s: procedure             /* S-type address constant */
  arg xBaseReg +1 xDisp +3
return 'S('||x(xDisp)'('r(xBaseReg)'))'

sLoc: procedure expose g.
  arg xBaseReg +1 xDisp +3
  xBase = g.0CBASE.xBaseReg
  if xBase = ''
  then nLoc = 0
  else nLoc = x2d(xBase) + x2d(xDisp)
return nLoc

doAddress: procedure expose g.
  parse arg sData /* No more than 4 bytes */
  nData = length(sData)
  xData = c2x(sData)
  select
    when nData = 4 then do    /* Generate A(label) or AL4(label)     */
      xLoc = d2x(x2d(xData))  /* Remove leading zeros */
      sLabel = getLabel(xLoc)
      if sLabel = ''
      then sLabel = label(xLoc)
      call refLabel sLabel,xLoc
      if isFullwordBoundary()
      then call saveStmt 'DC',a(sLabel),x(xData),g.0XLOC8 xData
      else call saveStmt 'DC',al(sLabel,4),x(xData),g.0XLOC8 xData
    end
    when nData = 3 then do    /* Generate AL3(label)                 */
      xLoc = d2x(x2d(xData))  /* Remove leading zeros */
      sLabel = getLabel(xLoc)
      if sLabel = ''
      then sLabel = label(xLoc)
      call refLabel sLabel,xLoc
      call saveStmt 'DC',al(sLabel,3),x(xData),g.0XLOC8 xData
    end
    otherwise do              /* Generate ALn(decimal)               */
      call saveStmt 'DC',al(xData),x(xData),g.0XLOC8 xData
    end
  end
  call nextLoc +nData
return

doBit: procedure expose g.
  parse arg sData /* No more than 1 byte */
  xData = c2x(sData)
  nData = length(sData)
  call saveStmt 'DC',m(xData),,g.0XLOC8 xData
  call nextLoc nData
return

doFullword: procedure expose g.
  parse arg sData /* No more than 4 bytes */
  xData = c2x(sData)
  nData = length(sData)
  if isFullwordBoundary() & nData = 4
  then call saveStmt 'DC',f(xData),,g.0XLOC8 xData
  else call saveStmt 'DC',fl(xData),,g.0XLOC8 xData
  call nextLoc +nData
return

doHalfword: procedure expose g.
  parse arg sData /* No more than 2 bytes */
  xData = c2x(sData)
  nData = length(sData)
  if isHalfwordBoundary() & nData = 2
  then call saveStmt 'DC',h(xData),,g.0XLOC8 xData
  else call saveStmt 'DC',hl(xData),,g.0XLOC8 xData
  call nextLoc +nData
return

doPacked: procedure expose g.
  parse arg sData
  xData = c2x(sData)
  nData = length(sData)
  call saveStmt 'DC',p(xData),,g.0XLOC8 xData
  call nextLoc +nData
return

doHex: procedure expose g.
  parse arg sData
  xData = c2x(sData)
  nData = length(sData)
  call saveStmt 'DC',xl(xData),,g.0XLOC8 xData
  call nextLoc +nData
return

doUnspecified: procedure expose g.
  parse arg sData
  nFirstNonText = verify(sData,g.0EBCDIC,'NOMATCH')
  nFirstText    = verify(sData,g.0EBCDIC,'MATCH')
/*
              nFirstNonText nFirstText
  ABC.EF      4             1
  .BCDEF      1             2
  ABCDEF      0             1
  ......      1             0

*/
  select
    when nFirstText = 0 then do     /* All binary */
      call doBinary sData
      sData = ''
    end
    when nFirstNonText = 0 then do  /* All text */
      call doText sData
      sData = ''
    end
    when nFirstText = 1 then do     /* Text then binary             */
      if length(sData) <= 4         /* It's probably all binary     */
      then do                       /* x... or xx.. or xxx.         */
        call doBinary sData
        sData = ''
      end
      else do
        sChunk = left(sData,nFirstNonText-1)
        sData = substr(sData,nFirstNonText)
        call doText sChunk
      end
    end
    when nFirstNonText = 1 then do  /* Binary then text             */
      if length(sData) <= 4         /* It's probably all binary     */
      then do                       /* .xxx or ..xx or ...x         */
        call doBinary sData
        sData = ''
      end
      else do
        sChunk = left(sData,nFirstText-1)
        sData = substr(sData,nFirstText)
        call doBinary sChunk
      end
    end
    otherwise do                    /* WTF? */
      say 'DIS0001E Could not parse data "'xData'" at offset' g.0XLOC8
      sData = ''
    end
  end
return sData

doBinary: procedure expose g.
  parse arg sData
  if isOddBoundary()
  then do /* emit the 1st byte so that the rest aligns on an even boundary */
    parse arg sChunk +1 sData
    xChunk = c2x(sChunk)
    call saveStmt 'DC',data(xChunk),,g.0XLOC8 xChunk
    call nextLoc +1
  end
  do while length(sData) > 0
    parse var sData sChunk +16 sData
    xChunk = c2x(sChunk)
    call saveStmt 'DC',data(xChunk),,g.0XLOC8 xChunk
    call nextLoc +length(sChunk)
  end
return

isOddBoundary: procedure expose g.
return g.0LOC//2

isFullwordBoundary: procedure expose g.
return g.0LOC//4 = 0

isHalfwordBoundary: procedure expose g.
return g.0LOC//2 = 0

data: procedure expose g.
  arg xData
  /* Try to generate a human friendly constant */
  nBytes = length(xData)/2
  nBoundary = g.0LOC//4
  select
    when nBoundary = 0 & nBytes = 4 then return fhx(xData) /* fw on fw */
    when nBoundary = 0 & nBytes = 2 then return hx(xData)  /* hw on fw */
    when nBoundary = 2 & nBytes = 2 then return hx(xData)  /* hw on hw */
    when nBytes = 1 then return al(xData) /* single byte */
    otherwise nop
  end
return xl(xData)                          /* multi byte */

a: procedure             /* Address */
  arg xData .
  if datatype(xData,'X')
  then return 'A('x2d(xData)')'
return 'A('xData')'

al: procedure            /* Address with length */
  arg xData,nLen         /* xData can be hex or a label */
  if datatype(xData,'X')
  then return 'AL'length(xData)/2'('x2d(xData)')'
return 'AL'nLen'('xData')'

cl: procedure            /* Character with length */
  parse arg s,n
  if n = '' then n = length(s)
return 'CL'n||quote(s)

f: procedure             /* Fullword */
  arg xData .
return "F'"x2d(xData,8)"'"

fhx: procedure           /* Fullword, halfword or hex */
  arg xData
  nData = x2d(xData,8)
  if abs(nData) > 4096   /* 00001000 or higher */
  then do                /* split fullword into two halfwords */
    parse var xData xH1 +4 xH2 +4 1 x1 +1 x2 +1 x3 +1 x4 +1
    select
      when xH1 = '0000' then return h(xH1)','h(xH2)          /* 0000xxxx */
      when xH2 = '0000' then return h(xH1)','h(xH2)          /* xxxx0000 */
      when x1 = '00' & x3 = '00' then return h(xH1)','h(xH2) /* 00xx00xx */
      otherwise return xl(xData)                             /* xxxxxxxx */
    end
  end
return f(xData)          /* 00000000 to 00001000 --> F'0' to F'4096'*/

fl: procedure            /* Fullword with length */
  arg xData .
return 'FL'length(xData)/2"'"x2d(xData,8)"'"

h: procedure             /* Halfword */
  arg xData .
return "H'"x2d(xData,4)"'"

hl: procedure            /* Halfword with length */
  arg xData .
return 'HL'length(xData)/2"'"x2d(xData,4)"'"

hx: procedure            /* Halfword or hex */
  arg xData
  nData = x2d(xData,8)
  if abs(nData) <= 4096  /* Arbitrary friendly cutoff               */
  then return h(xData)   /* 0000 to 1000 --> H'0' to H'4096'        */
return xl(xData)         /* 1001 to 1FFF --> XL2'1001' to XL2'1FFF' */

p: procedure             /* Packed decimal */
  arg xData .                      /* 19365F */
  nData = length(xData)
  xSign = right(xData,1)           /*      F */
  xData = left(xData,nData-1)      /* 19365  */
  if pos(xSign,'BD') > 0           /* Indicates negative packed decimal */
  then n = -xData
  else n =  xData
return 'PL'nData/2"'"format(n)"'"  /* Number with leading zeros removed */

xl: procedure            /* Hex with length */
  arg xData .
return 'XL'length(xData)/2"'"xData"'"

doText: procedure expose g.
  parse arg sData
  do while length(sData) > 0
    parse var sData sChunk +50 sData
    nChunk = length(sChunk)
    if nChunk <= 6
    then xChunk = c2x(sChunk)
    else xChunk = ''
    if sChunk = ''       /* For all blanks, show CLnnn' ' */
    then call saveStmt 'DC',cl(' ',nChunk),,g.0XLOC8 xChunk
    else do
      sShort = strip(sChunk,'TRAILING')
      nShort = length(sShort)
      if nShort < nChunk /* For trailing blanks, show CLnnn'text' */
      then call saveStmt 'DC',cl(sShort,nChunk),,g.0XLOC8 xChunk
      else call saveStmt 'DC',cl(sChunk),,g.0XLOC8 xChunk
    end
    call nextLoc +length(sChunk)
  end
return

quote: procedure
  parse arg s
  if pos("'",s) > 0 then s = replace("'","''",s)
  if pos("&",s) > 0 then s = replace("&","&&",s)
return "'"s"'"

replace: procedure
  parse arg sFrom,sTo,sText
  nTo = length(sTo)
  n = pos(sFrom,sText)
  do while n > 0
    sText = delstr(sText,n,length(sFrom))
    sText = insert(sTo,sText,n-1)
    n = pos(sFrom,sText,n+nTo)
  end
return sText

decodeCode: procedure expose g.
  arg xData
  nData = length(xData)
  i = 1
  do while i < nData
    xInst = substr(xData,i,12)
    nLen = decodeInst(xInst)
    call nextLoc +trunc(nLen/2)
    i = i + nLen
  end
return

decodeInst: procedure expose g.
  arg 1 a +1 1 aa +2 1 bbbb +4 4 c +1 11 dd +2 0 xInst
/*
   Opcodes can only come from certain places in an instruction:
   Instruction      OpCd Instruction formats using this OpCode format
   ------------     ---- -------------------------------------------------
   aa.......... --> aa   I MII RR RS RX SI SMI SS
   bbbb........ --> bbbb E IE RRD RRE RRF S SIL SSE
   cc.c........ --> ccc  RI RIL SSF
   dd........dd --> dddd RIE RIS RRS RSL RSY RXE RXF RXY Vxx

   So, given 6 bytes of hex, we need to check if there is valid opcode
   for each of these sources. If not, then return a 2-byte constant and move
   the 6-byte instruction window forward by 2.
*/
  ccc  = aa || c
  dddd = aa || dd
  select
    when         g.0INST.aa   <> '' then xOpCode = aa
    when         g.0INST.ccc  <> '' then xOpCode = ccc
    when a='E' & aa <> 'E5' & g.0INST.dddd <> '' then xOpCode = dddd
    when         g.0INST.bbbb <> '' then xOpCode = bbbb /* E5xx and others   */
    otherwise xOpCode = '.' /* Unrecognised opcode: treat as constant  */
  end
  if xOpCode <> '.'
  then g.0INST = g.0INST + 1              /* Instruction count      */
  else g.0TODO = g.0TODO + 1              /* "Bad Instruction" count*/
  sMnemonic = g.0INST.xOpCode             /* Instruction mnemonic   */
  sFormat   = g.0FORM.xOpCode             /* Instruction format     */
  sFlag     = g.0FLAG.xOpCode             /* Instruction flags      */
  sDesc     = g.0DESC.xOpCode             /* Instruction description*/
  sHint     = g.0HINT.xOpCode             /* Operand length hint    */
  nLen      = g.0LENG.sFormat             /* Instruction length     */
  sParser   = g.0PARS.sFormat             /* Instruction parser     */
  sEmitter  = g.0EMIT.sFormat             /* Instruction generator  */
  parse value '' with ,  /* Clear operand fields:                   */
                      B1 B2 B3 B4,        /* Base register          */
                      DH1 DH2,            /* Displacement (high)    */
                      DL1 DL2,            /* Displacement (low)     */
                      D1 D2 D3 D4,        /* Displacement           */
                      I1 I2 I3 I4 I5 I6,  /* Immediate              */
                      L1 L2,              /* Length                 */
                      M1 M2 M3 M4 M5 M6,  /* Mask                   */
                      O1 O2,              /* Operation Code         */
                      RI1 RI2 RI3 RI4,    /* Relative Immediate     */
                      RXB,                /* Vector register MSBs   */
                      R1 R2 R3,           /* Register               */
                      V1 V2 V3 V4,        /* Vector register LSBs   */
                      X1 X2,              /* Index register         */
                      Z                   /* Zero reamining bits    */
  interpret 'parse var xInst' sParser /* 1. Parse the instruction          */
  if RXB <> '' /* If this is a Vector instruction */
  then do      /* Each Vector register is 5-bits wide: 32 registers */
    parse value x2b(RXB) with RXB1 +1 RXB2 +1 RXB3 +1 RXB4 +1
    V1 = RXB1||V1 /* Prepend high order bit to the V1 operand */
    V2 = RXB2||V2 /* Prepend high order bit to the V2 operand */
    V3 = RXB3||V3 /* Prepend high order bit to the V3 operand */
    V4 = RXB4||V4 /* Prepend high order bit to the V4 operand */
  end
  interpret 'g.0TLENG =' sHint        /* 2. Get length hint from xOpCode   */
  interpret 'o =' sEmitter            /* 3. Generate instruction operands  */
  sOperands = space(o,,',')           /* Put commas between operands    */
  sOperands = translate(sOperands,' ',g.0HARDBLANK) /* Soften blanks :) */
  xCode     = left(xInst,nLen)
  sOverlay  = g.0XLOC8 left(xCode,12) sFormat g.0TLENG

  /* Post decode tweaking: extended mnemonics are a bit easier to read  */
  if pos(sFlag,'ACcM') > 0
  then g.0CC = sFlag /* Instruction type that sets condition code       */
  select
    when sMnemonic = 'SVC' then do
      if g.0SVC.I1 \= ''
      then sDesc = g.0SVC.I1
      call saveStmt sMnemonic,sOperands,sDesc,sOverlay
    end
    when sFlag = 'B' then do          /* Branch on condition            */
      sExt = getExt(sMnemonic,g.0CC,M1)
      if sExt <> ''                   /* If an extended mnemonic exists */
      then do
        sUse = g.0CC
        sDesc = g.0DESC.sUse.sExt
        parse var sOperands ','sTarget  /* Discard M1 field               */
        call saveStmt sExt,sTarget,sDesc,sOverlay
      end
      else call saveStmt sMnemonic,sOperands,sDesc,sOverlay
    end
    when sFlag = 'R' then do          /* Branch relative on condition   */
      sTarget = getLabelRel(RI2)
      sExt = getExt(sMnemonic,g.0CC,M1)
      if sExt <> ''                   /* If an extended mnemonic exists */
      then do
        sUse = g.0CC
        sDesc = g.0DESC.sUse.sExt
        call saveStmt sExt,sTarget,sDesc,sOverlay
      end
      else call saveStmt sMnemonic,m(M1)','sTarget,sDesc,sOverlay
    end
    when sFlag = 'S' then do          /* Select (SELR, SELGR, SELFHR)   */
      sExt = getExt(sMnemonic,g.0CC,M4)
      if sExt <> ''                   /* If an extended mnemonic exists */
      then do
        sUse = g.0CC
        sDesc = g.0DESC.sUse.sExt
        nComma = lastpos(',',sOperands)
        sOps = left(sOperands,nComma-1) /* Discard M4 field             */
        call saveStmt sExt,sOps,sDesc,sOverlay
      end
      else call saveStmt sMnemonic,sOperands,sDesc,sOverlay
    end
    when sFlag = 'R4' then do         /* Relative 4-nibble offset       */
      sTarget = getLabelRel(RI2)
      call saveStmt sMnemonic,r(R1)','sTarget,sDesc,sOverlay
    end
    when sFlag = 'R8' then do         /* Relative 8-nibble offset       */
      sTarget = getLabelRel(RI2)
      call saveStmt sMnemonic,r(R1)','sTarget,sDesc,sOverlay
    end
    when sFlag = 'JX' then do         /* Jump on index                  */
      sTarget = getLabelRel(RI2)
      call saveStmt sMnemonic,r(R1)','r(R3)','sTarget,sDesc,sOverlay
    end
    when sFlag = 'CJ' then do         /* Compare and Jump               */
      sExt = g.0EXTC.M3     /* Convert mask to extended mnemonic suffix */
      if sExt <> ''    /* If an extended mnemonic exists for this inst  */
      then do          /* Then rebuild operands without the M3 mask     */
        select         /* These are the only Compare and Jump formats:  */
          when sFormat = 'RIEb'  then o = r(R1) r(R2) getLabelRel(RI4)
          when sFormat = 'RIEc'  then o = r(R1) u(I2) getLabelRel(RI4)
          when sFormat = 'RIS'   then o = r(R1) r(R2) getLabelRel(I2)
          when sFormat = 'RRS'   then o = r(R1) r(R2) db(D4,B4)
          otherwise nop
        end
        sMnemonic = sMnemonic||sExt
        call saveStmt sMnemonic,space(o,,','),sDesc,sOverlay
      end
      else call saveStmt sMnemonic,sOperands,sDesc,sOverlay
    end
    when sFlag = 'O' then do          /* Load/Store on Condition        */
      sExt = g.0EXTO.M3 /* Convert mask to extended mnemonic suffix     */
      if sExt <> ''    /* If an extended mnemonic exists for this inst  */
      then do          /* Then rebuild operands without the M3 mask     */
        select         /* These are the only Load/St on Cond formats:   */
          when sFormat = 'RIEg'  then o = r(R1) s4(I2)
          when sFormat = 'RRFc'  then o = r(R1) r(R2)
          when sFormat = 'RRFc3' then o = r(R1) r(R2)
          when sFormat = 'RSYb'  then o = r(R1) db(DH2||DL2,B2)
          otherwise nop
        end
        sMnemonic = sMnemonic||sExt
        call saveStmt sMnemonic,space(o,,','),sDesc,sOverlay
      end
      else call saveStmt sMnemonic,sOperands,sDesc,sOverlay
    end
    when sFlag = 'RO' then do         /* Rotate (RIEf format)           */
      x345 = I3 || I4 || I5         /* Operands 3, 4 and 5 together     */
      sExt = g.0EXTR.sMnemonic.x345 /* Convert operands to ext mnemonic */
      if sExt <> ''    /* If an extended mnemonic exists                */
      then do          /* Then rebuild operands using the mnemonic      */
        sDesc = g.0DESC.sMnemonic.x345
        call saveStmt sExt,r(R1)','r(R2),sDesc,sOverlay
        sMnemonic = sExt
      end
      else do
        d4 = s2(I4)                  /* Get the 4th operand in decimal */
        if d4 < 0                    /* If the zero flag bit is set    */
        then do                      /* Append Z to the mnemonic...    */
          d4 = d4 + 128                  /* Remove zero flag bit */
          o = r(R1) r(R2) s2(I3) d4 s2(I5) /* Rebuild the operands */
          call saveStmt sMnemonic'Z',space(o,,','),sDesc,sOverlay
        end
        else call saveStmt sMnemonic,sOperands,sDesc,sOverlay
      end
    end
    otherwise do
      call saveStmt sMnemonic,sOperands,sDesc,sOverlay
    end
  end
  if g.0OPTION.STAT
  then call doStats sFormat,sMnemonic,xOpCode
return nLen

/* Target operand length hint calculations */
hM: procedure expose R1 R3 /* Target length for multiple register load/store */
  arg n
  nR1 = x2d(R1)
  nR3 = x2d(R3)
  if nR1 <= nR3
  then nLM = ( 1 + nR3 - nR1) * n /* LM R2,R4,xxx   -> 3 registers  = 12 */
  else nLM = (17 + nR3 - nR1) * n /* LM R14,R12,xxx -> 15 registers = 60 */
return nLM

doStats: procedure expose g.
  parse arg sFormat,sMnemonic,xOpCode
  if xOpCode \= '.' /* If it is a valid instruction */
  then do
    /* Instruction format statistics */
    if g.0FI.sFormat = ''   /* If format not seen before */
    then do
      n = g.0FN.0 + 1       /* Increment format count */
      g.0FN.0 = n
      g.0FC.0 = n
      g.0FN.n = sFormat     /* This format's name  */
      g.0FI.sFormat = n     /* This format's index */
      g.0FC.n = 1           /* This format's count */
    end
    else do
      n = g.0FI.sFormat     /* Get this format's index */
      g.0FC.n = g.0FC.n + 1 /* Increment format count */
    end
    /* Instruction mnemonic statistics */
    if g.0MI.sMnemonic = '' /* If mnemonic not seen before */
    then do
      n = g.0MN.0 + 1       /* Increment mnemonic name count */
      g.0MN.0 = n
      g.0MC.0 = n
      g.0MN.n = sMnemonic   /* This mnemonic's name  */
      g.0MI.sMnemonic = n   /* This mnemonic's index */
      g.0MC.n = 1           /* This mnemonic's count */
      g.0MF.n = sFormat     /* This mnemonic's format */
      g.0ML.sFormat = g.0ML.sFormat sMnemonic /* List of mnemonics */
    end
    else do
      n = g.0MI.sMnemonic   /* Get this mnemonic's index */
      g.0MC.n = g.0MC.n + 1 /* Increment mnemonic count */
    end
  end
return

inSet: procedure
  parse arg sArg,sSet
return wordpos(sArg,sSet) > 0

saveStmt: procedure expose g.
  parse arg sMnemonic,sOperands,sComment,sOverlay
  sLabel = getLabel(g.0XLOC)
  if sLabel <> ''
  then do
    nLoc = x2d(g.0XLOC)
    g.0DEF.nLoc = 1           /* Remember a label is assigned to this location*/
  end
  nMnemonic = max(length(sMnemonic),5)
  sInst = left(sMnemonic,nMnemonic) sOperands
  nInst = max(length(sInst),29)
  sStmt = left(sLabel,8),
          left(sInst,nInst),
          sComment
  call save overlay(sOverlay,sStmt,100)
return

db: procedure expose g.       /* Unsigned 12-bit displacement off base */
  arg xDisp,xBaseReg
  sLabel = getLabelDisp(xDisp,xBaseReg)
  if sLabel = ''
  then do /* No known label found, so return explicit operands */
    if xBaseReg = 0
    then return u(xDisp) /* Base register defaults to 0 */
    else return u(xDisp)'('r(xBaseReg)')'
  end
return sLabel

ldb: procedure expose g.      /* Signed 20-bit displacement off base */
  arg xDisp,xBaseReg
  sLabel = getLabelDisp(xDisp,xBaseReg)
  if sLabel = ''
  then do /* No known label found, so return explicit operands */
    if xBaseReg = 0
    then return s5(xDisp) /* Base register defaults to 0 */
    else return s5(xDisp)'('r(xBaseReg)')'
  end
return sLabel

dbs: procedure expose g.      /* Signed 12-bit shift */
  arg xDisp,xBaseReg
  if xBaseReg = 0
  then return s3(xDisp)                  /* Displacement only */
  else return s3(xDisp)'('r(xBaseReg)')' /* Displacement off a base register */
return

ldbs: procedure expose g.     /* Signed 20-bit shift */
  arg xDisp,xBaseReg
  if xBaseReg = 0
  then return s5(xDisp)                  /* Displacement only */
  else return s5(xDisp)'('r(xBaseReg)')' /* Displacement off a base register  */
return

dlb: procedure expose g. /* 12-bit displacement off base register with length */
  arg xDisp,xLength,xBaseReg
  sLabel = getLabelDisp(xDisp,xBaseReg,xLength)
  if sLabel = '' /* No known label found, so return explicit operands */
  then return u(xDisp)'('l(xLength)','r(xBaseReg)')'
return sLabel'('l(xLength)')'

dvb: procedure /* Displacement off a base register with vector register */
  arg xDisp,xVectorReg,xBaseReg
return x(xDisp)'('v(xVectorReg)','r(xBaseReg)')'

dxb: procedure expose g. /* 12-bit displacement off base reg with index reg */
  arg xDisp,xIndexReg,xBaseReg
  if xIndexReg = 0 & xBaseReg = 0 /* it's a displacement only */
  then return u(xDisp)
  if xBaseReg  = 0 /* it's a displacement from an index register only */
  then do
    sLabel = getLabelDisp(xDisp,xIndexReg)
    if sLabel = ''
    then return u(xDisp)'('xr(xIndexReg)')' /* LA Rn,X'xxx'(Rx)             */
    else return sLabel                      /* LA Rn,label                  */
  end
  /* A base register is specified: either CSECT or DSECT */
  sLabel = getLabelDisp(xDisp,xBaseReg)
  if xIndexReg = 0 /* it's a displacement from a base register only */
  then do
    if sLabel = ''
    then return u(xDisp)'(,'r(xBaseReg)')'  /* LA Rn,X'xxx'(,Rb)            */
    else return sLabel                      /* LA Rn,label                  */
  end
                   /* it's a displacement from a base WITH index register */
  if sLabel = ''
  then return u(xDisp)'('xr(xIndexReg)','r(xBaseReg)')' /* LA Rn,X'xxx'(Rx,Rb)*
return sLabel'('xr(xIndexReg)')'            /* LA Rn,label(Rx)              */

ldxb: procedure expose g. /* 20-bit displacement off base reg with index reg */
  arg xDisp,xIndexReg,xBaseReg
  if xIndexReg = 0 & xBaseReg = 0 /* it's a displacement only */
  then return s5(xDisp)
  if xBaseReg  = 0 /* it's a displacement from an index register */
  then return s5(xDisp)'('xr(xIndexReg)')'
  /* A base register is specified: either CSECT or DSECT */
  sLabel = getLabelDisp(xDisp,xBaseReg)
  if xIndexReg = 0 /* it's a displacement from a base register only */
  then do
    if sLabel = ''
    then return s5(xDisp)'(,'r(xBaseReg)')'
    else return sLabel
  end
                   /* it's a displacement from a base with index register */
  if sLabel = ''
  then return s5(xDisp)'('xr(xIndexReg)','r(xBaseReg)')'
return sLabel'('xr(xIndexReg)')'

getLabelDisp: procedure expose g.
  arg xDisp,xBaseReg,xLength
  /* xDisp is a positive offset in bytes from xBaseReg */
  sLabel = ''
  select
    when g.0CBASE.xBaseReg \= '' then do /* This is a CSECT base register */
      xLoc = g.0CBASE.xBaseReg
      nTarget = x2d(xLoc) + x2d(xDisp)
      xTarget = d2x(nTarget)
      if nTarget < g.0LOC /* If target is before the current location */
      then do /* Remember so we can apply labels later */
        n = g.0BACKREF.0 + 1
        g.0BACKREF.0 = n
        g.0BACKREF.n = xTarget
      end
      if getLabel(xTarget) = ''  /* If a label is not already assigned */
      then call refLabel label(xTarget),xTarget
      sLabel = getLabel(xTarget)
    end
    when g.0DBASE.xBaseReg \= '' then do /* This is a DSECT base register */
      sLabel = getDsectLabel(xDisp,xBaseReg,xLength)
      if xLength \= ''
      then do
        nLength = l(xLength)           /* Proposed length of this field */
        if nLength > g.0DLENG.sLabel   /* If proposed > current length */
        then g.0DLENG.sLabel = nLength /* Then use the larger length */
      end
    end
    otherwise nop                /* Unnamed base+displacement */
  end
return sLabel

getDsectLabel: procedure expose g.
  arg xDisp,xBaseReg,xLength
  sDsectName = g.0DBASE.xBaseReg       /* DSECT name for this base register */
  nLocn = g.0DLOCN.xBaseReg            /* Offset into DSECT for this base reg */
  xDisp = d2x(x2d(xDisp)+nLocn)        /* Offset into DSECT of this label */
  sLabel = g.0DSLAB.sDsectName.xDisp   /* Get existing DSECT label if any */
  if sLabel = ''
  then do                              /* Create a label for this field */
    sLabel = sDsectName'_'xDisp        /* Label format: dsect_xxx */
    g.0DSLAB.sDsectName.xDisp = sLabel /* Remember label by DSECT and disp */
    if xLength \= ''                   /* If instruction has length operand */
    then g.0DLENG.sLabel = l(xLength)  /* Assign known field length */
    else g.0DLENG.sLabel = 0           /* Else it becomes "name DS 0X" */
    n = g.0DSECT.sDsectName.0          /* Number of fields in this DSECT */
    if n = '' then n = 0               /* If no fields yet then count = 0 */
    n = n + 1                          /* Increment number of fields */
    g.0DSECT.sDsectName.n = sLabel     /* Set label for field n */
    g.0DSECT.sDsectName.0 = n          /* Number of fields */
    g.0DDISP.sDsectName.n = x2d(xDisp) /* Decimal displacement of field */
    g.0DDISP.sDsectName.0 = n          /* Number of fields for sorting later */
  end
return sLabel


hint: procedure expose g. /* Operand length hint */
  /* Hint() is called as each instruction is being parsed and sets the */
  /* length in bytes of the field referenced by base+disp.  It always */
  /* returns '' so as not to add spurious characters to the generated */
  /* assembler instruction */
  arg nLength,xBaseReg,xDisp
  select
    when g.0CBASE.xBaseReg \= '' then do /* Base+Disp addresses CSECT */
      xBase = g.0CBASE.xBaseReg
      nOffset = x2d(xDisp)
      nTarget = x2d(xBase) + nOffset
      xTarget = d2x(nTarget)
      sTarget = getLabel(xTarget)
      if nLength \= ''      /* If instruction has an implicit operand length */
      then do
        if g.0CLENG.xTarget = ''
        then g.0CLENG.xTarget = nLength
        else g.0CLENG.xTarget = max(g.0CLENG.xTarget,nLength)
      end
    end
    when g.0DBASE.xBaseReg \= '' then do /* Base+Disp addresses DSECT */
      if nLength \= ''      /* If instruction has an implicit operand length */
      then sLabel = getDsectLabel(xDisp,xBaseReg,d2x(nLength))
      else sLabel = getDsectLabel(xDisp,xBaseReg)
      if nLength > g.0DLENG.sLabel   /* If proposed > current length */
      then g.0DLENG.sLabel = nLength /* Then use the larger length */
    end
    otherwise nop                        /* No USING for this base register */
  end
return ''

l: procedure   /* Length */
  arg xData .
  n = x2d(xData)
return n+1

ml: procedure expose g.  /* Mask Length e.g. '0111' length is 3 */
  arg xData .
return g.0MASK.xData

m: procedure   /* 1-nibble bit mask */
  arg xData .
return "B'"x2b(xData)"'"

om: procedure  /* Optional 1-nibble bit mask */
  arg xData .
  if xData = '0'
  then return ''
return "B'"x2b(xData)"'"

r: procedure   /* 1-nibble register R0 to R15 */
  arg xData .
return 'R'x2d(xData)

s2: procedure  /* Signed 8-bit integer */
  arg xData .
return x2d(xData,2)

s3: procedure  /* Signed 12-bit integer */
  arg xData .
return x2d(xData,2)

s4: procedure  /* Signed 32-bit integer */
  arg xData .
return x2d(xData,4)

s5: procedure expose g.  /* Signed 20-bit integer */
  arg xData .
return x2d(xData,5)

s8: procedure  /* Signed 64-bit integer */
  arg xData .
return x2d(xData,8)

u: procedure expose g.  /* Unsigned integer */
  arg xData .
  n = x2d(xData)
  if n < 64 then return n       /* 00 to 3F: return a decimal        */
  if n = 64 then return "C'"g.0HARDBLANK"'" /* 40: return hard blank */
  sData = x2c(xData)            /* 41 to FF                          */
  if isText(sData)
  then return 'C'quote(sData)   /* Return character if text          */
return "X'"xData"'"             /* else return hex                   */

v: procedure expose g.  /* 1-nibble vector register V0 to V31        */
  arg xData .     /* Already has the most significant bit prepended  */
  g.0VECTOR = 1   /* Remember to emit vector register equeates later */
return 'V'x2d(xData)

x: procedure   /* Hexadecimal */
  arg xData .
return "X'"xData"'"

xr: procedure  /* Index register */
  arg xData .
  n = x2d(xData)
  if n = 0
  then return ''
return 'R'n

getLabelRel: procedure expose g.
  arg xHalfwords . /* xHalfwords is a signed displacement in halfwords */
  if length(xHalfwords) > 4
  then nOffset = 2 * x2d(xHalfwords,8)  /* xxxxxxxx */
  else nOffset = 2 * x2d(xHalfwords,4)  /* xxxx     */
  nTarget = g.0LOC + nOffset
  if nTarget < 0 then nTarget = 0
  xTarget = d2x(nTarget)
  if nOffset < 0 & getLabel(xTarget) = '' /* If unlabeled back reference */
  then do /* Remember so we can apply labels later */
    n = g.0BACKREF.0 + 1
    g.0BACKREF.0 = n
    g.0BACKREF.n = xTarget
  end
  if getLabel(xTarget) = ''  /* If a label is not already assigned */
  then call refLabel label(xTarget),xTarget
return getLabel(xTarget)

getLabel: procedure expose g.
  arg xLoc
return g.0LABEL.xLoc

getLocation: procedure expose g. /* Technically the same as getLabel() */
  arg sLabel
return g.0LABEL.sLabel

isReferredTo: procedure expose g.
  parse arg xLoc
  nLoc = x2d(xLoc)
return g.0REF.nLoc \= ''

defLabel: procedure expose g. /* Explicitly define a label for a location */
  parse arg sLabel,xLoc
  nLoc = x2d(xLoc)
  xLoc = d2x(nLoc)            /* Remove leading zeros from xLoc */
  call setLabel sLabel,xLoc   /* Assign a label to location */
  g.0DEF.nLoc = 1             /* Remember this location has a label */
return

refLabel: procedure expose g. /* Implicitly define a referenced label */
  parse arg sLabel,xLoc
  nLoc = x2d(xLoc)
  xLoc = d2x(nLoc)            /* Remove leading zeros from xLoc */
  call setLabel sLabel,xLoc   /* Assign a label to location */
  if g.0REF.nLoc = ''
  then do                     /* Add to list of locations referred to */
    g.0REF.nLoc = g.0XLOC     /* Remember this location was referenced */
    n = g.0REFLOC.0 + 1
    g.0REFLOC.n = nLoc        /* Location in decimal so it can be sorted */
    g.0REFLOC.0 = n
  end
return

setLabel: procedure expose g.
  parse arg sLabel,xLoc
  xLoc = d2x(x2d(xLoc))       /* Remove leading zeros from xLoc */
  g.0LABEL.xLoc = sLabel      /* Assign a label to this location */
  g.0LABEL.sLabel = xLoc      /* Facilitate retrieving location of a label */
return

label: procedure expose g.
  parse arg xLoc
return 'L'xLoc

isText: procedure expose g.
  parse arg sData
return verify(sData,g.0EBCDIC,'NOMATCH') = 0

isHex: procedure expose g.
  parse arg xData
return xData \= '' & datatype(xData,'X')

isNum: procedure expose g.
  parse arg nData
return datatype(nData,'WHOLE')

sortWords: procedure expose sorted.
  parse arg sWords,bAscending
  array.0 = words(sWords)
  do i = 1 to array.0
    array.i = word(sWords,i)
  end
  call sortStem 'array.',bAscending
  sSorted = ''
  do i = 1 to sorted.0
    n = sorted.i
    sSorted = sSorted word(sWords,n)
  end
return strip(sSorted)

sortStem:
  parse arg stem,ascending
return quickSort(stem,ascending)

quickSort: procedure expose (stem) sorted. g.
  /* Perform a quick sort without modifying the passed stem.
     Instead, return a fixed "sorted." stem containing indexes
     into the passed stem that, if traversed, would access the
     passed stem in the desired order.
     For example:
       in.0 = 3      -->   sorted.0 = 3 (number of items)
       in.1 = 'the'        sorted.1 = 2 (cat)
       in.2 = 'cat'        sorted.2 = 3 (sat)
       in.3 = 'sat'        sorted.3 = 1 (the)
  */
  parse arg array,ascending
  ascending = (ascending <> 0)
  bAlreadySorted = 1
  /* Initialise sorted. array indexes */
  drop sorted.
  sorted.0 = value(array'0') /* Number of items to be sorted */
  if \datatype(sorted.0,'WHOLE') then sorted.0 = 0
  do i = 1 to sorted.0
    sorted.i = i
  end
  if sorted.0 <= 1
  then return bAlreadySorted
  /* Push (1,number of items) onto stack  */
  s = 1               /* Stack pointer      */
  L.1 = 1             /* Left window bound  */
  R.1 = sorted.0      /* Right window bound */
  do while s <> 0
    /* Pop (L,R) from stack */
    L = L.s
    R = R.s
    s = s - 1
    do until L >= R
      i = L
      j = R
      mid = (L + R) % 2
      middleItem = value(array||sorted.mid)
      do until i > j
        if ascending
        then do
          do while value(array||sorted.i) < middleItem
            i = i + 1
          end
          do while middleItem < value(array||sorted.j)
            j = j - 1
          end
        end
        else do
          do while value(array||sorted.i) > middleItem
            i = i + 1
          end
          do while middleItem > value(array||sorted.j)
            j = j - 1
          end
        end
        if i <= j
        then do /* Swap i and j items */
          bAlreadySorted = 0
          p = sorted.i
          sorted.i = sorted.j
          sorted.j = p
          i = i + 1
          j = j - 1
        end
      end
      if i < R
      then do /* Push i and R onto stack */
        s = s + 1
        L.s = i
        R.s = R
      end
      R = j
    end
  end
return bAlreadySorted

prolog:
  g. = ''
  g.0INST   = 0       /* Number of instructions emitted                  */
  g.0TODO   = 0       /* Number of bad instructions (TODO's) emitted     */
  g.0HARDBLANK = 'ff'x /* Hard blank to help with parsing                */
  g.0DELTA  = 0       /* Progress counter                                */
  g.0VECTOR = 0       /* Assume no vector register equates are required  */
  g.0FN.0   = 0       /* Instruction format count                        */
  g.0MN.0   = 0       /* Instruction mnemonic count                      */
  g.0DSECT.0 = 0      /* DSECT count                                     */
  g.0REFLOC.0 = 0     /* Number of referenced locations                  */
  call setLoc 0       /* Location counter from start of module (integer) */
  g.0ISCODE = 1       /* 1=Code 0=Data                                   */
  do i = 1 until sourceline(i) = 'BEGIN-FORMAT-DEFINITIONS'
  end
  do i = i+1 while sourceline(i) <> 'END-FORMAT-DEFINITIONS'
    sLine = sourceline(i)
    parse var sLine sType nLen sTemplate
    call addFormat sType,nLen,sTemplate
  end
  do i = i while sourceline(i) <> 'BEGIN-INSTRUCTION-DEFINITIONS'
  end
  do i = i+1 while sourceline(i) <> 'END-INSTRUCTION-DEFINITIONS'
    sLine = sourceline(i)
    parse var sLine sMnemonic xOpCode sFormat sFlag sDesc '='sHint
    call addInst sMnemonic,xOpCode,sFormat,sFlag,sDesc,sHint
  end
  do i = i while sourceline(i) <> 'BEGIN-EXTENDED-BRANCH-MNEMONICS'
  end
  do i = i+1 while sourceline(i) <> 'END-EXTENDED-BRANCH-MNEMONICS'
    sLine = sourceline(i)
    parse var sLine sUse xMask sBC sBCR sBIC sBRC sBRCL sDesc
    call addExt sUse,xMask,sBC,sBCR,sBIC,sBRC,sBRCL,sDesc
  end
  do i = i while sourceline(i) <> 'BEGIN-EXTENDED-SELECT-MNEMONICS'
  end
  do i = i+1 while sourceline(i) <> 'END-EXTENDED-SELECT-MNEMONICS'
    sLine = sourceline(i)
    parse var sLine sUse xMask sSELR sSELGR sSELFHR sDesc
    call addExtSelect sUse,xMask,sSELR,sSELGR,sSELFHR,sDesc
  end
  do i = i while sourceline(i) <> 'BEGIN-SVC-LIST'
  end
  do i = i+1 while sourceline(i) <> 'END-SVC-LIST'
    sLine = sourceline(i)
    parse var sLine xSVC sZOSSVC
    call addSVC xSVC,sZOSSVC
  end
  /* Number of 1 bits in a 4-bit mask */
  g.0MASK.0 = 0
  g.0MASK.1 = 1
  g.0MASK.2 = 1
  g.0MASK.3 = 2
  g.0MASK.4 = 1
  g.0MASK.5 = 2
  g.0MASK.6 = 2
  g.0MASK.7 = 3
  g.0MASK.8 = 1
  g.0MASK.9 = 2
  g.0MASK.A = 2
  g.0MASK.B = 3
  g.0MASK.C = 2
  g.0MASK.D = 3
  g.0MASK.E = 3
  g.0MASK.F = 4
  /* Compare Immediate and Branch extended mnemonic suffixes */
                                /* Equal             */
                                /* |Low              */
                                /* ||High            */
                                /* |||Ignored        */
                                /* ||||              */
                                /* VVVV              */
  call addExtCompare '2','H'    /* 0010              */
  call addExtCompare '4','L'    /* 0100              */
  call addExtCompare '6','NE'   /* 0110              */
  call addExtCompare '8','E'    /* 1000              */
  call addExtCompare 'A','NL'   /* 1010              */
  call addExtCompare 'C','NH'   /* 1100              */

  /* Load/Store on Condition extended mnemonic suffixes      */
                                /* Equal             */
                                /* |Low              */
                                /* ||High            */
                                /* |||One|Overflow   */
                                /* ||||              */
                                /* VVVV              */
  call addExtOnCond  '1','O'    /* 0001              */
  call addExtOnCond  '2','H'    /* 0010              */
  call addExtOnCond  '4','L'    /* 0100              */
  call addExtOnCond  '7','NE'   /* 0111              */
  call addExtOnCond  '8','E'    /* 1000              */
  call addExtOnCond  'B','NL'   /* 1011              */
  call addExtOnCond  'D','NH'   /* 1101              */
  call addExtOnCond  'E','NH'   /* 1110              */

  /* Extended mnemonics for Rotate instrucions               */
  /*           ---Mnemonic---   --Operands--                 */
  /*           Extended Base    I3     I4 I5  Desc           */
  call addRot 'NHHR'  ,'RNSBG' ,00,    31,00,'And High (H<-H)'
  call addRot 'NHLR'  ,'RNSBG' ,00,    31,32,'And High (H<-L)'
  call addRot 'NLHR'  ,'RNSBG' ,32,    63,32,'And High (L<-H)'
  call addRot 'XHHR'  ,'RXSBG' ,00,    31,00,'Exclusive-Or High (H<-H)'
  call addRot 'XHLR'  ,'RXSBG' ,00,    31,32,'Exclusive-Or High (H<-L)'
  call addRot 'XLHR'  ,'RXSBG' ,32,    63,32,'Exclusive-Or High (L<-H)'
  call addRot 'OHHR'  ,'ROSBG' ,00,    31,00,'Or High (H<-H)'
  call addRot 'OHLR'  ,'ROSBG' ,00,    31,32,'Or High (H<-L)'
  call addRot 'OLHR'  ,'ROSBG' ,32,    63,32,'Or High (L<-H)'
  call addRot 'LHHR'  ,'RISBHG',00,128+31,00,'Load (H<-H)'
  call addRot 'LHLR'  ,'RISBHG',00,128+31,32,'Load (H<-L)'
  call addRot 'LLHFR' ,'RISBLG',00,128+31,32,'Load (L<-H)'
  call addRot 'LLHHHR','RISBHG',16,128+31,00,'Load Logical Halfword (H<-H)'
  call addRot 'LLHHLR','RISBHG',16,128+31,32,'Load Logical Halfword (H<-L)'
  call addRot 'LLHLHR','RISBLG',16,128+31,32,'Load Logical Halfword (L<-H)'
  call addRot 'LLCHHR','RISBHG',24,128+31,00,'Load Logical Character (H<-H)'
  call addRot 'LLCHLR','RISBHG',24,128+31,32,'Load Logical Character (H<-L)'
  call addRot 'LLCLHR','RISBLG',24,128+31,32,'Load Logical Character (L<-H)'

  /* EBCDIC characters that can typically be displayed by ISPF EDIT */
  g.0EBCDIC  =        '40'x        ||, /*            */
               xrange('4A'x,'50'x) ||, /* ¢.<(+|&    */
               xrange('5A'x,'61'x) ||, /* !$*);^-/   */
               xrange('6A'x,'6F'x) ||, /* |,%_>?     */
               xrange('7A'x,'7F'x) ||, /* :#@'="     */
               xrange('81'x,'89'x) ||, /* abcdefghi  */
               xrange('91'x,'99'x) ||, /* jklmnopqr  */
               xrange('A1'x,'A9'x) ||, /* ~stuvwxyz  */
                      'AD'x        ||, /* [          */
                      'BD'x        ||, /* ]          */
               xrange('C0'x,'C9'x) ||, /* {ABCDEFGHI */
               xrange('D0'x,'D9'x) ||, /* }JKLMNOPQR */
                      'E0'x        ||, /* \          */
               xrange('E2'x,'E9'x) ||, /* STUVWXYZ   */
               xrange('F0'x,'F9'x)     /* 0123456789 */

  address TSO 'SUBCOM ISREDIT'
  g.0EDITENV = rc = 0
  if g.0EDITENV
  then do /* Direct output to a temporary dataset and then edit it */
    address ISREDIT
    'MACRO (sArgs)'
    if rc <> 0 /* If not already editing a file */
    then do    /* Then edit a temporary file and insert an AMBLIST job */
      sTempFile = getTempFileName()'E'
      call quietly 'ALLOCATE FILE(OUT) DATASET('sTempFile')',
                   'RECFM(V B) BLKSIZE(27920) LRECL(259)',
                   'SPACE(1,1) TRACKS REUSE'
      call buildJob sDsn sMod
      address ISPEXEC 'EDIT DATASET('sTempFile')'
      call quietly 'DELETE' sTempFile
      exit
    end
    '(member) = MEMBER'   /* Member currently being edited */
    '(dataset) = DATASET' /* Dataset currently being edited */
    '(lines) = LINENUM .ZLAST' /* Number of lines being edited */
    nPri = lines * 10
    nSec = lines
    address ISPEXEC 'CONTROL ERRORS RETURN'
    g.0TEMPDSN = getTempFileName()
    call quietly 'ALLOCATE FILE(OUT) DATASET('g.0TEMPDSN')',
                 'RECFM(V B) BLKSIZE(27920) LRECL(259)',
                 'SPACE('nPri','nSec') AVBLOCK(130) REUSE'
    g.0LINE = 0
    g.0BACKREF.0 = 0
    g.0ARGS = translate(sArgs)
    call getOptions
  end
return

getOptions:
  parse var g.0ARGS '('sOptions
  g.0OPTION.TEST = 0
  g.0OPTION.STAT = 0
  do i = 1 to words(sOptions)
    sOption = word(sOptions,i)
    interpret 'g.0OPTION.'sOption '= 1'
  end
return

buildJob:
  arg sDsn sMod .
  if sDsn = '' then sDsn = 'SYS1.LPALIB'
  if sMod = '' then sMod = 'IEFBR14'
  sJob = left(userid()'A',8)
  queue '//'sJob "JOB ,'AMBLIST" sMod"',CLASS=U,MSGCLASS=T,NOTIFY=&SYSUID"
  queue '//STEP1   EXEC PGM=AMBLIST'
  queue '//SYSPRINT  DD SYSOUT=*'
  queue '//SYSLIB    DD DISP=SHR,DSN='sDsn
  queue '//SYSIN     DD *'
  queue '  LISTLOAD  DDN=SYSLIB,OUTPUT=MODLIST,MEMBER='sMod
  queue '/*'
  queue '//'
  do i = 1 until sourceline(i) = 'BEGIN-JCL-COMMENTS'
  end
  do i = i+1 while sourceline(i) <> 'END-JCL-COMMENTS'
    sLine = sourceline(i)
    parse var sLine 4 sComment +66 .
    queue '//*' sComment
  end
  address TSO 'EXECIO' queued() 'DISKW OUT (FINIS'
return

Epilog:
  address TSO 'EXECIO' queued() 'DISKW OUT (FINIS'
  if g.0EDITENV
  then do
    call quietly 'FREE FILE(OUT)'
    address ISPEXEC 'EDIT DATASET('g.0TEMPDSN')'
    call quietly 'DELETE' g.0TEMPDSN
  end
  'RESET FIND'
return

getTempFileName: procedure expose g.
  yymmdd = substr(date('STANDARD'),3)
  parse value time('LONG') with hh':'mm':'ss'.'uuuuuu
return 'DA.D'yymmdd'.T'hh||mm||ss'.S'uuuuuu

quietly: procedure expose g. o.
  parse arg sCommand
  rc = outtrap('o.')
  address TSO sCommand
  g.0RC = rc
  rc = outtrap('off')
return

addFormat: procedure expose g.
  parse arg sFormat,nLength,sParseTemplate
  sParseTemplate = space(sParseTemplate)
  if isNum(nLength)
  then do
    g.0LENG.sFormat = nLength
    g.0PARS.sFormat = sParseTemplate
    /* Validate the template format */
    nSum = 0
    do i = 1 to words(sParseTemplate)
      sToken = word(sParseTemplate,i)
      if left(sToken,1) = '+'
      then nSum = nSum + sToken
    end
    if nLength <> nSum
    then do
      say 'DIS0002E Format' sFormat':' sParseTemplate
      say '         Template length ('nSum') does not match',
                   'instruction length ('nLength')'
    end
  end
  else do
    g.0EMIT.sFormat = sParseTemplate
  end
return

addInst: procedure expose g.
  parse arg sMnemonic,xOpCode,sFormat,sFlag,sDesc,sHint
  if g.0MNEM.sMnemonic <> ''
  then say 'DIS0003E Already defined:' sMnemonic 'as' g.0MNEM.sMnemonic
  g.0MNEM.sMnemonic = xOpCode
  if g.0INST.xOpCode <> ''
  then say 'DIS0004E Already defined:' xOpCode sMnemonic sFormat sFlag sDesc
  if g.0LENG.sFormat = ''
  then say 'DIS0005E Format' sFormat 'is not defined (opcode='xOpCode')'
  g.0INST.xOpCode = sMnemonic
  g.0FORM.xOpCode = sFormat
  g.0FLAG.xOpCode = sFlag
  sDesc = strip(sDesc)
  g.0DESC.xOpCode = sDesc
  g.0DESC.sMnemonic = sDesc
  if sHint = ''
  then g.0HINT.xOpCode = "''"             /* No target length hint */
  else g.0HINT.xOpCode = sHint            /* Target length hint expression */
return

addRot: procedure expose g.
  parse arg sExt,sBaseMnemonic,I3,I4,I5,sDesc
  x345 = d2x(I3,2)d2x(I4,2)d2x(I5,2)
  g.0EXTR.sBaseMnemonic.x345 = sExt
  g.0DESC.sBaseMnemonic.x345 = sDesc
return

genInst: procedure expose g.
  parse arg xOpCode,sMnemonic,sFormat,sFlag,sDesc
  /* Generate test harness instruction */
  parse value '' with ,                   /* Clear operand fields:  */
                      B1 B2 B3 B4,        /* Base register          */
                      DH1 DH2,            /* Displacement (high)    */
                      DL1 DL2,            /* Displacement (low)     */
                      D1 D2 D3 D4,        /* Displacement           */
                      I1 I2 I3 I4 I5 I6,  /* Immediate              */
                      L1 L2,              /* Length                 */
                      M1 M2 M3 M4 M5 M6,  /* Mask                   */
                      O1 O2,              /* Operation Code         */
                      RI1 RI2 RI3 RI4,    /* Relative Immediate     */
                      RXB,                /* Vector register MSBs   */
                      R1 R2 R3,           /* Register               */
                      V1 V2 V3 V4,        /* Vector register LSBs   */
                      X1 X2               /* Index register         */
  xInst = '000000000000' /* Pseudo instruction hex */
  interpret 'parse var xInst' g.0PARS.sFormat   /* Parse the instruction */
  xOpCode = g.0OPCD.sMnemonic
  /* Fix-ups for those instructions that cannot have all zero operands */
  select
    when wordpos(sMnemonic,'KMA KMCTR') > 0 then do
      R1 = 2
      R2 = 4
      R3 = 6
    end
    when wordpos(sMnemonic,'KIMD KLMD') > 0 then do
      R2 = 2
    end
    when left(sMnemonic,2) = 'KM' | sMnemonic = 'PRNO' then do
      R1 = 2
      R2 = 2
    end
    when wordpos(sMnemonic,'PKU') > 0 then do
      L2 = 1
    end
    when wordpos(sMnemonic,'UNPKU') > 0 then do
      L1 = 1
    end
    when wordpos(sMnemonic,'DP MP') > 0 then do
      L1 = 2
      L2 = 1
    end
    when wordpos(sMnemonic,'DIDBR DIEBR') > 0 then do
      R1 = 1
      R2 = 2
    end
    otherwise nop
  end
  interpret 'o =' g.0EMIT.sFormat     /* Generate instruction operands  */
  sOperands = space(o,,',')
  nMnemonic = max(length(sMnemonic),5)
  xLoc = g.0XLOC
  sLabel = getLabel(xLoc)
  sInst = left(sMnemonic,nMnemonic) sOperands
  nInst = max(length(sInst),29)
  sStmt = left(sLabel,8),
          left(sInst,nInst),
          sDesc
  call emit sStmt
return

addSVC: procedure expose g.
  parse arg xSVC,sZOSSVC
  g.0SVC.xSVC   = strip(sZOSSVC)
return

addExt: procedure expose g.
  parse arg sUse,xMask,sBC,sBCR,sBIC,sBRC,sBRCL,sDesc
  g.0EXT.BC.sUse.xMask  = sBC    /* Branch on Condition               */
  g.0EXT.BCR.sUse.xMask = sBCR   /* Branch Register on Condition      */
  g.0EXT.BIC.sUse.xMask = sBIC   /* Branch Immediate on Condition     */
  g.0EXT.BRC.sUse.xMask = sBRC   /* Branch Relative on Condition      */
  g.0EXT.BRCL.sUse.xMask = sBRCL /* Branch Relative on Condition Long */
  sDesc = strip(sDesc)
  g.0DESC.sUse.sBC   = sDesc
  g.0DESC.sUse.sBCR  = sDesc
  g.0DESC.sUse.sBIC  = sDesc
  g.0DESC.sUse.sBRC  = sDesc
  g.0DESC.sUse.sBRCL = sDesc
return

addExtSelect: procedure expose g.
  parse arg sUse,xMask,sSELR,sSELGR,sSELFHR,sDesc
  g.0EXT.SELR.sUse.xMask   = sSELR   /* Select (32)                       */
  g.0EXT.SELGR.sUse.xMask  = sSELGR  /* Select (64)                       */
  g.0EXT.SELFHR.sUse.xMask = sSELFHR /* Select High                       */
  sDesc = strip(sDesc)
  g.0DESC.sUse.sSELR   = sDesc
  g.0DESC.sUse.sSELGR  = sDesc
  g.0DESC.sUse.sSELFHR = sDesc
return

addExtCompare: procedure expose g.
  arg xMask,sExt
  g.0EXTC.xMask = sExt
return

addExtOnCond: procedure expose g.
  arg xMask,sExt
  g.0EXTO.xMask = sExt
return

getExt: procedure expose g.
  parse arg sMnemonic,sUse,xMask
  if xMask = 'F' | xMask = '0' /* If mask is unconditional or no-op   */
  then sUse = '.'              /* Preceding instruction is irrelevant */
return g.0EXT.sMnemonic.sUse.xMask

/*
The instruction formats are defined below. There are two lines per instruction
format:

1. The first line is the PARSER. It specifies:
  a. The name of the instruction format
  b. The length (in 4-bit nibbles) of an instruction having this format
  c. The Rexx parsing template to be used to parse an instruction with this
     format.

  For example:

   RR     4 O1 +2 R1 +1    R2 +1

  ...the opcode O1 is 2 nibbles (1 byte), followed by the 1-nibble R1
     operand and the 1-nibble R2 operand.

2. The second line is the GENERATOR. It specifies:
  a. The name of the instruction format (again)
  b. A '.' in the instruction length column to identify this as the GENERATOR
  c. The right hand side of a Rexx assignment statement used to generate the
     Assembler operands of the instruction that was parsed using the parsing
     template.

  For example:

   RR     . r(R1) r(R2)

  Note: Operands are separated by spaces (rather than commas) in order to
        simplify the table definition. Commas are inserted later.

  The GENERATOR can also use the hint() rexx function to compute the lengths
  of the operands if that is possible. It is not possible for MVCL, for
  example, because MVCL length values are computed at run time. The hint()
  function always returns '' so it has no impact on the GENERATOR other than
  to assign length values to the operands.

Parsing works as follows, using the instruction hex 18CF as an example:

1. The opcode 18 is extracted from the 18CF instruction. Opcodes can appear
   in only a few positions:

   aa..........
   bbbb........
   cc.c........
   dd........dd

   In this case, the opcode is found in position 'aa' (because the other
   combinations do not yield a known instruction).

2. The 18 instruction data is retrieved from the instruction table. In this
   case the instruction data is:

   code mnemonic fmt   f desc
   ---- -------- ----  - -------------------------------------
   18   LR       RR    . Load (32)

   From this, we can see that the 18 instruction is 'Load (32)' and has the
   LR assembler mnemonic and the RR (Register Register) instruction format.

3. The RR instruction format data is retrieved from the format table.
   The RR format data consists of the PARSER and GENERATOR lines:

   Name Len PARSER and GENERATOR (in nibble units)
   ----- -- --------------------------------------
   RR     4 O1 +2 R1 +1    R2 +1                  <-- PARSER template
   RR     . r(R1) r(R2)                           <-- GENERATOR function list

4. The hex instruction 18CF is PARSED using the template "O1 +2 R1 +1 R2 +1"
   which causes the following variables to be set:

   O1 = '18'                                      <-- Op code byte 1
   R1 = 'C'                                       <-- Operand 1
   R2 = 'F'                                       <-- Operand 2

5. The operands are GENERATED using the template "r(R1) r(R2)" which invokes
   the "r" function twice: once with the value in R1 ('C') and again with the
   value in R2 ('F'). When assigned to the Rexx variable 'o' the result is:

   o = 'R12 R15'

6. The assembler instruction is now built by combining the instruction
   mnemonic ('LR') with the operands ('R12 R15') as follows:

   Mnemonic                      Current
   |     Operands   Comment      Offset  Hex           Format
   |     |          |            |       |             |
   V     V          V            V       V             V
   LR    R12,R15    Load (32)    0000000 18CF          RR


Tip:  Because the PARSER and GENERATOR templates are executed using the
      Rexx "interpret" instruction, you can debug individual formats by
      appending Rexx instructions (delimited by ';') to the templates.
      For example:

I      4 O1 +2 I1 +2; say 'Heh dude, we just parsed an I format:'xOpCode
I      . u(I1)

       .--- Instruction length in nibbles (4, 8 or 12)
       |
       V
Name Len PARSER and GENERATOR (in nibble units)
----- -- --------------------------------------
BEGIN-FORMAT-DEFINITIONS
.      4 X1 +4
.      . x(X1)
E      4 O1 +4
E      .
I      4 O1 +2 I1 +2
I      . x2d(I1)
IE     8 O1 +4  . +2    I1 +1  I2 +1
IE     . u(I1) u(I2)
MII   12 O1 +2 M1 +1   RI2 +3 RI3 +6
MII    . u(M1) u(RI2) u(RI3)
RIa    8 O1 +2 R1 +1    O2 +1  I2 +4
RIa    . r(R1) s4(I2)
RIax   8 O1 +2 R1 +1    O2 +1  I2 +4
RIax   . r(R1) x(I2)
RIb    8 O1 +2 R1 +1    O2 +1 RI2 +4
RIb    . r(R1) s4(RI2)
RIc    8 O1 +2 M1 +1    O2 +1 RI2 +4
RIc    . m(M1) s4(RI2)
RIEa  12 O1 +2 R1 +1     . +1  I2 +4  M3 +1   . +1       O2 +2
RIEa   . r(R1) s4(I2) m(M3)
RIEb  12 O1 +2 R1 +1    R2 +1 RI4 +4  M3 +1   . +1       O2 +2
RIEb   . r(R1) r(R2) m(M3) s4(RI4)
RIEc  12 O1 +2 R1 +1    M3 +1 RI4 +4  I2 +2              O2 +2
RIEc   . r(R1) u(I2) m(M3) s4(RI4)
RIEd  12 O1 +2 R1 +1    R3 +1  I2 +4   . +2              O2 +2
RIEd   . r(R1) r(R3) s4(I2)
RIEe  12 O1 +2 R1 +1    R3 +1 RI2 +4   . +2              O2 +2
RIEe   . r(R1) r(R3) s4(RI2)
RIEf  12 O1 +2 R1 +1    R2 +1  I3 +2  I4 +2  I5 +2       O2 +2
RIEf   . r(R1) r(R2) s2(I3) s2(I4) s2(I5)
RIEg  12 O1 +2 R1 +1    M3 +1  I2 +4   . +2              O2 +2
RIEg   . r(R1) s4(I2) m(M3)
RILa  12 O1 +2 R1 +1    O2 +1  I2 +8
RILa   . r(R1) u(I2)
RILax 12 O1 +2 R1 +1    O2 +1  I2 +8
RILax  . r(R1) x(I2)
RILb  12 O1 +2 R1 +1    O2 +1 RI2 +8
RILb   . r(R1) s8(RI2)
RILc  12 O1 +2 M1 +1    O2 +1 RI2 +8
RILc   . m(M1) s8(I2)
RIS   12 O1 +2 R1 +1    M3 +1  B4 +1  D4 +3  I2 +2       O2 +2
RIS    . r(R1) r(R2) m(M3) s2(I2)
RR     4 O1 +2 R1 +1    R2 +1
RR     . r(R1) r(R2)
RR1    4 O1 +2 R1 +1     . +1
RR1    . r(R1)
RRm    4 O1 +2 M1 +1    R2 +1
RRm    . m(M1) r(R2)
RRD    8 O1 +4 R1 +1     . +1  R3 +1  R2 +1
RRD    . r(R1) r(R3) r(R2)
RRE    8 O1 +4  . +2    R1 +1  R2 +1
RRE    . r(R1) r(R2)
RRE0   8 O1 +4  . +4
RRE0   . ''
RRE1   8 O1 +4  . +2    R1 +1   . +1
RRE1   . r(R1)
RRFa   8 O1 +4 R3 +1    M4 +1  R1 +1  R2 +1
RRFa   . r(R1) r(R2) r(R3) om(M4)
RRFa4  8 O1 +4 R3 +1    M4 +1  R1 +1  R2 +1
RRFa4  . r(R1) r(R2) r(R3) m(M4)
RRFb   8 O1 +4 R3 +1    .  +1  R1 +1  R2 +1
RRFb   . r(R1) r(R2) r(R3)
RRFc   8 O1 +4 M3 +1     . +1  R1 +1  R2 +1
RRFc   . r(R1) r(R2) om(M3)
RRFc3  8 O1 +4 M3 +1     . +1  R1 +1  R2 +1
RRFc3  . r(R1) r(R2) m(M3)
RRFd   8 O1 +4  . +1    M4 +1  R1 +1  R2 +1
RRFd   . r(R1) r(R2) m(M4)
RRFe   8 O1 +4 M3 +1    M4 +1  R1 +1  R2 +1
RRFe   . r(R1) m(M3) r(R2) om(M4)
RRFe4  8 O1 +4 M3 +1    M4 +1  R1 +1  R2 +1
RRFe4  . r(R1) u(M3) r(R2) m(M4)
RRFb4  8 O1 +4 R3 +1    M4 +1  R1 +1  R2 +1
RRFb4  . r(R1) r(R2) r(R3) u(M4)
RRS   12 O1 +2 R1 +1    R2 +1  B4 +1  D4 +3  M3 +1  . +1 O2 +2
RRS    . r(R1) r(R2) m(M3) db(D4,B4)
RSa    8 O1 +2 R1 +1    .  +1  B2 +1  D2 +3
RSa    . r(R1)       dbs(D2,B2)
RSb    8 O1 +2 R1 +1    M3 +1  B2 +1  D2 +3
RSb    . r(R1) m(M3) db(D2,B2)          hint(ml(M3),B2,D2)
RSA    8 O1 +2 R1 +1    R3 +1  B2 +1  D2 +3
RSA    . r(R1) r(R3) db(D2,B2)          hint(g.0TLENG,B2,D2)
RSI    8 O1 +2 R1 +1    R3 +1 RI2 +4
RSI    . r(R1) r(R3) s4(RI2)
RSLa  12 O1 +2 L1 +1     . +1  B1 +1  D1 +3   . +1  . +1 O2 +2
RSLa   . dlb(D1,L1,B1)
RSLb  12 O1 +2 L2 +2           B2 +1  D2 +3  R1 +1 M3 +1 O2 +2
RSLb   . r(R1) dlb(D2,L2,B2) m(M3)
RSYa  12 O1 +2 R1 +1    R3 +1  B2 +1 DL2 +3 DH2 +2       O2 +2
RSYa   . r(R1) r(R3) ldb(DH2||DL2,B2)   hint(g.0TLENG,B2,DH2||DL2)
RSYas 12 O1 +2 R1 +1    R3 +1  B2 +1 DL2 +3 DH2 +2       O2 +2
RSYas  . r(R1) r(R3) ldbs(DH2||DL2,B2)
RSYb  12 O1 +2 R1 +1    M3 +1  B2 +1 DL2 +3 DH2 +2       O2 +2
RSYb   . r(R1) m(M3) ldb(DH2||DL2,B2)   hint(g.0TLENG,B2,DH2||DL2)
RSYbm 12 O1 +2 R1 +1    M3 +1  B2 +1 DL2 +3 DH2 +2       O2 +2
RSYbm  . r(R1) m(M3) ldb(DH2||DL2,B2)   hint(ml(M3),B2,DH2||DL2)
RXa    8 O1 +2 R1 +1    X2 +1  B2 +1  D2 +3
RXa    . r(R1) dxb(D2,X2,B2)            hint(g.0TLENG,B2,D2)
RXb    8 O1 +2 M1 +1    X2 +1  B2 +1  D2 +3
RXb    . m(M1) dxb(D2,X2,B2)
RXE   12 O1 +2 R1 +1    X2 +1  B2 +1  D2 +3   . +1  . +1 O2 +2
RXE    . r(R1) dxb(D2,X2,B2)            hint(g.0TLENG,B2,D2)
RXE3  12 O1 +2 R1 +1    X2 +1  B2 +1  D2 +3  M3 +1  . +1 O2 +2
RXE3   . r(R1) dxb(D2,X2,B2) m(M3)      hint(g.0TLENG,B2,D2)
RXF   12 O1 +2 R3 +1    X2 +1  B2 +1  D2 +3  R1 +1  . +1 O2 +2
RXF    . r(R1) r(R3) dxb(D2,X2,B2)      hint(g.0TLENG,B2,D2)
RXYa  12 O1 +2 R1 +1    X2 +1  B2 +1 DL2 +3 DH2 +2       O2 +2
RXYa   . r(R1) ldxb(DH2||DL2,X2,B2)     hint(g.0TLENG,B2,DH2||DL2)
RXYb  12 O1 +2 M1 +1    X2 +1  B2 +1 DL2 +3 DH2 +2       O2 +2
RXYb   . m(M1) ldxb(DH2||DL2,X2,B2)
S      8 O1 +4 B2 +1    D2 +3
S      . db(D2,B2)                      hint(g.0TLENG,B2,D2)
SI     8 O1 +2 I2 +2    B1 +1  D1 +3
SI     . db(D1,B1) u(I2)                hint(g.0TLENG,B1,D1)
SI0    8 O1 +2 I2 +2    B1 +1  D1 +3
SI0    . db(D1,B1) m(I2)                hint(1,B1,D1)
SI1    8 O1 +2  . +2    B1 +1  D1 +3
SI1    . db(D1,B1)                      hint(g.0TLENG,B1,D1)
SIL   12 O1 +4 B1 +1    D1 +3  I2 +4
SIL    . db(D1,B1) s2(I2)               hint(g.0TLENG,B1,D1)
SIY   12 O1 +2 I2 +2    B1 +1 DL1 +3 DH1 +2              O2 +2
SIY    . ldb(DH1||DL1,B1) s2(I2)        hint(g.0TLENG,B1,DH1||DL1)
SIYm  12 O1 +2 I2 +2    B1 +1 DL1 +3 DH1 +2              O2 +2
SIYm   . ldb(DH1||DL1,B1) m(I2)         hint(1,B1,DH1||DL1)
SIYx  12 O1 +2 I2 +2    B1 +1 DL1 +3 DH1 +2              O2 +2
SIYx   . ldb(DH1||DL1,B1) x(I2)         hint(1,B1,DH1||DL1)
SIYu  12 O1 +2 I2 +2    B1 +1 DL1 +3 DH1 +2              O2 +2
SIYu   . ldb(DH1||DL1,B1) u(I2)         hint(1,B1,DH1||DL1)
SMI   12 O1 +2 M1 +1     . +1  B3 +1  D3 +3 RI2 +4
SMI    . m(M1) s4(RI2) db(D3,B1)
SSa   12 O1 +2 L1 +2           B1 +1  D1 +3  B2 +1  D2 +3
SSa    . dlb(D1,L1,B1) db(D2,B2)        hint(l(L1),B2,D2)
SSb   12 O1 +2 L1 +1    L2 +1  B1 +1  D1 +3  B2 +1  D2 +3
SSb    . dlb(D1,L1,B1) dlb(D2,L2,B2)
SSc   12 O1 +2 L1 +1    I3 +1  B1 +1  D1 +3  B2 +1  D2 +3
SSc    . dlb(D1,L1,B1) db(D2,B2) u(I3)
SSd   12 O1 +2 R1 +1    R3 +1  B1 +1  D1 +3  B2 +1  D2 +3
SSd    . db(D1,B1) db(D2,B2) r(R3)
SSe   12 O1 +2 R1 +1    R3 +1  B2 +1  D2 +3  B4 +1  D4 +3
SSe    . r(R1) r(R3) db(D2,B2) db(D4,B4) hint(hM(4),B2,D2) hint(hM(4),B4,D4)
SSe1  12 O1 +2 R1 +1    R3 +1  B2 +1  D2 +3  B4 +1  D4 +3
SSe1   . r(R1) r(R3) db(D2,B2) db(D4,B4)
SSf   12 O1 +2 L2 +2           B1 +1  D1 +3  B2 +1  D2 +3
SSf    . db(D1,B1) dlb(D2,L2,B2)        hint(16,B1,D1)
SSE   12 O1 +4                 B1 +1  D1 +3  B2 +1  D2 +3
SSE    . db(D1,B1) db(D2,B2)            hint(g.0TLENG,B2,D2)
SSF   12 O1 +2 R3 +1    O2 +1  B1 +1  D1 +3  B2 +1  D2 +3
SSF    . db(D1,B1) db(D2,B2) r(R3)      hint(g.0TLENG,B2,D2)
VRIa  12 O1 +2 V1 +1     . +1  I2 +4   . +1                    RXB +1 O2 +2
VRIa   . v(V1) u(I2)
VRIa3 12 O1 +2 V1 +1     . +1  I2 +4  M3 +1                    RXB +1 O2 +2
VRIa3  . v(V1) s4(I2) u(M3)
VRIb  12 O1 +2 V1 +1     . +1  I2 +2  I3 +2  M4 +1             RXB +1 O2 +2
VRIb   . v(V1) u(I2) u(I3) u(M4)
VRIc  12 O1 +2 V1 +1    V3 +1  I2 +4         M4 +1             RXB +1 O2 +2
VRIc   . v(V1) v(V3) u(I2) m(M4)
VRId  12 O1 +2 V1 +1    V2 +1  V3 +1   . +1  I4 +2  . +1       RXB +1 O2 +2
VRId   . v(V1) v(V2) v(V3) u(I4)
VRId5 12 O1 +2 V1 +1    V2 +1  V3 +1   . +1  I4 +2 M5 +1       RXB +1 O2 +2
VRId5  . v(V1) v(V2) v(V3) u(I4) u(M5)
VRIe  12 O1 +2 V1 +1    V2 +1  I3 +3         M5 +1 M4 +1       RXB +1 O2 +2
VRIe   . v(V1) v(V2) u(I3) u(M4) m(M5)
VRIf  12 O1 +2 V1 +1    V2 +1  V3 +1   . +1  M5 +1 I4 +2       RXB +1 O2 +2
VRIf   . v(V1) v(V2) v(V3) u(I4) m(M5)
VRIg  12 O1 +2 V1 +1    V2 +1  I4 +2  M5 +1        I3 +2       RXB +1 O2 +2
VRIg   . v(V1) v(V2) u(I3) m(I4) m(M5)
VRIh  12 O1 +2 V1 +1     . +1  I2 +4  I3 +1                    RXB +1 O2 +2
VRIh   . v(V1) x(I2) u(I3)
VRIi  12 O1 +2 V1 +1    R2 +1   . +2  M4 +1  I3 +2             RXB +1 O2 +2
VRIi   . v(V1) r(R2) u(I3) m(M4)
VRRa  12 O1 +2 V1 +1    V2 +1   . +5                           RXB +1 O2 +2
VRRa   . v(V1) v(V2)
VRRa2 12 O1 +2 V1 +1    V2 +1   . +2  M5 +1   . +1 M3 +1       RXB +1 O2 +2
VRRa2  . v(V1) v(V2) m(M3)      om(M5)
VRRa3 12 O1 +2 V1 +1    V2 +1   . +4               M3 +1       RXB +1 O2 +2
VRRa3  . v(V1) v(V2) m(M3)
VRRa4 12 O1 +2 V1 +1    V2 +1   . +3         M4 +1 M3 +1       RXB +1 O2 +2
VRRa4  . v(V1) v(V2) u(M3) m(M4)
VRRa5 12 O1 +2 V1 +1    V2 +1   . +2  M5 +1  M4 +1 M3 +1       RXB +1 O2 +2
VRRa5  . v(V1) v(V2) u(M3) m(M4) u(M5)
VRRb  12 O1 +2 V1 +1    V2 +1  V3 +1   . +1  M5 +1  . +1 M4 +1 RXB +1 O2 +2
VRRb   . v(V1) v(V2) v(V3) u(M4) m(M5)
VRRb4 12 O1 +2 V1 +1    V2 +1  V3 +1   . +1  M5 +1  . +1 M4 +1 RXB +1 O2 +2
VRRb4  . v(V1) v(V2) v(V3) u(M4) om(M5)
VRRc3 12 O1 +2 V1 +1    V2 +1  V3 +1   . +4                    RXB +1 O2 +2
VRRc3  . v(V1) v(V2) v(V3)
VRRc4 12 O1 +2 V1 +1    V2 +1  V3 +1   . +3              M4 +1 RXB +1 O2 +2
VRRc4  . v(V1) v(V2) v(V3) u(M4)
VRRc5 12 O1 +2 V1 +1    V2 +1  V3 +1   . +2        M5 +1 M4 +1 RXB +1 O2 +2
VRRc5  . v(V1) v(V2) v(V3) u(M4) m(M5)
VRRc6 12 O1 +2 V1 +1    V2 +1  V3 +1   . +1  M6 +1 M5 +1 M4 +1 RXB +1 O2 +2
VRRc6  . v(V1) v(V2) v(V3) u(M4) m(M5) m(M6)
VRRd  12 O1 +2 V1 +1    V2 +1  V3 +1  M5 +1   . +2       V4 +1 RXB +1 O2 +2
VRRd   . v(V1) v(V2) v(V3) v(V4) u(M5)
VRRd5 12 O1 +2 V1 +1    V2 +1  V3 +1  M5 +1  M6 +1  . +1 V4 +1 RXB +1 O2 +2
VRRd5  . v(V1) v(V2) v(V3) v(V4) u(M5) om(M6)
VRRd6 12 O1 +2 V1 +1    V2 +1  V3 +1  M5 +1  M6 +1  . +1 V4 +1 RXB +1 O2 +2
VRRd6  . v(V1) v(V2) v(V3) v(V4) u(M5) m(M6)
VRRe  12 O1 +2 V1 +1    V2 +1  V3 +1   . +3              V4 +1 RXB +1 O2 +2
VRRe   . v(V1) v(V2) v(V3) v(V4)
VRRe6 12 O1 +2 V1 +1    V2 +1  V3 +1  M6 +1   . +1 M5 +1 V4 +1 RXB +1 O2 +2
VRRe6  . v(V1) v(V2) v(V3) v(V4) m(M5) u(M6)
VRRf  12 O1 +2 V1 +1    R2 +1  R3 +1   . +4                    RXB +1 O2 +2
VRRf   . v(V1) r(R2) r(R3)
VRRg  12 O1 +2  . +1    V1 +1   . +5                           RXB +1 O2 +2
VRRg   . v(V1)
VRRh  12 O1 +2  . +1    V1 +1  V2 +1   . +1  M3 +1  . +2       RXB +1 O2 +2
VRRh   . v(V1) v(V2) m(M3)
VRRi  12 O1 +2 R1 +1    V2 +1   . +2  M3 +1   . +2             RXB +1 O2 +2
VRRi   . r(R1) v(V2) m(M3)
VRSa  12 O1 +2 V1 +1    V2 +1  B2 +1  D2 +3  M4 +1             RXB +1 O2 +2
VRSa   . v(V1) v(V3) db(D2,B2) u(M4)
VRSb  12 O1 +2 V1 +1    R3 +1  B2 +1  D2 +3   . +1             RXB +1 O2 +2
VRSb   . v(V1) r(R3) db(D2,B2)
VRSb4 12 O1 +2 V1 +1    R3 +1  B2 +1  D2 +3  M4 +1             RXB +1 O2 +2
VRSb4  . v(V1) r(R3) db(D2,B2) u(M4)
VRSc  12 O1 +2 R1 +1    V3 +1  B2 +1  D2 +3  M4 +1             RXB +1 O2 +2
VRSc   . r(R1) v(V3) db(D2,B2) u(M4)
VRSd  12 O1 +2  . +1    R3 +1  B2 +1  D2 +3  V1 +1             RXB +1 O2 +2
VRSd   . v(V1) r(R3) db(D2,B2)
VRV   12 O1 +2 V1 +1    V2 +1  B2 +1  D2 +3  M3 +1             RXB +1 O2 +2
VRV    . v(V1) dvb(D2,V2,B2) m(M3)
VRX   12 O1 +2 V1 +1    X2 +1  B2 +1  D2 +3   . +1             RXB +1 O2 +2
VRX    . v(V1) dxb(D2,X2,B2)
VRX3  12 O1 +2 V1 +1    X2 +1  B2 +1  D2 +3  M3 +1             RXB +1 O2 +2
VRX3   . v(V1) dxb(D2,X2,B2) u(M3)
VSI   12 O1 +2 I3 +2           B2 +1  D2 +3  v1 +1             RXB +1 O2 +2
VSI    . v(V1) db(D2,B2) u(I3)
END-FORMAT-DEFINITIONS


The instructions are defined below. There is one line per instruction, each
specifying:
  a. The instruction opcode
  b. The assembler mnemonic
  c. The instruction format
  d. A flag used to modify the processing for certain instructions (for
     example, to convert mnemonics to extended mnemonics)
  e. The instruction description as specified in Principles of Operations
     manual.
  f. An expression (prefixed by '=') that generates the target operand
     length. This is called a "hint". For example, the STC target operand
     length is always 1, but for LM it depends on the operands.
     So, the STC instruction hint is "=1", and the LM instruction hint
     is "=hM(4)"...which means take the M1 value from the LM instruction
     and compute the actual length from the number of 4-byte registers loaded
     by the instruction.
     The length computed in this way is stored in g.0TLENG and can be used
     to compute length hints at the instruction format level (so that the
     length applies to all instructions with that format).

                    .- Flag for determining extended mnemonics:
                    |    A = Arithmetic instruction
                    |    B = Branch on condition instruction (Bxx)
                    |    C = Compare instructions (A:B)
                    |   CJ = Compare and Jump
                    |   JX = Jump on Index
                    |    M = Test under mask instruction
                    |    O = Load/Store-on-Condition instruction
                    |    R = Relative branch on condition (Jxx)
                    |   RO = Rotate
                    |   R4 = Relative 4-nibble offset
                    |   R8 = Relative 8-nibble offset
                    |    S = Select instructions
                    |    c = Sets condition code
                    |    . = Does not set condition code
                    V
mnemonic cde fmt    f desc                                  =hint
------- ---- ----- -- ------------------------------------- -------------------
BEGIN-INSTRUCTION-DEFINITIONS
DC      .    .      . <-- TODO (not code)
PR      0101 E      c Program Return
UPT     0102 E      c Update Tree
PTFF    0104 E      c Perform Timing Facility Function
SCKPF   0107 E      . Set Clock Programmable Field
PFPO    010A E      c Perform Floating Point Operation
TAM     010B E      c Test Addressing Mode
SAM24   010C E      . Set Addressing Mode (24)
SAM31   010D E      . Set Addressing Mode (31)
SAM64   010E E      . Set Addressing Mode (64)
TRAP2   01FF E      . Trap
SPM     04   RR1    c Set Program Mask
BALR    05   RR     . Branch And Link
BCTR    06   RR     . Branch on Count
BCR     07   RRm    B Branch on Condition
SVC     0A   I      . Supervisor Call
BSM     0B   RR     . Branch and Set Mode
BASSM   0C   RR     . Branch And Save and Set Mode
BASR    0D   RR     . Branch And Save
MVCL    0E   RR     c Move Character Long
CLCL    0F   RR     C Compare Logical Character Long
LPR     10   RR     A Load Positive (32)
LNR     11   RR     A Load Negative (32)
LTR     12   RR     A Load and Test (32)
LCR     13   RR     A Load Complement (32)
NR      14   RR     A And (32)
CLR     15   RR     C Compare Logical (32)
OR      16   RR     A Or (32)
XR      17   RR     A Exclusive-Or (32)
LR      18   RR     . Load (32)
CR      19   RR     C Compare (32)
AR      1A   RR     A Add (32)
SR      1B   RR     A Subtract (32)
MR      1C   RR     A Multiply (64<-32)
DR      1D   RR     A Divide (32<-64)
ALR     1E   RR     A Add Logical (32)
SLR     1F   RR     A Subtract Logical (32)
LPDR    20   RR     A Load Positive (LH)
LNDR    21   RR     A Load Negative (LH)
LTDR    22   RR     A Load and Test (LH)
LCDR    23   RR     A Load Complement (LH)
HDR     24   RR     . Halve (LH)
LDXR    25   RR     . Load Rounded (LH<-EH)
MXR     26   RR     A Multiply (EH)
MXDR    27   RR     A Multiply (EH<-LH)
LDR     28   RR     . Load (Long)
CDR     29   RR     C Compare (LH)
ADR     2A   RR     A Add (LH)
SDR     2B   RR     A Subtract (LH)
MDR     2C   RR     A Multiply (LH)
DDR     2D   RR     A Divide (LH)
AWR     2E   RR     A Add Unnormalized (LH)
SWR     2F   RR     A Subtract Unnormalized (LH)
LPER    30   RR     A Load Positive (SH)
LNER    31   RR     A Load Negative (SH)
LTER    32   RR     A Load and Test (SH)
LCER    33   RR     A Load Complement (SH)
HER     34   RR     . Halve Short (SH)
LEDR    35   RR     . Load Rounded (SH<-LH)
AXR     36   RR     A Add Normalized (EH)
SXR     37   RR     A Subtract Normalized (EH)
LER     38   RR     . Load (SH)
CER     39   RR     C Compare (SH)
AER     3A   RR     A Add Normalized (SH)
SER     3B   RR     A Subtract Normalized (SH)
MER     3C   RR     A Multiply Normalized (LH<-SH)
DER     3D   RR     A Divide Normalized (SH)
AUR     3E   RR     A Add Unnormalized (SH)
SUR     3F   RR     A Subtract Unnormalized (SH)
STH     40   RXa    . Store Halfword (16) =2
LA      41   RXa    . Load Address
STC     42   RXa    . Store Character (8) =1
IC      43   RXa    . Insert Character (8) =1
EX      44   RXa    . Execute
BAL     45   RXa    . Branch And Link
BCT     46   RXa    . Branch on Count
BC      47   RXb    B Branch on Condition
LH      48   RXa    . Load Halfword (32<-16) =2
CH      49   RXa    C Compare Halfword (32<-16) =2
AH      4A   RXa    A Add Halfword (32<-16) =2
SH      4B   RXa    A Subtract Halfword (32<-16) =2
MH      4C   RXa    A Multiply Halfword (32<-16) =2
BAS     4D   RXa    . Branch And Save
CVD     4E   RXa    . Convert to Decimal (32) =8
CVB     4F   RXa    . Convert to Binary (32) =8
ST      50   RXa    . Store (32) =4
LAE     51   RXa    . Load Address Extended
N       54   RXa    A And (32) =4
CL      55   RXa    C Compare Logical (32) =4
O       56   RXa    A Or (32) =4
X       57   RXa    A Exclusive-Or (32) =4
L       58   RXa    . Load (32) =4
C       59   RXa    C Compare (32) =4
A       5A   RXa    A Add (32) =4
S       5B   RXa    A Subtract (32) =4
M       5C   RXa    A Multiply (64<-32) =4
D       5D   RXa    A Divide (32<-64) =4
AL      5E   RXa    A Add Logical (32) =4
SL      5F   RXa    A Subtract Logical (32) =4
STD     60   RXa    . Store (Long) =8
MXD     67   RXa    A Multiply (EH<-LH) =8
LD      68   RXa    . Load (Long) =8
CD      69   RXa    C Compare (LH) =8
AD      6A   RXa    A Add Normalized (LH) =8
SD      6B   RXa    A Subtract Normalized (LH) =8
MD      6C   RXa    A Multiply (LH) =8
DD      6D   RXa    A Divide (LH) =8
AW      6E   RXa    A Add Unnormalized (LH) =8
SW      6F   RXa    A Subtract Unnormalized (LH) =8
STE     70   RXa    . Store (Short) =4
MS      71   RXa    A Multiply Single (32) -4
LE      78   RXa    . Load (Short) =4
CE      79   RXa    C Compare (SH) =4
AE      7A   RXa    A Add Normalized (SH) =4
SE      7B   RXa    A Subtract Normalized (SH) =4
ME      7C   RXa    A Multiply (LH<-SH) =4
DE      7D   RXa    A Divide (SH) =4
AU      7E   RXa    A Add Unnormalized (SH) =4
SU      7F   RXa    A Subtract Unnormalized (SH) =4
SSM     80   SI1    . Set System Mask
LPSW    82   SI1    c Load Program Status Word =8
DIAG    83   RXa    . Diagnose
JXH     84   RSI   JX Branch Relative on Index High (32)
JXLE    85   RSI   JX Branch Relative on Index Low or Equal (32)
BXH     86   RSA    . Branch on Index High (32)
BXLE    87   RSA    . Branch on Index Low or Equal (32)
SRL     88   RSa    . Shift Right Single Logical (32)
SLL     89   RSa    . Shift Left Single Logical (32)
SRA     8A   RSa    A Shift Right Single Arithmetic (32)
SLA     8B   RSa    A Shift Left Single Arithmetic (32)
SRDL    8C   RSa    . Shift Right Double Logical (64)
SLDL    8D   RSa    . Shift Left Double Logical (64)
SRDA    8E   RSa    A Shift Right Double Arithmetic (64)
SLDA    8F   RSa    A Shift Left Double Arithmetic (64)
STM     90   RSA    . Store Multiple (32) =hM(4)
TM      91   SI0    M Test under Mask (8)
MVI     92   SI     . Move Immediate (8) =1
TS      93   SI1    c Test And Set (8) =1
NI      94   SI0    A And Immediate (8)
CLI     95   SI     C Compare Logical Immediate (8) =1
OI      96   SI0    A Or Immediate (8)
XI      97   SI0    A Exclusive-Or Immediate (8)
LM      98   RSA    . Load Multiple (32) =hM(4)
TRACE   99   RSA    . Trace (32)
LAM     9A   RSA    . Load Access Multiple =hM(4)
STAM    9B   RSA    . Store Access Multiple =hM(4)
IIHH    A50  RIax   . Insert Immediate High High (0-15)
IIHL    A51  RIax   . Insert Immediate High Low (16-31)
IILH    A52  RIax   . Insert Immediate Low Low (32-47)
IILL    A53  RIax   . Insert Immediate Low Low (48-63)
NIHH    A54  RIax   A And Immediate High High (0-15)
NIHL    A55  RIax   A And Immediate High Low (16-31)
NILH    A56  RIax   A And Immediate Low Low (32-47)
NILL    A57  RIax   A And Immediate Low Low (48-63)
OIHH    A58  RIax   A Or Immediate High High (0-15)
OIHL    A59  RIax   A Or Immediate High Low (16-31)
OILH    A5A  RIax   A Or Immediate Low Low (32-47)
OILL    A5B  RIax   A Or Immediate Low Low (48-63)
LLIHH   A5C  RIax   . Load Logical Immediate High High (0-15)
LLIHL   A5D  RIax   . Load Logical Immediate High Low (16-31)
LLILH   A5E  RIax   . Load Logical Immediate Low Low (32-47)
LLILL   A5F  RIax   . Load Logical Immediate Low Low (48-63)
TMLH    A70  RIax   M Test under Mask Low Low (32-47)
TMLL    A71  RIax   M Test under Mask Low Low (48-63)
TMHH    A72  RIax   M Test under Mask High High (0-15)
TMHL    A73  RIax   M Test under Mask High Low (16-31)
BRC     A74  RIc    R Branch Relative on Condition
JAS     A75  RIb   R4 Branch Relative And Save
JCT     A76  RIb   R4 Branch Relative on Count (32)
JCTG    A77  RIb   R4 Branch Relative on Count (64)
LHI     A78  RIa    . Load Halfword Immediate (32<-16)
LGHI    A79  RIa    . Load Halfword Immediate (64<-16)
AHI     A7A  RIa    A Add Halfword Immediate (32<-16)
AGHI    A7B  RIa    A Add Halfword Immediate (64<-16)
MHI     A7C  RIa    A Multiply Halfword Immediate (32<-16)
MGHI    A7D  RIa    A Multiply Halfword Immediate (64<-16)
CHI     A7E  RIa    C Compare Halfword Immediate (32<-16)
CGHI    A7F  RIa    C Compare Halfword Immediate (64<-16)
MVCLE   A8   RSA    c Move Long Extended
CLCLE   A9   RSA    C Compare Logical Long Extended
STNSM   AC   SI     . Store Then And System Mask =1
STOSM   AD   SI     . Store Then Or System Mask =1
SIGP    AE   RSA    c Signal Processor
MC      AF   SI     . Monitor Call
LRA     B1   RXa    c Load Real Address (32)
STIDP   B202 S      . Store CPU ID =8
SCK     B204 S      c Set Clock =8
STCK    B205 S      c Store Clock =8
SCKC    B206 S      . Set Clock Comparator =8
STCKC   B207 S      . Store Clock Comparator =8
SPT     B208 S      . Set CPU Timer =8
STPT    B209 S      . Store CPU Timer =8
SPKA    B20A S      . Set PSW Key From Address
IPK     B20B S      . Insert PSW Key
PTLB    B20D S      . Purge TLB
SPX     B210 S      . Set Prefix =4
STPX    B211 S      . Store Prefix =4
STAP    B212 S      . Store CPU Address =2
PC      B218 S      . Program Call
SAC     B219 S      . Set Address Space Control
CFC     B21A S      C Compare And Form Codeword
IPTE    B221 RRFa   . Invalidate Page Table Entry
IPM     B222 RRE1   . Insert Program Mask
IVSK    B223 RRE    . Insert Virtual Storage Key
IAC     B224 RRE1   c Insert Address Space Control
SSAR    B225 RRE1   . Set Secondary ASN
EPAR    B226 RRE1   . Extract Primary ASN
ESAR    B227 RRE1   . Extract Secondary ASN
PT      B228 RRE    . Program Transfer
ISKE    B229 RRE    . Insert Storage Key Extended
RRBE    B22A RRE    . Reset Storage Key Extended
SSKE    B22B RRFc   c Set Storage Key Extended
TB      B22C RRE    c Test Block
DXR     B22D RRE    A Divide
PGIN    B22E RRE    c Page In
PGOUT   B22F RRE    c Page Out
CSCH    B230 S      c Clear Subchannel
HSCH    B231 S      c Halt Subchannel
MSCH    B232 S      c Modify Subchannel
SSCH    B233 S      c Start Subchannel
STSCH   B234 S      c Store Subchannel
TSCH    B235 S      c Test Subchannel
TPI     B236 S      c Test Pending Interruption
SAL     B237 S      . Set Address Limit
RSCH    B238 S      c Resume Subchannel
STCRW   B239 S      c Store Channel Report Word
STCPS   B23A S      . Store Channel Path Status
RCHP    B23B S      c Reset Channel Path
SCHM    B23C S      . Set Channel Monitor
BAKR    B240 RRE    . Branch And Stack
CKSM    B241 RRE    c Checksum
SQDR    B244 RRE    . Square Root (LH)
SQER    B245 RRE    . Square Root (SH)
STURA   B246 RRE    . Store Using Real Address (32)
MSTA    B247 RRE1   . Modify Stacked state
PALB    B248 RRE    . Purge ALB
EREG    B249 RRE    . Extract Stacked Registers (32)
ESTA    B24A RRE    c Extract Stacked State
LURA    B24B RRE    . Load Using Real Address (32)
TAR     B24C RRE    c Test Access
CPYA    B24D RRE    . Copy Access
SAR     B24E RRE    . Set Access
EAR     B24F RRE    . Extract Access
CSP     B250 RRE    C Compare And Swap And Purge (32)
MSR     B252 RRE    A Multiply Single (32)
MVPG    B254 RRE    c Move Page
MVST    B255 RRE    c Move String
CUSE    B257 RRE    C Compare Until Substring Equal
BSG     B258 RRE    . Branch in Subspace Group
BSA     B25A RRE    . Branch And Set Authority
CLST    B25D RRE    C Compare Logical String
SRST    B25E RRE    c Search String
CMPSC   B263 RRE    c Compression Call
XSCH    B276 S      c Cancel Subchannel
RP      B277 S      . Resume Program
STCKE   B278 S      c Store Clock Extended =16
SACF    B279 S      . Set Address Space Control Fast
STCKF   B27C S      c Store Clock Fast =8
STSI    B27D S      c Store System Information
SRNM    B299 S      . Set BFP Rounding Mode (2 bit)
STFPC   B29C S      . Store Floating Point Control =4
LFPC    B29D S      . Load Floating Point Control =4
TRE     B2A5 RRE    c Translate Extended
CU21    B2A6 RRFc   c Convert UTF-16 to UTF-8
CU12    B2A7 RRFc   c Convert UTF-8 to UTF-16
STFLE   B2B0 S      c Store Facility List Extended
STFL    B2B1 S      . Store Facility List
LPSWE   B2B2 S      c Load PSW Extended =16
SRNMB   B2B8 S      . Set BFP Rounding Mode (3 bit)
SRNMT   B2B9 S      . Set DFP Rounding Mode
LFAS    B2BD S      . Load Floating Point Control And Signal =4
PPA     B2E8 RRFc3  . Perform Processor Assist
ETND    B2EC RRE1   . Extract Transaction Nesting Depth
TEND    B2F8 S      . Transaction End
NIAI    B2FA IE     . Next Instruction Access Intent
TABORT  B2FC S      . Transaction Abort
TRAP4   B2FF S      . Trap
LPEBR   B300 RRE    A Load Positive (SB)
LNEBR   B301 RRE    A Load Negative (SB)
LTEBR   B302 RRE    A Load and Test (SB)
LCEBR   B303 RRE    A Load Complement (SB)
LDEBR   B304 RRE    . Load Lengthened (LB<-SB)
LXDBR   B305 RRE    . Load Lengthened (EB<-LB)
LXEBR   B306 RRE    . Load Lengthened (EB<-SB)
MXDBR   B307 RRE    A Multiply (EB<-LB)
KEBR    B308 RRE    C Compare And Signal (SB)
CEBR    B309 RRE    C Compare (SB)
AEBR    B30A RRE    A Add (SB)
SEBR    B30B RRE    A Subtract (SB)
MDEBR   B30C RRE    A Multiply (LB<-SB)
DEBR    B30D RRE    A Divide (SB)
MAEBR   B30E RRD    A Multiply And Add (SB)
MSEBR   B30F RRD    A Multiply And Subtract (SB)
LPDBR   B310 RRE    A Load Positive (LB)
LNDBR   B311 RRE    A Load Negative (LB)
LTDBR   B312 RRE    A Load and Test (LB)
LCDBR   B313 RRE    A Load Complement (LB)
SQEBR   B314 RRE    . Square Root (SB)
SQDBR   B315 RRE    . Square Root (LB)
SQXBR   B316 RRE    . Square Root (EB)
MEEBR   B317 RRE    A Multiply (LB)
KDBR    B318 RRE    C Compare And Signal (LB)
CDBR    B319 RRE    C Compare (LB)
ADBR    B31A RRE    A Add (LB)
SDBR    B31B RRE    A Subtract (LB)
MDBR    B31C RRE    A Multiply (LB)
DDBR    B31D RRE    A Divide (LB)
MADBR   B31E RRD    A Multiply And Add (LB)
MSDBR   B31F RRD    A Multiply And Subtract (LB)
LDER    B324 RRE    . Load Lengthened (LH<-SH)
LXDR    B325 RRE    . Load Lengthened (EH<-LH)
LXER    B326 RRE    . Load Lengthened (EH<-SH)
MAER    B32E RRD    A Multiply And Add (SH)
MSER    B32F RRD    A Multiply And Subtract (SH)
SQXR    B336 RRE    . Square Root Extended (EH)
MEER    B337 RRE    A Multiply And Subtract (SH)
MAYLR   B338 RRD    A Multiply And Add Unnormalized (EHL<-LH)
MYLR    B339 RRD    A Multiply Unnormalized (EHL<-LH)
MAYR    B33A RRD    A Multiply And Add Unnormalized (EH<-LH)
MYR     B33B RRD    A Multiply Unnormalized (EH<-LH)
MAYHR   B33C RRD    A Multiply And Add Unnormalized (EHH<-LH)
MYHR    B33D RRD    A Multiply Unnormalized (LH)
MADR    B33E RRD    A Multiply And Add (LH)
MSDR    B33F RRD    A Multiply And Subtract (LH)
LPXBR   B340 RRE    A Load Positive (EB)
LNXBR   B341 RRE    A Load Negative (EB)
LTXBR   B342 RRE    A Load and Test (EB)
LCXBR   B343 RRE    A Load Complement (EB)
LEDBR   B344 RRE    . Load Rounded (SB<-LB)
LDXBR   B345 RRE    . Load Rounded (LB<-EB)
LEXBR   B346 RRE    . Load Rounded (SB<-EB)
FIXBR   B347 RRFe   . Load FP Integer (EB)
KXBR    B348 RRE    C Compare And Signal (EB)
CXBR    B349 RRE    C Compare (EB)
AXBR    B34A RRE    A Add (EB)
SXBR    B34B RRE    A Subtract (EB)
MXBR    B34C RRE    A Multiply (EB)
DXBR    B34D RRE    A Divide (EB)
TBEDR   B350 RRFe   A Convert HFP to BFP (SB<-LH)
TBDR    B351 RRFe   A Convert HFP to BFP (LB<-LH)
DIEBR   B353 RRFb4  A Divide to Integer (SB)
FIEBR   B357 RRFe   . Load FP Integer (SB)
THDER   B358 RRE    A Convert BFP to HFP (LH<-SB)
THDR    B359 RRE    A Convert BFP to HFP (LH<-LB)
DIDBR   B35B RRFb4  A Divide to Integer (LB)
FIDBR   B35F RRFb   . Load FP Integer (LB)
LPXR    B360 RRE    A Load Positive (EH)
LNXR    B361 RRE    A Load Negative (EH)
LTXR    B362 RRE    A Load and Test (EH)
LCXR    B363 RRE    A Load Complement (EH)
LXR     B365 RRE    . Load (EH)
LEXR    B366 RRE    . Load Rounded (SH<-EH)
FIXR    B367 RRE    . Load FP Integer (EH)
CXR     B369 RRE    C Compare (EH)
LPDFR   B370 RRE    A Load Positive (Long)
LNDFR   B371 RRE    A Load Negative (Long)
CPSDR   B372 RRFb   . Copy Sign (Long)
LCDFR   B373 RRE    A Load Complement (Long)
LZER    B374 RRE1   . Load Zero (Short)
LZDR    B375 RRE1   . Load Zero (Long)
LZXR    B376 RRE1   . Load Zero (E)
FIER    B377 RRE    . Load FP Integer (SH)
FIDR    B37F RRE    . Load FP Integer (LH)
SFPC    B384 RRE1   . Set Floating Point Control
SFASR   B385 RRE1   . Set Floating Point Control and Signal
EFPC    B38C RRE1   . Extract Floating Point Control
CELFBR  B390 RRFe4  . Convert from Logical (SB<-32)
CDLFBR  B391 RRFe4  . Convert from Logical (LB<-32)
CXLFBR  B392 RRFe4  . Convert from Logical (SB<-32)
CEFBR   B394 RRE    . Convert from Logical (EB<-32)
CDFBR   B395 RRE    . Convert from Fixed (LB<-32)
CXFBR   B396 RRE    . Convert from Fixed (EB<-32)
CFEBR   B398 RRFe   A Convert to Fixed (32<-SB)
CFDBR   B399 RRFe   A Convert to Fixed (32<-LB)
CFXBR   B39A RRFe   A Convert to Fixed (32<-EB)
CLFEBR  B39C RRFe4  A Convert to Logical (32<-SB)
CLFDBR  B39D RRFe4  A Convert to Logical (32<-LB)
CLFXBR  B39E RRFe4  A Convert to Logical (32<-EB)
CELGBR  B3A0 RRFe4  . Convert from Locical (SB<-64)
CDLGBR  B3A1 RRFe4  . Convert from Locical (LB<-64)
CXLGBR  B3A2 RRFe4  . Convert from Locical (EB<-64)
CEGBR   B3A4 RRE    . Convert from Fixed (SB<-64)
CDGBR   B3A5 RRE    . Convert from Fixed (LB<-64)
CXGBR   B3A6 RRE    . Convert from Fixed (EB<-64)
CGEBR   B3A8 RRFe   A Convert to Fixed (64<-SB)
CGDBR   B3A9 RRFe   A Convert to Fixed (64<-LB)
CGXBR   B3AA RRFe   A Convert to Fixed (64<-EB)
CLGEBR  B3AC RRFe4  A Convert to Logical (64<-SB)
CLGDBR  B3AD RRFe4  A Convert to Logical (64<-LB)
CLGXBR  B3AE RRFe4  A Convert to Logical (64<-BB)
CEFR    B3B4 RRE    . Convert from Fixed (SH<-32)
CDFR    B3B5 RRE    . Convert from Fixed (LH<-32)
CXFR    B3B6 RRE    . Convert from Fixed (EH<-32)
CFER    B3B8 RRFe   A Convert to Fixed (32<-SH)
CFDR    B3B9 RRFe   A Convert to Fixed (32<-LH)
CFXR    B3BA RRFe   A Convert to Fixed (32<-EH)
LDGR    B3C1 RRE    . Load FPR from GR (L<-64)
CEGR    B3C4 RRE    . Convert from Fixed (SH<-64)
CDGR    B3C5 RRE    . Convert from Fixed (LH<-64)
CXGR    B3C6 RRE    . Convert from Fixed (EH<-64)
CGER    B3C8 RRFe   A Convert to Fixed (64<-SH)
CGDR    B3C9 RRFe   A Convert to Fixed (64<-LH)
CGXR    B3CA RRFe   A Convert to Fixed (64<-EH)
LGDR    B3CD RRE    . Load GR from FPR (64<-L)
MDTR    B3D0 RRFa   A Multiply (LD)
DDTR    B3D1 RRFa   A Divide (LD)
ADTR    B3D2 RRFa   A Add (LD)
SDTR    B3D3 RRFa   A Subtract (LD)
LDETR   B3D4 RRFd   . Load Lengthened (LD<-SD)
LEDTR   B3D5 RRFe4  . Load Rounded (SD<-LD)
LTDTR   B3D6 RRE    A Load and Test (LD)
FIDTR   B3D7 RRFe4  . Load FP Integer (LD)
MXTR    B3D8 RRFa   A Multiply (ED)
DXTR    B3D9 RRFa   A Divide (ED)
AXTR    B3DA RRFa   A Add (ED)
SXTR    B3DB RRFa   A Subtract (ED)
LXDTR   B3DC RRFd   . Load Lengthened (ED<-LD)
LDXTR   B3DD RRFe4  . Load Rounded (LD<-ED)
LTXTR   B3DE RRE    A Load and Test (ED)
FIXTR   B3DF RRFe4  . Load FP Integer (ED)
KDTR    B3E0 RRE    C Compare and Signal (LD)
CGDTR   B3E1 RRFe   A Convert to Fixed (64<-LD)
CUDTR   B3E2 RRE    . Convert to Unsigned Packed (64<-LD)
CSDTR   B3E3 RRFd   . Convert to Signed Packed (64<-LD)
CDTR    B3E4 RRE    C Compare (LD)
EEDTR   B3E5 RRE    . Extract Biased Exponent (64<-LD)
ESDTR   B3E7 RRE    . Extract Significance (64<-LD)
KXTR    B3E8 RRE    C Compare and Signal (ED)
CGXTR   B3E9 RRFe   A Convert to Fixed (64<-ED)
CUXTR   B3EA RRE    . Convert to Unsigned Packed (128<-ED)
CSXTR   B3EB RRFd   . Convert to Signed Packed (128<-ED)
CXTR    B3EC RRE    C Compare (ED)
EEXTR   B3ED RRE    . Extract Biased Exponent (64<-ED)
ESXTR   B3EF RRE    . Extract Significance (64<-ED)
CDGTR   B3F1 RRE    . Convert from Fixed (LD<-64)
CDUTR   B3F2 RRE    . Convert from Unsigned Packed (LD<-64)
CDSTR   B3F3 RRE    . Convert from Signed Packed (LD<-64)
CEDTR   B3F4 RRE    C Compare Biased Exponent (LD)
QADTR   B3F5 RRFb4  . Quantize (LD)
IEDTR   B3F6 RRFb   . Insert Biased Exponent (LD<-64)
RRDTR   B3F7 RRFb4  . Reround (LD)
CXGTR   B3F9 RRE    . Convert from Fixed (ED<-64)
CXUTR   B3FA RRE    . Convert from Unsigned Packed (ED<-128)
CXSTR   B3FB RRE    . Convert from Signed Packed (ED<-128)
CEXTR   B3FC RRE    C Compare Biased Exponent (ED)
QAXTR   B3FD RRFb4  . Quantize (ED)
IEXTR   B3FE RRFb   . Insert Biased Exponent (ED<-64)
RRXTR   B3FF RRFb4  . Reround (ED)
STCTL   B6   RSA    . Store Control (32) =hM(4)
LCTL    B7   RSA    . Load Control (32) =hM(4)
LPGR    B900 RRE    A Load Positive (64)
LNGR    B901 RRE    A Load Negative (64)
LTGR    B902 RRE    A Load and Test (64)
LCGR    B903 RRE    A Load Complement (64)
LGR     B904 RRE    . Load (64)
LURAG   B905 RRE    . Load Using Real Address (64)
LGBR    B906 RRE    . Load Byte (64<-8)
LGHR    B907 RRE    . Load Halfword (64<-16)
AGR     B908 RRE    A Add (64)
SGR     B909 RRE    A Subtract (64)
ALGR    B90A RRE    A Add Logical (64)
SLGR    B90B RRE    A Subtract Logical (64)
MSGR    B90C RRE    A Multiply Single (64)
DSGR    B90D RRE    A Divide Single (64)
EREGG   B90E RRE    . Extract Stacked Registers (64)
LRVGR   B90F RRE    . Load Reversed (64)
LPGFR   B910 RRE    A Load Positive (64<-32)
LNGFR   B911 RRE    A Load Negative (64<-32)
LTGFR   B912 RRE    A Load and Test (64<-32)
LCGFR   B913 RRE    A Load Complement (64<-32)
LGFR    B914 RRE    . Load (64<-32)
LLGFR   B916 RRE    . Load Logical (64<-32)
LLGTR   B917 RRE    . Load Logical 31-Bits (64<-31)
AGFR    B918 RRE    A Add (64<-32)
SGFR    B919 RRE    A Subtract (64<-32)
ALGFR   B91A RRE    A Add Logical (64<-32)
SLGFR   B91B RRE    A Subtract Logical (64<-32)
MSGFR   B91C RRE    A Multiply Single (64<-32)
DSGFR   B91D RRE    A Divide Single (64<-32)
KMAC    B91E RRE    c Compute Message Authentication Code
LRVR    B91F RRE    . Load Reversed (32)
CGR     B920 RRE    C Compare (64)
CLGR    B921 RRE    C Compare Logical (64)
STURG   B925 RRE    . Store Using Real Address (64)
LBR     B926 RRE    . Load Byte (32<-8)
LHR     B927 RRE    . Load Halfword (32<-16)
PCKMO   B928 RRE    . Perform Crypto Key Management Operations
KMA     B929 RRFb   c Cipher Message with Authentication
KMF     B92A RRE    c Cipher Message with Cipher Feedback
KMO     B92B RRE    c Cipher Message with Output Feedback
PCC     B92C RRE0   c Perform Crypto Computation
KMCTR   B92D RRFb   c Cipher Message with Counter
KM      B92E RRE    c Cipher Message
KMC     B92F RRE    c Cipher Message with Chaining
CGFR    B930 RRE    C Compare (64<-32)
CLGFR   B931 RRE    C Compare Logical (64<-32)
DFLTCC  B939 RRFa   c Deflate Conversion Call
KDSA    B93A RRE    c Compute Digital Signature Authentication
PRNO    B93C RRE    c Perform Random Number Operation
KIMD    B93E RRE    c Compute Intermediate Message Digest
KLMD    B93F RRE    c Compute Last Message Digest
CFDTR   B941 RRFe4  A Convert to Fixed (32<-LD)
CLGDTR  B942 RRFe4  A Convert to Logical (64<-LD)
CLFDTR  B943 RRFe4  A Convert to Logical (32<-LD)
BCTGR   B946 RRE    . Branch on Count (64)
CFXTR   B949 RRFe4  A Convert to Fixed (32<-ED)
CLGXTR  B94A RRFe4  A Convert to Logical (64<-ED)
CLFXTR  B94B RRFe4  A Convert to Logical (32<-ED)
CDFTR   B951 RRFe4  . Convert from Fixed (LD<-32)
CDLGTR  B952 RRFe4  . Convert from Logical (LD<-64)
CDLFTR  B953 RRFe4  . Convert from Logical (LD<-32)
CXFTR   B959 RRFe4  . Convert from Fixed (ED<-32)
CXLGTR  B95A RRFe4  . Convert from Logical (ED<-64)
CXLFTR  B95B RRFe4  . Convert from Logical (ED<-32)
CGRT    B960 RRFc3  c Compare and Trap (64)
CLGRT   B961 RRFc3  c Compare Logical and Trap (64)
NNGRK   B964 RRFa   A Not And (64)
OCGRK   B965 RRFa   A Or with Complement (64)
NOGRK   B966 RRFa   A Not Or (64)
NXGRK   B967 RRFa   A Not Exlusive Or (64)
CRT     B972 RRFc3  c Compare and Trap (32)
CLRT    B973 RRFc3  c Compare Logical and Trap (32)
NNRK    B974 RRFa   A Not And (32)
OCRK    B975 RRFa   A Or with Complement (32)
NORK    B976 RRFa   A Not Or (32)
NXRK    B977 RRFa   A Not Exlusive Or (32)
NGR     B980 RRE    A And (64)
OGR     B981 RRE    A Or (64)
XGR     B982 RRE    A Exclusive Or (64)
FLOGR   B983 RRE    c Find Leftmost One
LLGCR   B984 RRE    . Load Logical Character (64<-8)
LLGHR   B985 RRE    . Load Logical Halfword (64<-16)
MLGR    B986 RRE    A Multiply Logical (128<-64)
DLGR    B987 RRE    A Divide Logical (64<-128)
ALCGR   B988 RRE    A Add Logical with Carry (64)
SLBGR   B989 RRE    A Subtract Logical with Borrow (64)
CSPG    B98A RRE    C Compare and Swap and Purge (64)
EPSW    B98D RRE    . Extract PSW
IDTE    B98E RRFb4  . Invalidate DAT Table Entry
CRDTE   B98F RRFb4  C Compare and Replace DAT Table Entry
TRTT    B990 RRFc   c Translate Two to Two
TRTO    B991 RRFc   c Translate Two to One
TROT    B992 RRFc   c Translate One to Two
TROO    B993 RRFc   c Translate One to One
LLCR    B994 RRE    . Load Logical Character (32<-8)
LLHR    B995 RRE    . Load Logical Halfword (32<-16)
MLR     B996 RRE    A Multiply Logical (64<-32)
DLR     B997 RRE    A Divide Logical (32<-64)
ALCR    B998 RRE    A Add Logical with Carry (32)
SLBR    B999 RRE    A Subtract Logical with Borrow (32)
EPAIR   B99A RRE1   . Extract Primary ASN and Instance
ESAIR   B99B RRE1   . Extract Secondary ASN and Instance
ESEA    B99D RRE1   . Extract and Set Extended authority
PTI     B99E RRE    . Program Transfer with Instance
SSAIR   B99F RRE1   . Set Secondary ASN with Instance
TPEI    B9A1 RRE    c Test Pending External Interruption
PTF     B9A2 RRE1   c Perform Topology Function
LPTEA   B9AA RRFb4  c Load Page Table Entry Address
IRBM    B9AC RRE    . Insert Reference Bits Multiple
RRBM    B9AE RRE    . Reset Reference Bits Multiple
PFMF    B9AF RRE    . Perform Frame Management Function
CU14    B9B0 RRFc   c Convert UTF-8 to UTF-32
CU24    B9B1 RRFc   c Convert UTF-16 to UTF-32
CU41    B9B2 RRE    c Convert UTF-32 to UTF-8
CU42    B9B3 RRE    c Convert UTF-32 to UTF-16
TRTRE   B9BD RRFc   c Translate and Test Reverse Extended
SRSTU   B9BE RRE    c Search String UNICODE
TRTE    B9BF RRFc   c Translate and Test Extended
SELFHR  B9C0 RRFa4  S Select High (32)
AHHHR   B9C8 RRFa   A Add High (32)
SHHHR   B9C9 RRFa   A Subtract High (32)
ALHHHR  B9CA RRFa   A Add Logical High (32)
SLHHHR  B9CB RRFa   A Subtract Logical High (32)
CHHR    B9CD RRE    C Compare High (32)
CLHHR   B9CF RRE    C Compare Logical High (32)
AHHLR   B9D8 RRFa   A Add High (32)
SHHLR   B9D9 RRFa   A Subtract High (32)
ALHHLR  B9DA RRFa   A Add Logical High (32)
SLHHLR  B9DB RRFa   A Subtract Logical High (32)
CHLR    B9DD RRE    C Compare High (32)
CLHLR   B9DF RRE    C Compare Logical High (32)
LOCFHR  B9E0 RRFc3  O Load High on Condition (32)
POPCNT  B9E1 RRFc   c Population Count
LOCGR   B9E2 RRFc3  O Load on Condition (64)
SELGR   B9E3 RRFa4  S Select (64)
NGRK    B9E4 RRFa   A And (64)
OGRK    B9E6 RRFa   A Or (64)
XGRK    B9E7 RRFa   A Exclusive Or (64)
AGRK    B9E8 RRFa   A Add (64)
SGRK    B9E9 RRFa   A Subtract (64)
ALGRK   B9EA RRFa   A Add Logical (64)
SLGRK   B9EB RRFa   A Subtract Logical (64)
MGRK    B9EC RRFa   A Multiply (128<-64)
MSGRKC  B9ED RRFa   A Multiply Single (64)
SELR    B9F0 RRFa4  S Select (32)
LOCR    B9F2 RRFc3  O Load on Condition (32)
NRK     B9F4 RRFa   A And (32)
ORK     B9F6 RRFa   A Or (32)
XRK     B9F7 RRFa   A Exclusive Or (32)
ARK     B9F8 RRFa   A Add (32)
SRK     B9F9 RRFa   A Subtract (32)
ALRK    B9FA RRFa   A Add Logical (32)
SLRK    B9FB RRFa   A Subtract Logical (32)
MSRKC   B9FD RRFa   A Multiply Single (32)
CS      BA   RSA    C Compare And Swap =4
CDS     BB   RSA    C Compare Double And Swap =8
CLM     BD   RSb    C Compare Logical Char. under Mask (low)
STCM    BE   RSb    . Store Characters under Mask
ICM     BF   RSb    A Insert Characters under Mask
LARL    C00  RILb  R8 Load Address Relative Long
LGFI    C01  RILa   . Load Immediate (64<-32)
BRCL    C04  RILc   R Branch Relative on Condition Long
JASL    C05  RILb  R4 Branch Relative and Save Long
XIHF    C06  RILax  A Exclusive-Or Immediate (high) (0-31)
XILF    C07  RILax  A Exclusive-Or Immediate (low) (32-63)
IIHF    C08  RILax  . Insert Immediate (high) (0-31)
IILF    C09  RILax  . Insert Immediate (low) (32-63)
NIHF    C0A  RILax  A And Immediate (high) (0-31)
NILF    C0B  RILax  A And Immediate (low) (32-63)
OIHF    C0C  RILax  A Or Immediate (high) (0-31)
OILF    C0D  RILax  A Or Immediate (low) (32-63)
LLIHF   C0E  RILa   . Load Logical Immediate (high) (0-31)
LLILF   C0F  RILa   . Load Logical Immediate (low) (32-63)
MSGFI   C20  RILa   A Multiply Single Immediate (64<-32)
MSFI    C21  RILa   A Multiply Single Immediate (32)
SLGFI   C24  RILa   A Subtract Logical Immediate (64<-32)
SLFI    C25  RILa   A Subtract Logical Immediate (32)
AGFI    C28  RILa   A Add Immediate (64<-32)
AFI     C29  RILa   A Add Immediate (32)
ALGFI   C2A  RILa   A Add Logical Immediate (64<-32)
ALFI    C2B  RILa   A Add Logical Immediate (32)
CGFI    C2C  RILa   C Compare Immediate (64<-32)
CFI     C2D  RILa   C Compare Immediate (32)
CLGFI   C2E  RILa   C Compare Logical Immediate (64<-32)
CLFI    C2F  RILa   C Compare Logical Immediate (32)
LLHRL   C42  RILb  R8 Load Logical Halfword Relative Long (32<-16) =2
LGHRL   C44  RILb  R8 Load Halfword Relative Long (64<-16) =2
LHRL    C45  RILb  R8 Load Halfword Relative Long (32<-16) =2
LLGHRL  C46  RILb  R8 Load Logical Halfword Relative Long (64<-16) =2
STHRL   C47  RILb  R8 Store Halfword Relative Long (16) =2
LGRL    C48  RILb  R8 Load Relative Long (64) =8
STGRL   C4B  RILb  R8 Store Relative Long (64) =8
LGFRL   C4C  RILb  R8 Load Relative Long (64<-32) =4
LRL     C4D  RILb  R8 Load Relative Long (32) =4
LLGFRL  C4E  RILb  R8 Load Logical Relative Long (64<-32) =4
STRL    C4F  RILb  R8 Store Relative Long (32) =4
BPRP    C5   MII    . Branch Prediction Relative Preload
EXRL    C60  RILb  R8 Execute Relative Long
PFDRL   C62  RILc   . Prefetch Data Relative Long
CGHRL   C64  RILb   C Compare Halfword Relative Long (64<-16) =2
CHRL    C65  RILb   C Compare Halfword Relative Long (32<-16) =2
CLGHRL  C66  RILb   C Compare Logical Relative Long (64<-16) =2
CLHRL   C67  RILb   C Compare Logical Relative Long (32<-16) =2
CGRL    C68  RILb   C Compare Relative Long (64) =8
CLGRL   C6A  RILb   C Compare Logical Relative Long (64) =8
CGFRL   C6C  RILb   C Compare Relative Long (64<-32) =4
CRL     C6D  RILb   C Compare Relative Long (32) =4
CLGFRL  C6E  RILb   C Compare Logical Relative Long (64<-32) =4
CLRL    C6F  RILb   C Compare Logical Relative Long (32) =4
BPP     C7   SMI    . Branch Prediction Preload
MVCOS   C80  SSF    c Move with Optional Specifications
ECTG    C81  SSF    . Extract CPU Time =8
CSST    C82  SSF    C Compare and Swap and Store
LPD     C84  SSF    . Load Pair Disjoint (32)
LPDG    C85  SSF    . Load Pair Disjoint (64)
BRCTH   CC6  RILb  R8 Branch Relative on Count High (32)
AIH     CC8  RILa   A Add Immediate High (32)
ALSIH   CCA  RILa   A Add Logical with Signed Immediate High (32)
ALSIHN  CCB  RILa   A Add Logical with Signed Immediate High (32)
CIH     CCD  RILa   C Compare Immediate High (32)
CLIH    CCF  RILa   C Compare Logical Immediate High (32)
TRTR    D0   RILa   c Translate and Test Reverse
MVN     D1   SSa    . Move Numerics
MVC     D2   SSa    . Move Character
MVZ     D3   SSa    . Move Zones
NC      D4   SSa    A And Character
CLC     D5   SSa    C Compare Logical Character
OC      D6   SSa    A Or Character
XC      D7   SSa    A Exclusive-Or Character
MVCK    D9   SSd    c Move with Key
MVCP    DA   SSd    c Move to Primary
MVCS    DB   SSd    c Move to Secondary
TR      DC   SSa    . Translate
TRT     DD   SSa    c Translate and Test
ED      DE   SSa    A Edit
EDMK    DF   SSa    A Edit and MarK
PKU     E1   SSf    . Pack Unicode
UNPKU   E2   SSa    c Unpack Unicode
LTG     E302 RXYa   A Load and Test (64) =8
LRAG    E303 RXYa   c Load Real Address (64)
LG      E304 RXYa   . Load (64) =8
CVBY    E306 RXYa   . Convert to Binary (32) =8
AG      E308 RXYa   A Add (64) =8
SG      E309 RXYa   A Subtract (64) =8
ALG     E30A RXYa   A Add Logical (64) =8
SLG     E30B RXYa   A Subtract Logical (64) =8
MSG     E30C RXYa   A Multiply Single (64) =8
DSG     E30D RXYa   A Divide Single (64) =8
CVBG    E30E RXYa   . Convert to Binary (64) =16
LRVG    E30F RXYa   . Load Reversed (64) =8
LT      E312 RXYa   A Load and Test (32) =4
LRAY    E313 RXYa   c Load Real Address (32)
LGF     E314 RXYa   . Load (64<-32) =4
LGH     E315 RXYa   . Load Halfword (64<-16) =2
LLGF    E316 RXYa   . Load Logical (64<-32) =4
LLGT    E317 RXYa   . Load Logical 31-Bits (64<-31) =4
AGF     E318 RXYa   A Add (64<-32) =4
SGF     E319 RXYa   A Subtract (64<-32) =4
ALGF    E31A RXYa   A Add Logical (64<-32) =4
SLGF    E31B RXYa   A Subtract Logical (64<-32) =4
MSGF    E31C RXYa   A Multiply Single (64<-32) =4
DSGF    E31D RXYa   A Divide Single (64<-32) =4
LRV     E31E RXYa   . Load Reversed (32) =4
LRVH    E31F RXYa   . Load Reversed (16) =2
CG      E320 RXYa   C Compare (64) =8
CLG     E321 RXYa   C Compare Logical (64) =8
STG     E324 RXYa   . Store (64) =8
NTSTG   E325 RXYa   . NonTransactional Store (64)
CVDY    E326 RXYa   . Convert to Decimal (32) =8
LZRG    E32A RXYa   . Load and Zero Rightmost Byte (64) =8
CVDG    E32E RXYa   . Convert to Decimal (64) =16
STRVG   E32F RXYa   . Store Reversed (64) =8
CGF     E330 RXYa   C Compare (64<-32) =4
CLGF    E331 RXYa   C Compare Logical (64<-32) =4
LTGF    E332 RXYa   A Load and Test (64<-32) =4
CGH     E334 RXYa   C Compare Halfword (64<-16) =2
PFD     E336 RXYb   . PreFetch Data
AGH     E338 RXYa   A Add Halfword (64<-16) =2
SGH     E339 RXYa   A Subtract Halfword (64<-16) =2
LLZRGF  E33A RXYa   . Load Logical and Zero Rightmost Byte (64<-32) =4
LZRF    E33B RXYa   . Load and Zero Rightmost Byte (32) =4
MGH     E33C RXYa   A Multiply Halfword (64<-16) =2
STRV    E33E RXYa   . Store Reversed (32) =4
STRVH   E33F RXYa   . Store Reversed (16) =2
BCTG    E346 RXYa   . Branch on Count (64) =8
BIC     E347 RXYb   . Branch Indirect on Condition
LLGFSG  E348 RXYa   . Load Logical and Shift Guarded (64<-32) =4
STGSC   E349 RXYa   . Store Guarded Storage Controls
LGG     E34C RXYa   . Load Guarded (64) =8
LGSC    E34D RXYa   . Load Guarded Storage Controls
STY     E350 RXYa   . Store (32) =4
MSY     E351 RXYa   A Multiply Single (32) =4
MSC     E353 RXYa   A Multiply single (32) =4
NY      E354 RXYa   A And (32) =4
CLY     E355 RXYa   C Compare Logical (32) =4
OY      E356 RXYa   A Or (32) =4
XY      E357 RXYa   A Exclusive-Or (32) =4
LY      E358 RXYa   . Load (32) =4
CY      E359 RXYa   C Compare (32) =4
AY      E35A RXYa   A Add (32) =4
SY      E35B RXYa   A Subtract (32) =4
MFY     E35C RXYa   A Multiply (64<-32) =4
ALY     E35E RXYa   A Add Logical (32) =4
SLY     E35F RXYa   A Subtract Logical (32) =4
STHY    E370 RXYa   . Store Halfword (16) =2
LAY     E371 RXYa   . Load Address
STCY    E372 RXYa   . Store Character =1
ICY     E373 RXYa   . Insert Character =1
LAEY    E375 RXYa   . Load Address Extended
LB      E376 RXYa   . Load Byte (32<-8) =1
LGB     E377 RXYa   . Load Byte (64<-8) =1
LHY     E378 RXYa   . Load Halfword (32<-16) =2
CHY     E379 RXYa   C Compare Halfword (32<-16) =2
AHY     E37A RXYa   A Add Halfword (32<-16) =2
SHY     E37B RXYa   A Subtract Halfword (32<-16) =2
MHY     E37C RXYa   A Multiply Halfword (32<-16) =2
NG      E380 RXYa   A And (64) =8
OG      E381 RXYa   A Or (64) =8
XG      E382 RXYa   A Exclusive-Or (64) =8
MSGC    E383 RXYa   A Multiply Single (64) =8
MG      E384 RXYa   A Multiply (128<-64) =8
LGAT    E385 RXYa   . Load and Trap (64) =8
MLG     E386 RXYa   A Multiply Logical (128<-64) =8
DLG     E387 RXYa   A Divide Logical (64<-128) =8
ALCG    E388 RXYa   A Add Logical with Carry (64) =8
SLBG    E389 RXYa   A Subtract Logical with Borrow (64) =8
STPQ    E38E RXYa   . Store Pair to Quadword =16
LPQ     E38F RXYa   . Load Pair from Quadword (64+64<-128) =16
LLGC    E390 RXYa   . Load Logical Character (64<-8) =1
LLGH    E391 RXYa   . Load Logical Halfword (64<-16) =2
LLC     E394 RXYa   . Load Logical Character (32<-8) =1
LLH     E395 RXYa   . Load Logical Halfword (32<-16) =2
ML      E396 RXYa   A Multiply Logical (64<-32) =4
DL      E397 RXYa   A Divide Logical (32<-64) =4
ALC     E398 RXYa   A Add Logical with Carry (32) =4
SLB     E399 RXYa   A Subtract Logical with Borrow (32) =4
LLGTAT  E39C RXYa   . Load Logical 31-Bits and Trap (64<-31) =4
LLGFAT  E39D RXYa   . Load Logical and Trap (64<-32) =4
LAT     E39F RXYa   . Load and Trap (32L<-32) =4
LBH     E3C0 RXYa   . Load Byte High (32<-8) =1
LLCH    E3C2 RXYa   . Load Logical Character High (32<-8) =1
STCH    E3C3 RXYa   . Store Character High (8) =1
LHH     E3C4 RXYa   . Load Halfword High (32<-16) =2
LLHH    E3C6 RXYa   . Load Logical Halfword High (32<-16) =2
STHH    E3C7 RXYa   . Store Halfword High (16) =2
LFHAT   E3C8 RXYa   . Load High and Trap (32H<-16) =2
LFH     E3CA RXYa   . Load High (32) =4
STFH    E3CB RXYa   . Store High (32) =4
CHF     E3CD RXYa   C Compare High (32) =4
CLHF    E3CF RXYa   C Compare Logical High (32) =4
LASP    E500 SSE    c Load Address Space Parameters
TPROT   E501 SSE    c Test Protection
STRAG   E502 SSE    . Store Real Address =8
MVCSK   E50E SSE    . Move with Source Key
MVCDK   E50F SSE    . Move with Destination Key
MVHHI   E544 SIL    . Move (16<-16) =2
MVGHI   E548 SIL    . Move (64<-16) =8
MVHI    E54C SIL    . Move (32<-16) =4
CHHSI   E554 SIL    C Compare Halfword Immediate (16<-16)
CLHHSI  E555 SIL    C Compare Logical Immediate (16<-16)
CGHSI   E558 SIL    C Compare Halfword Immediate (64<-16)
CLGHSI  E559 SIL    C Compare Logical Immediate (64<-16)
CHSI    E55C SIL    C Compare Halfword Immediate (32<-16)
CLFHSI  E55D SIL    C Compare Logical Immediate (32<-16)
TBEGIN  E560 SIL    c Transaction Begin (noncontrained)
TBEGINC E561 SIL    c Transaction Begin (constrained)
VPKZ    E634 VSI    . Vector Pack Zoned
VLRL    E635 VSI    . Vector Load Rightmost with Length
VLRLR   E637 VRSd   . Vector Load Rightmost with Length
VUPKZ   E63C VSI    . Vector Unpack Zoned
VSTRL   E63D VSI    . Vector Store Rightmost with Length
VSTRLR  E63F VRSd   . Vector Store Rightmost with Length
VLIP    E649 VRIh   . Vector Load Immediate Decimal
VCVB    E650 VRRi   c Vector Convert to Binary
VCVBG   E652 VRRi   c Vector Convert to Binary
VCVD    E658 VRIi   c Vector Convert to Decimal
VSRP    E659 VRIg   c Vector Shift and Round Decimal
VCVDG   E65A VRIi   c Vector Convert to Decimal
VPSOP   E65B VRIg   c Vector Perform Sign Operation Decimal
VTP     E65F VRRg   c Vector Test Decimal
VAP     E671 VRIf   c Vector Add Decimal
VSP     E673 VRIf   c Vector Subtract Decimal
VCP     E677 VRRh   c Vector Compare Decimal
VMP     E678 VRIf   c Vector Multiply Decimal
VMSP    E679 VRIf   c Vector Multiply and Shift Decimal
VDP     E67A VRIf   c Vector Divide Decimal
VRP     E67B VRIf   c Vector Remainder Decimal
VSDP    E67E VRIf   c Vector Shift and Divide Decimal
VLEB    E700 VRX3   . Vector Load Element (8)
VLEH    E701 VRX3   . Vector Load Element (16)
VLEG    E702 VRX3   . Vector Load Element (64)
VLEF    E703 VRX3   . Vector Load Element (32)
VLLEZ   E704 VRX3   . Vector Load Logical Element and ZERO
VLREP   E705 VRX3   . Vector Load and Replicate
VL      E706 VRX    . Vector Load
VLBB    E707 VRX3   . Vector Load to Block Boundary
VSTEB   E708 VRX3   . Vector Store Element (8)
VSTEH   E709 VRX3   . Vector Store Element (16)
VSTEG   E70A VRX3   . Vector Store Element (64)
VSTEF   E70B VRX3   . Vector Store Element (32)
VST     E70E VRX    . Vector Store
VGEG    E712 VRV    . Vector Gather Element (64)
VGEF    E713 VRV    . Vector Gather Element (32)
VSCEG   E71A VRV    . Vector Scatter Element (64)
VSCEF   E71B VRV    . Vector Scatter Element (32)
VLGV    E721 VRSc   . Vector Load GR from VR Element
VLVG    E722 VRSb4  . Vector Load VR Element from GR
LCBB    E727 RXE3   c Load Count to Block Boundary
VESL    E730 VRSa   . Vector Element Shift Left
VERLL   E733 VRSa   . Vector Element Rotate Left Logical
VLM     E736 VRSa   . Vector Load Multiple
VLL     E737 VRSb   . Vector Load with Length
VESRL   E738 VRSa   . Vector Element Shift Right Logical
VESRA   E73A VRSa   . Vector Element Shift Right Arithmetic
VSTM    E73E VRSa   . Vector Store Multiple
VSTL    E73F VRSb   . Vector Store with Length
VLEIB   E740 VRIa3  . Vector Load Element Immediate (8)
VLEIH   E741 VRIa3  . Vector Load Element Immediate (16)
VLEIG   E742 VRIa3  . Vector Load Element Immediate (64)
VLEIF   E743 VRIa3  . Vector Load Element Immediate (32)
VGBM    E744 VRIa   . Vector Generate Byte Mask
VREPI   E745 VRIa3  . Vector Replicate Immediate
VGM     E746 VRIb   . Vector Generate Mask
VFTCI   E74A VRIe   c Vector FP Test Data Class Immediate
VREP    E74D VRIc   . Vector Replicate
VPOPCT  E750 VRRa3  . Vector Population Count
VCTZ    E752 VRRa3  . Vector Count Trailing Zeros
VCLZ    E753 VRRa3  . Vector Count Leading Zeros
VLR     E756 VRRa   . Vector Load
VISTR   E75C VRRa2  c Vector Isolate String
VSEG    E75F VRRa3  . Vector Sign Extend to Doubleword
VMRL    E760 VRRc4  . Vector Merge Low
VMRH    E761 VRRc4  . Vector Merge High
VLVGP   E762 VRRf   . Vector Load VR from GRS Disjoint
VSUM    E764 VRRc4  . Vector Sum Across Word
VSUMG   E765 VRRc4  . Vector Sum Across Doubleword
VCKSM   E766 VRRc3  . Vector Checksum
VSUMQ   E767 VRRc4  . Vector Sum Across Quadword
VN      E768 VRRc3  . Vector and
VNC     E769 VRRc3  . Vector and with COMPLEMENT
VO      E76A VRRc3  . Vector Or
VNO     E76B VRRc3  . Vector Nor
VNX     E76C VRRc3  . Vector Not Exclusive Or
VX      E76D VRRc3  . Vector Exclusive Or
VNN     E76E VRRc3  . Vector Nand
VOC     E76F VRRc3  . Vector Or with Complement
VESLV   E770 VRRc4  . Vector Element Shift Left
VERIM   E772 VRId5  . Vector Element Rotate and Insert Under Mask
VERLLV  E773 VRRc4  . Vector Element Rotate Left Logical
VSL     E774 VRRc3  . Vector Shift Left
VSLB    E775 VRRc3  . Vector Shift Left by Byte
VSLDB   E777 VRId   . Vector Shift Left Double by Byte
VESRLV  E778 VRRc4  . Vector Element Shift Right Logical
VESRAV  E77A VRRc4  . Vector Element Shift Right Arithmetic
VSRL    E77C VRRc3  . Vector Shift Right Logical
VSRLB   E77D VRRc3  . Vector Shift Right Logical by Byte
VSRA    E77E VRRc3  . Vector Shift Right Arithmetic
VSRAB   E77F VRRc3  . Vector Shift Right Arithmetic by Byte
VFEE    E780 VRRb4  c Vector Find Element Equal
VFENE   E781 VRRb4  c Vector Find Element Not Equal
VFAE    E782 VRRb4  c Vector Find Any Element Equal
VPDI    E784 VRRc4  . Vector Permute Doubleword Immediate
VBPERM  E785 VRRc3  . Vector Bit Permute
VSTRC   E78A VRRd5  c Vector String Range Compare
VSTRS   E78B VRRd5  c Vector String Search
VPERM   E78C VRRe   . Vector Permute
VSEL    E78D VRRe   . Vector Select
VFMS    E78E VRRe6  . Vector FP Multiply and Subtract
VFMA    E78F VRRe6  . Vector FP Multiply and Add
VPK     E794 VRRc4  . Vector Pack
VPKLS   E795 VRRb   c Vector Pack Logical Saturate
VPKS    E797 VRRb   c Vector Pack Saturate
VFNMS   E79E VRRe6  . Vector FP Negative Multiply and Subtract
VFNMA   E79F VRRe6  . Vector FP Negative Multiply and Add
VMLH    E7A1 VRRc4  . Vector Multiply Logical High
VML     E7A2 VRRc4  . Vector Multiply Low
VMH     E7A3 VRRc4  . Vector Multiply High
VMLE    E7A4 VRRc4  . Vector Multiply Logical Even
VMLO    E7A5 VRRc4  . Vector Multiply Logical Odd
VME     E7A6 VRRc4  . Vector Multiply Even
VMO     E7A7 VRRc4  . Vector Multiply Odd
VMALH   E7A9 VRRd   . Vector Multiply and Add Logical High
VMAL    E7AA VRRd   . Vector Multiply and Add Low
VMAH    E7AB VRRd   . Vector Multiply and Add High
VMALE   E7AC VRRd   . Vector Multiply and Add Logical Even
VMALO   E7AD VRRd   . Vector Multiply and Add Logical Odd
VMAE    E7AE VRRd   . Vector Multiply and Add Even
VMAO    E7AF VRRd   . Vector Multiply and Add Odd
VGFM    E7B4 VRRc4  . Vector Galois Field Multiply Sum
VMSL    E7B8 VRRd6  . Vector Multiply Sum Logical
VACCC   E7B9 VRRd   . Vector Add with Carry Compute Carry
VAC     E7BB VRRd   . Vector Add with Carry
VGFMA   E7BC VRRd   . Vector Galois Field Multiply Sum and Accumulate
VSBCBI  E7BD VRRd   . Vector Subtract with Borrow Compute Borrow Indication
VSBI    E7BF VRRd   . Vector Subtract with Borrow Indication
VCLGD   E7C0 VRRa5  . Vector FP Convert to Logical 64-bit
VCDLG   E7C1 VRRa5  . Vector FP Convert from Logical 64-bit
VCGD    E7C2 VRRa5  . Vector FP Convert to Fixed 64-bit
VCDG    E7C3 VRRa5  . Vector FP Convert from Fixed 64-bit
VFLL    E7C4 VRRa4  . Vector FP Load Lengthened
VFLR    E7C5 VRRa5  . Vector FP Load Rounded
VFI     E7C7 VRRa5  . Vector Load FP Integer
WFK     E7CA VRRa4  c Vector FP Compare and Signal Scalar
WFC     E7CB VRRa4  c Vector FP Compare Scalar
VFPSO   E7CC VRRa5  . Vector FP Perform Sign Operation
VFSQ    E7CE VRRa4  . Vector FP Square Root
VUPLL   E7D4 VRRa3  . Vector Unpack Logical Low
VUPLH   E7D5 VRRa3  . Vector Unpack Logical High
VUPL    E7D6 VRRa3  . Vector Unpack Low
VUPH    E7D7 VRRa3  . Vector Unpack High
VTM     E7D8 VRRa   M Vector Test Under Mask
VECL    E7D9 VRRa3  c Vector Element Compare Logical
VEC     E7DB VRRa3  c Vector Element Compare
VLC     E7DE VRRa3  . Vector Load Complement
VLP     E7DF VRRa3  . Vector Load Positive
VFS     E7E2 VRRc5  . Vector FP Subtract
VFA     E7E3 VRRc5  . Vector FP Add
VFD     E7E5 VRRc5  . Vector FP Divide
VFM     E7E7 VRRc5  . Vector FP Multiply
VFCE    E7E8 VRRc6  c Vector FP Compare Equal
VFCHE   E7EA VRRc6  c Vector FP Compare High OR Equal
VFCH    E7EB VRRc6  . Vector FP Compare High
VFMIN   E7EE VRRc6  . Vector FP Minimum
VFMAX   E7EF VRRc6  . Vector FP Maximum
VAVGL   E7F0 VRRc4  . Vector Average Logical
VACC    E7F1 VRRc4  . Vector Add Compute Carry
VAVG    E7F2 VRRc4  . Vector Average
VA      E7F3 VRRc4  . Vector Add
VSCBI   E7F5 VRRc4  . Vector Subtract Compute Borrow Indication
VS      E7F7 VRRc4  . Vector Subtract
VCEQ    E7F8 VRRb   c Vector Compare Equal
VCHL    E7F9 VRRb   c Vector Compare High Logical
VCH     E7FB VRRb   c Vector Compare High
VMNL    E7FC VRRc4  . Vector Minimum Logical
VMXL    E7FD VRRc4  . Vector Maximum Logical
VMN     E7FE VRRc4  . Vector Minimum
VMX     E7FF VRRc4  . Vector Maximum
MVCIN   E8   SSa    . Move Inverse
PKA     E9   SSf    . Pack ASCII
UNPKA   EA   SSa    c UnPacK ASCII
LMG     EB04 RSYa   . Load Multiple (64)  =hM(8)
SRAG    EB0A RSYas  A Shift Right Single (64)
SLAG    EB0B RSYas  A Shift Left Single (64)
SRLG    EB0C RSYas  . Shift Right Single Logical (64)
SLLG    EB0D RSYas  . Shift Left Single Logical (64)
TRACG   EB0F RSYa   . Trace (64)
CSY     EB14 RSYa   C Compare and Swap (32) =4
RLLG    EB1C RSYas  . Rotate Left Single Logical (64)
RLL     EB1D RSYas  . Rotate Left single Logical
CLMH    EB20 RSYbm  C Compare Logical Char. under Mask (high)
CLMY    EB21 RSYbm  C Compare Logical Char. under Mask (low)
CLT     EB23 RSYb   c Compare Logical and Trap (32) =4
STMG    EB24 RSYa   . Store Multiple (64) =hM(8)
STCTG   EB25 RSYa   . Store Control (64) =hM(8)
STMH    EB26 RSYa   . Store Multiple High (32) =hM(4)
CLGT    EB2B RSYb   c Compare Logical and Trap (64) =8
STCMH   EB2C RSYbm  . Store Characters under Mask (high)
STCMY   EB2D RSYbm  . Store Characters under Mask (low)
LCTLG   EB2F RSYa   . Load Control (64) =hM(8)
CSG     EB30 RSYa   C Compare and Swap (64) =8
CDSY    EB31 RSYa   C Compare Double and Swap (32)
CDSG    EB3E RSYa   C Compare Double and Swap (64)
BXHG    EB44 RSYa   . Branch on Index High (64)
BXLEG   EB45 RSYa   . Branch on Index Low or Equal (64)
ECAG    EB4C RSYa   . Extract CPU Attribute
TMY     EB51 SIYm   M Test under Mask
MVIY    EB52 SIYu   . Move Immediate
NIY     EB54 SIYx   A And Immediate
CLIY    EB55 SIYu   C Compare Logical Immediate
OIY     EB56 SIYx   A Or Immediate
XIY     EB57 SIYx   A Exclusive-Or Immediate
ASI     EB6A SIY    A Add Immediate (32<-8) =4
ALSI    EB6E SIY    A Add Logical with Signed Immediate (32<-8) =4
AGSI    EB7A SIY    A Add Immediate (64<-8) =8
ALGSI   EB7E SIY    A Add Logical with Signed Immediate (64<-8) =8
ICMH    EB80 RSYbm  . Insert Characters under Mask (high)
ICMY    EB81 RSYbm  . Insert Characters under Mask (low)
MVCLU   EB8E RSYa   c Move Long Unicode
CLCLU   EB8F RSYa   C Compare Logical Long Unicode
STMY    EB90 RSYa   . Store Multiple (32)
LMH     EB96 RSYa   . Load Multiple High (32)
LMY     EB98 RSYa   . Load Multiple (32)
LAMY    EB9A RSYa   . Load Access Multiple
STAMY   EB9B RSYa   . Store Access Multiple
TP      EBC0 RSLa   c Test Decimal
SRAK    EBDC RSYas  A Shift Right Single (32)
SLAK    EBDD RSYas  A Shift Left Single (32)
SRLK    EBDE RSYas  . Shift Right Single Logical (32)
SLLK    EBDF RSYas  . Shift Left Single Logical (32)
LOCFH   EBE0 RSYb   O Load High On Condition (32) =4
STOCFH  EBE1 RSYb   O Store High On Condition (32) =4
LOCG    EBE2 RSYb   O Load On Condition (64) =8
STOCG   EBE3 RSYb   O Store On Condition (64) =8
LANG    EBE4 RSYa   . Load and And (64)
LAOG    EBE6 RSYa   A Load and Or (64)
LAXG    EBE7 RSYa   A Load and Exclusive-Or (64)
LAAG    EBE8 RSYa   A Load and Add (64)
LAALG   EBEA RSYa   A Load and Add Logical (64)
LOC     EBF2 RSYb   O Load On Condition (32) =4
STOC    EBF3 RSYb   O Store On Condition (32) =4
LAN     EBF4 RSYa   . Load and And (32)
LAO     EBF6 RSYa   A Load and Or (32)
LAX     EBF7 RSYa   A Load and Exclusive-Or (32)
LAA     EBF8 RSYa   A Load and Add (32)
LAAL    EBFA RSYa   A Load and Add Logical (32)
LOCHI   EC42 RIEg   O Load Halfword Immediate On Condition (32<-16)
JXHG    EC44 RIEe  JX Branch Relative on Index High (64)
JXLEG   EC45 RIEe  JX Branch Relative on Index Low or Equal (64)
LOCGHI  EC46 RIEg   O Load Halfword Immediate On Condition (64<-16)
LOCHHI  EC4E RIEg   O Load Halfword High Immediate On Condition (32<-16)
RISBLG  EC51 RIEf  RO Rotate then Insert Selected Bits Low (64)
RNSBG   EC54 RIEf  RO Rotate then And Selected Bits (64)
RISBG   EC55 RIEf  RO Rotate then Insert Selected Bits (64)
ROSBG   EC56 RIEf  RO Rotate then Or Selected Bits (64)
RXSBG   EC57 RIEf  RO Rotate then Exlusive-Or Selected Bits (64)
RISBGN  EC59 RIEf  RO Rotate then Insert Selected Bits (64)
RISBHG  EC5D RIEf  RO Rotate then Insert Selected Bits High (64)
CGRJ    EC64 RIEb  CJ Compare and Branch Relative (64)
CLGRJ   EC65 RIEb  CJ Compare Logical and Branch Relative (64)
CGIT    EC70 RIEa   c Compare Immediate and Trap (64<-16)
CLGIT   EC71 RIEa   c Compare Logical Immediate and Trap (64<-16)
CIT     EC72 RIEa   c Compare Immediate and Trap (32<-16)
CLFIT   EC73 RIEa   c Compare Logical Immediate and Trap (32<-16)
CRJ     EC76 RIEb  CJ Compare and Branch Relative (32)
CLRJ    EC77 RIEb  CJ Compare Logical and Branch Relative (32)
CGIJ    EC7C RIEc  CJ Compare Immediate and Branch Relative (64<-8)
CLGIJ   EC7D RIEc  CJ Compare Logical Immediate and Branch Relative (64<-8)
CIJ     EC7E RIEc  CJ Compare Immediate and Branch Relative (32<-8)
CLIJ    EC7F RIEc  CJ Compare Logical Immediate and Branch Relative (32<-8)
AHIK    ECD8 RIEd   A Add Immediate (32<-16)
AGHIK   ECD9 RIEd   A Add Immediate (64<-16)
ALHSIK  ECDA RIEd   A Add Logical with Signed Immediate (32<-16)
ALGHSIK ECDB RIEd   A Add Logical with Signed Immediate (64<-16)
CGRB    ECE4 RRS   CJ Compare and Branch (64)
CLGRB   ECE5 RRS   CJ Compare Logical and Branch (64)
CRB     ECF6 RRS   CJ Compare and Branch (32)
CLRB    ECF7 RRS   CJ Compare Logical and Branch (32)
CGIB    ECFC RIS   CJ Compare Immediate and Branch (64<-8)
CLGIB   ECFD RIS   CJ Compare Logical Immediate and Branch (64<-8)
CIB     ECFE RIS   CJ Compare Immediate and Branch (32<-8)
CLIB    ECFF RIS   CJ Compare Logical Immediate and Branch (32<-8)
LDEB    ED04 RXE    . Load Lengthened (LB<-SB) =4
LXDB    ED05 RXE    . Load Lengthened (EB<-LB) =8
LXEB    ED06 RXE    . Load Lengthened (EB<-SB) =4
MXDB    ED07 RXE    A Multiply (EB<-LB) =8
KEB     ED08 RXE    C Compare and Signal (SB) =4
CEB     ED09 RXE    C Compare (SB) =4
AEB     ED0A RXE    A Add (SB) =4
SEB     ED0B RXE    A Subtract (SB) =4
MDEB    ED0C RXE    A Multiply (LB<-SB) =4
DEB     ED0D RXE    A Divide (SB) =4
MAEB    ED0E RXF    A Multiply and Add (SB) =4
MSEB    ED0F RXE3   A Multiply and Subtract (SB) =4
TCEB    ED10 RXE    c Test Data Class (SB) =4
TCDB    ED11 RXE    c Test Data Class (LB) =8
TCXB    ED12 RXE    c Test Data Class (EB)
SQEB    ED14 RXE    . Square Root (SB) =4
SQDB    ED15 RXE    . Square Root (LB) =8
MEEB    ED17 RXE    A Multiply (SB) =4
KDB     ED18 RXE    C Compare and Signal (LB) =8
CDB     ED19 RXE    C Compare (LB) =8
ADB     ED1A RXE    A Add (LB) =8
SDB     ED1B RXE    A Subtract (LB) =8
MDB     ED1C RXE    A Multiply (LB) =8
DDB     ED1D RXE    A Divide (LB) =8
MADB    ED1E RXE3   A Multiply and Add (LB) =8
MSDB    ED1F RXF    A Multiply and Subtract (LB) =8
LDE     ED24 RXE    . Load Lengthened (LH<-SH) =4
LXD     ED25 RXE    . Load Lengthened (EH<-LH) =8
LXE     ED26 RXE    . Load Lengthened (EH<-SH) =4
MAE     ED2E RXF    A Multiply and Add (SH) =4
MSE     ED2F RXF    A Multiply and Subtract (SH) =4
SQE     ED34 RXE    . Square Root (SH) =4
SQD     ED35 RXE    . Square Root (LH) =8
MEE     ED37 RXE    A Multiply (SH) =4
MAYL    ED38 RXF    A Multiply and Add Unnormalized (EHL<-LH) =8
MYL     ED39 RXF    A Multiply Unnormalized (EHL<-LH) =8
MAY     ED3A RXF    A Multiply and Add Unnormalized (EH<-LH) =8
MY      ED3B RXF    A Multiply Unnormalized (EH<-LH) =8
MAYH    ED3C RXF    A Multiply and Add Unnormalized (EHH<-LH) =8
MYH     ED3D RXF    A Multiply Unnormalized (EHH<-LH) =8
MAD     ED3E RXF    A Multiply and Add (LH) =8
MSD     ED3F RXF    A Multiply and Subtract (LH) =8
SLDT    ED40 RXF    . Shift Significand Left (LD)
SRDT    ED41 RXF    . Shift Significand Right (LD)
SLXT    ED48 RXF    . Shift Significand Left (ED)
SRXT    ED49 RXF    . Shift Significand Right (ED)
TDCET   ED50 RXE    c Test Data Class (SD)
TDGET   ED51 RXE    c Test Data Group (SD)
TDCDT   ED54 RXE    c Test Data Class (LD)
TDGDT   ED55 RXE    c Test Data Group (LD)
TDCXT   ED58 RXE    c Test Data Class (ED)
TDGXT   ED59 RXE    c Test Data Group (ED)
LEY     ED64 RXYa   . Load (Short) =4
LDY     ED65 RXYa   . Load (Long) =8
STEY    ED66 RXYa   . Store (Short) =4
STDY    ED67 RXYa   . Store (Long) =8
CZDT    EDA8 RSLb   A Convert to Zoned (from LD) =l(L2)
CZXT    EDA9 RSLb   A Convert to Zoned (from ED) =l(L2)
CDZT    EDAA RSLb   . Convert from Zoned (to LD) =l(L2)
CXZT    EDAB RSLb   . Convert from Zoned (to ED) =l(L2)
CPDT    EDAC RSLb   A Convert to Packed (from LD) =l(L2)
CPXT    EDAD RSLb   A Convert to Packed (from ED) =l(L2)
CDPT    EDAE RSLb   . Convert from Packed (to LD) =l(L2)
CXPT    EDAF RSLb   . Convert from Packed (to ED) =l(L2)
PLO     EE   SSe1   c Perform Locked Operation
LMD     EF   SSe    . Load Multiple Disjoint (64<-32+32)
SRP     F0   SSc    A Shift and Round Decimal
MVO     F1   SSb    . Move with Offset =l(L1)
PACK    F2   SSb    . Pack =l(L1)
UNPK    F3   SSb    c Unpack =l(L1)
ZAP     F8   SSb    A Zero and Add =l(L1)
CP      F9   SSb    C Compare Decimal =l(L1)
AP      FA   SSb    A Add Decimal =l(L1)
SP      FB   SSb    A Subtract Decimal =l(L1)
MP      FC   SSb    A Multiply Decimal =l(L1)
DP      FD   SSb    A Divide Decimal =l(L1)
END-INSTRUCTION-DEFINITIONS


The following table is used to convert branch instructions to extended
mnemonics. This makes the generated instruction more human friendly by
translating the mask (M1 field) into the extended mnemonic name. For
example:

     BRC   B'1000',somewhere

...will be converted to either:

     JE    somewhere    (if present after a comparison instruction)
or:
     JZ    somewhere    (if present after an arithmetic instruction)
or:
     JO    somewhere    (if present after a Test Under Mask instruction)

.-- C = Preceding instruction was a comparison instruction
|   A = Preceding instruction was an arithmetic instruction
|   M = Preceding instruction was a Test Under Mask instruction
|   . = Preceding instruction is irrelevant
|
|     .-- Mask field (M1) value in this conditional branch instruction
|     |
|     |  ---Extended Mnemonic for----
|     |  .-- Branch on Condition
|     |  |     .-- Branch on Condition Register
|     |  |     |     .-- Branch Indirect on Condition
|     |  |     |     |     .-- Branch Relative on Condition
|     |  |     |     |     |     .-- Branch Relative on Condition Long
|     |  |     |     |     |     |
V     V  V     V     V     V     V
Usage M1 BC    BCR   BIC   BRC   BRCL  Meaning
----- -- ----- ----- ----- ----- ----- ----------------------------
BEGIN-EXTENDED-BRANCH-MNEMONICS
.     F  B     BR    BI    J     JLU   Unconditional branch
.     0  NOP   NOPR  -     JNOP  JLNOP No operation
C     2  BH    BHR   BIH   JH    JLH   Branch if High
C     4  BL    BLR   BIL   JL    JLL   Branch if Low
C     8  BE    BER   BIE   JE    JLE   Branch if Equal
C     D  BNH   BNHR  BINH  JNH   JLNH  Branch if Not High
C     B  BNL   BNLR  BINL  JNL   JLNL  Branch if Not Low
C     7  BNE   BNER  BINE  JNE   JLNE  Branch if Not Equal
A     2  BP    BPR   BIP   JP    JLP   Branch if Plus
A     4  BM    BMR   BIM   JM    JLM   Branch if Minus
A     8  BZ    BZR   BIZ   JZ    JLZ   Branch if Zero
A     1  BO    BOR   BIO   JO    JLO   Branch if Overflow
A     D  BNP   BNPR  BINP  JNP   JLNP  Branch if Not Plus
A     B  BNM   BNMR  BINM  JNM   JLNM  Branch if Not Minus
A     7  BNZ   BNZR  BINZ  JNZ   JLNZ  Branch if Not Zero
A     E  BNO   BNOR  BINO  JNO   JLNO  Branch if Not Overflow
M     1  BO    BOR   BIO   JO    JLO   Branch if Ones
M     4  BM    BMR   BIM   JM    JLM   Branch if Mixed
M     8  BZ    BZR   BIZ   JZ    JLZ   Branch if Zeros
M     E  BNO   BNOR  BINO  JNO   JLNO  Branch if Not Ones
M     B  BNM   BNMR  BINM  JNM   JLNM  Branch if Not Mixed
M     7  BNZ   BNZR  BINZ  JNZ   JLNZ  Branch if Not Zeros
END-EXTENDED-BRANCH-MNEMONICS

.-- C = Preceding instruction was a comparison instruction
|   A = Preceding instruction was an arithmetic instruction
|   M = Preceding instruction was a Test Under Mask instruction
|   . = Preceding instruction is irrelevant
|
|     .-- Mask field (M4) value in this Select instruction
|     |
|     |  ---Extended Mnemonic for----
|     |  .-- Select (32)
|     |  |       .-- Select (64)
|     |  |       |       .-- Select High
|     |  |       |       |
|     |  |       |       |
|     |  |       |       |
V     V  V       V       V
Usage M4 SELR    SELGR   SELFHR        Meaning
----- -- -----   -----   -----         ----------------------------
BEGIN-EXTENDED-SELECT-MNEMONICS
C     2  SELRH   SELGRH  SELFHRH       Select if High
C     4  SELRL   SELGRL  SELFHRL       Select if Low
C     8  SELRE   SELGRE  SELFHRE       Select if Equal
C     D  SELRNH  SELGRNH SELFHRNH      Select if Not High
C     B  SELRNL  SELGRNL SELFHRNL      Select if Not Low
C     7  SELRNE  SELGRNE SELFHRNE      Select if Not Equal
A     2  SELRP   SELGRP  SELFHRP       Select if Plus
A     4  SELRM   SELGRM  SELFHRM       Select if Minus
A     8  SELRZ   SELGRZ  SELFHRZ       Select if Zero
A     1  SELRO   SELGRO  SELFHRO       Select if Overflow
A     D  SELRNP  SELGRNP SELFHRNP      Select if Not Plus
A     B  SELRNM  SELGRNM SELFHRNM      Select if Not Minus
A     7  SELRNZ  SELGRNZ SELFHRNZ      Select if Not Zero
A     E  SELRNO  SELGRNO SELFHRNO      Select if Not Overflow
M     1  SELRO   SELGRO  SELFHRO       Select if Ones
M     4  SELRM   SELGRM  SELFHRM       Select if Mixed
M     8  SELRZ   SELGRZ  SELFHRZ       Select if Zeros
M     E  SELRNO  SELGRNO SELFHRNO      Select if Not Ones
M     B  SELRNM  SELGRNM SELFHRNM      Select if Not Mixed
M     7  SELRNZ  SELGRNZ SELFHRNZ      Select if Not Zeros
END-EXTENDED-SELECT-MNEMONICS


The following table is used to give a hint as to what some SVCs are used for
on z/OS. This helps to understand the function of the disassembled machine code.

BEGIN-SVC-LIST
.-- Supervisor call number in hex
|
V
SVC ZOS
--- --------
00  EXCP/XDAP
01  WAIT/WAITR/PRTOV
02  POST
03  EXIT
04  GETMAIN
05  FREEMAIN
06  LINK
07  XCTL
08  LOAD
09  DELETE
0A  GETMAIN/FREEMAIN
0B  TIME
0C  SYNCH
0D  ABEND
0E  SPIE
0F  ERREXCP
10  PURGE
11  RESTORE
12  BLDL/FIND
13  OPEN
14  CLOSE
15  STOW
16  OPEN
17  CLOSE
18  DEVTYPE
19  TRKBAL
1A  CATALOG/INDEX/LOCATE
1B  OBTAIN
1D  SCRATCH
1E  RENAME
1F  FEOV
20  REALLOC
21  IOHALT
22  MGCR/MGCRE/QEDIT
23  WTO/WTOR
24  WTL
25  SEGLD/SEGWT
27  LABEL
28  EXTRACT
29  IDENTIFY
2A  ATTACH/ATTACHX
2B  CIRB
2C  CHAP
2D  OVLYBRCH
2E  TTIMER/STIMERM(TEST/CANCEL)
2F  STIMER/STIMERM(SET)
30  DEQ
33  SNAP/SNAPX/SDUMP/SDUMPX
34  RESTART
35  RELEX
36  DISABLE
37  EOV
38  ENQ/RESERVE
39  FREEDBUF
3A  RELBUF/REQBUF
3B  OLTEP
3C  STAE/ESTAE
3E  DETACH
3F  CHKPT
40  RDJFCB
42  BTAMTEST
44  SYNADAF/SYNADRLS
45  BSP
46  GSERV
47  ASGNBFR/BUFINQ/RLSEBFR
48  IEAVVCTR
49  SPAR
4A  DAR
4B  DQUEUE
4C  IFBSVC76
4E  LSPACE
4F  STATUS
51  SETPRT/SETDEV
53  SMFWTM/SMFEWTM
54  GRAPHICS
55  IGC0008E
56  ATLAS
57  DOM
5B  VOLSTAT
5C  TCBEXCP
5D  TGET/TPG/TPUT
5E  STCC
5F  SYSEVENT
60  STAX
61  IGC0009G
62  PROTECT
63  DYNALLOC
64  IKJEFF00
65  QTIP
66  AQCTL
67  XLATE
68  TOPCTL
69  IMGLIB
6B  MODESET
6D  IGC0010F
6F  IGC111
70  PGRLSE
71  PGFIX/PGFREE/PGLOAD/PGOUT/PGANY
72  EXCPVR
74  IECTSVC
75  DEBCHK
77  TESTAUTH
78  GETMAIN/FREEMAIN
79  VSAM
7A  Extended LOAD/LINK/XCTL
7B  PURGEDQ
7C  TPIO
7D  EVENTS
82  RACHECK
83  RACINIT
84  RACLIST
85  RACDEF
89  IEAVEDS0
8A  PGSER
8B  CVAF
8F  GENKEY/RETKEY/CIPHER/EMK
92  BPESVC
CA  z/VM CMS Command
CB  z/VM CMS Command
CC  z/VM CMSCALL
END-SVC-LIST
*/
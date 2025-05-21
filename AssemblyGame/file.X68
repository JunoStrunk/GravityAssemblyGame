*-----------------------------------------------------------
* Title      : File Read/Write
* Written by : Juno Strunk
* Date       : 9/18/24
* Description: Read and Write files
*-----------------------------------------------------------

FILE_TASK_FOPEN      EQU     51
FILE_TASK_FCREATE    EQU     52
FILE_TASK_FREAD      EQU     53
FILE_TASK_FWRITE     EQU     54
FILE_TASK_FCLOSE     EQU     56

FILE_READ_REGS       REG    d2/a2

* File Read ---
* Read a file into a buffer
* 
* --- In
* a1 - start address of filename
* a2 - start address of buffer to read to
* d1.l - size of buffer to read
* 
* --- Out
* a1   - start address of buffer read to (a2)
* d1.l - number of bytes read
* d0.b - 0 = success, non-zero = error
* 
* -------------
file_Read
    * Load off d2 to store size
    movem.l  FILE_READ_REGS, -(sp)
    
    * Move d1 into d2 to make room for
    * file handle
    move.l  d1, d2

    * open the file ---
    * Uses a1 for file name
    move.l  #FILE_TASK_FOPEN, d0
    trap    #15
    tst.w   d0
    bne     .done
    * d1 contains file handle
    
    * Read the file ---
    * a1 buffer address, d2.l number of bytes to read
    move.b  #FILE_TASK_FREAD, d0
    move.l  a2, a1  ; move buffer into a1 for trap
    trap    #15
    tst.w   d0
    bne     .done
    
    * close the file
    move.l  #FILE_TASK_FCLOSE, d0
    trap    #15
    tst.w   d0
    beq     .done
    
.done
    move.l  d2, d1  ; move number of bytes read into d1
    movem.l  (sp)+, FILE_READ_REGS   ; Reload d2
    rts

* File Write ---
* Write a buffer to a file
*
* --- In
* a1    - File name
* a2    - File Contents
* d1.l  - File Size
*
* --- Out
* d0.b  - 0 = success, non-zero = error
*
* --------------
file_Write
    * Load off d2 to store size
    * Need to store file handle in d1
    move.l  d2, -(sp)
    move.l  d1, d2

    * open the file ---
    * Uses a1 for file name
    move.b  #FILE_TASK_FCREATE, d0
    trap    #15
    tst.w   d0
    bne     .done
    * d1 contains file handle
        
    * write the words ---
    * Uses a1 for file contents
    * uses d2 for file size (in bytes)
    move.b  #FILE_TASK_FWRITE, d0
    move.l  a2, a1
    trap    #15
    tst.w   d0
    bne     .done
        
    * close the file
    move.l  #FILE_TASK_FCLOSE, d0
    trap    #15
    tst.w   d0
    beq     .done
    
.done
    move.l  (sp)+, d2   ; Reload d2
    rts
    






*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~

*-----------------------------------------------------------
* Title      :  Bitmap Module
* Written by :  Juno Strunk
* Date       :  9/25/24
* Description:  Load, unload, and draw bitmaps
*-----------------------------------------------------------
    
BMP_LOAD_REGS       REG     d2/a2-a3
BMP_DRAW_REGS       REG     d5-d7

BMP_SCREENWIDTH     EQU     640
BMP_SCREENHEIGHT    EQU     480

BMP_MAX_FILESIZE    EQU     $401000
BMP_OFFS_PIXELGET   EQU     10
BMP_OFFS_IMGWH      EQU     18
BMP_OFFS_BPP        EQU     28
BMP_OFFS_SIZE       EQU     34

BMP_BYTESPERPIX_32  EQU     4
BMP_BYTESPERPIX_24  EQU     3

BMP_FILESIGN        EQU     $424D

*---
* Loads a bitmap into memory
* Max size of 4194370 (1024x1024)
*
*--- In
* a1 - address of null-terminated filename
* d1.l - size to load
* 
*--- Out
* a1 - address of loaded BMP file in memory
* d1 - offset to pixels
* d0.b  - Error code
*       - 0 = success
*       - 1 = file size too large
*       - 2 = not enough memory
*       - 3 = file error
*
*---
bmp_Load:
    
    movem.l BMP_LOAD_REGS, -(sp)
    
    * save a1 for now
    move.l  a1, a2
    
    * Check file size ---
    cmp.l   #BMP_MAX_FILESIZE, d1
    bgt     .er_size
    
    move.l  d1, d0
    and.l   #%00000001, d0
    cmp.l   #%00000001, d0
    beq     .er_mem
    
    * --- Mem Alloc In
    * d1.l - Size needed
    
    bsr     mem_Alloc
    tst.b   d0
    bne     .er_mem
    * a0 now has the pointer to buffer in memory
    
    * save pointer to buffer for later
    move.l  a0, a3
    
    bsr     mem_GetSize
    * d1 now has the size again
    
    * --- File Read In
    * a1 - start address of filename
    * a2 - start address of buffer to read to
    * d1.l - size of buffer to read
    
    * move file name back into a1
    * move pointer to memory into a2 for file_Read
    move.l  a2, a1
    move.l  a0, a2
    
    bsr     file_Read
    tst.b   d0
    bne     .er_file
    * --- File Read Out
    * a1   - start address of buffer read to (a2)
    * d1.l - number of bytes read
    
    * --- Mem Shrink In
    * a1 - start address of allocation
    * d1.l - new size
    bsr     mem_Shrink
    tst.b   d0
    bne     .er_mem
    
    * Process Pixels ---
    * Restore a1 to pointer to buffer
    move.l  a3, a1
    * Get image size
    move.l  BMP_OFFS_SIZE(a1), d2
    rol.w   #8, d2
    swap    d2
    rol.w   #8, d2
    
    * Get to pixels
    move.l  BMP_OFFS_PIXELGET(a1), d1
    rol.w   #8, d1
    swap    d1
    rol.w   #8, d1
    add.l   d1, a1
    
    * Get bound with image size
    add.l   a1, d2
    
    * Loop through pixels
    
.pxl_Loop
    
    * Adjust colors
    move.l  (a1), d1
    lsr.l   #8, d1
    move.l  d1, (a1)
    
    add.l   #4, a1

    cmp.l   d2, a1
    blt     .pxl_Loop
    
    *Restore a1 again
    move.l  a3, a1
    
.done
    move.b  #0, d0
    movem.l (sp)+, BMP_LOAD_REGS
    rts
    
.er_Size
    move.b  #1, d0
    movem.l (sp)+, BMP_LOAD_REGS
    rts
    
.er_mem
    move.b  #2, d0
    movem.l (sp)+, BMP_LOAD_REGS
    rts
    
.er_file
    move.b  #3, d0
    movem.l (sp)+, BMP_LOAD_REGS
    rts

*---
* Unloads a bitmap from memory
*
*--- In
* a1 - address of loaded BMP
* 
*--- Out
* d0.b  - Error code 0=success, non-zero=failure
*       - 2 = memory failure
*
*---
bmp_Unload:
    
    * Check to make sure pointer is in correct place
    move.w  (a1), d0
    cmp.w   #BMP_FILESIGN, d0
    bne     .er_mem
    
    bsr     mem_Free
    tst.b   d0
    bne     .er_mem

.done
    move.b  #0, d0
    rts

.er_mem
    move.b  #2, d0
    rts

*---
* Draws bitmap
*
*--- In
* a1 - address of loaded BMP
* d1.l - pixel offset
* d2.l - Point in screen coordinates to start
* d3.l - Rect starting point (x, y)
* d4.l - Rect (Width, Height)
* 
*--- Out
* d0.b  - Error code 0=success, non-zero=failure
*       - 1 = File error
*       - 2 = Bounds error
*
*---    
bmp_DrawTrans:
    movem.l BMP_DRAW_REGS, -(sp)
    
    * Check that we are looking at a bitmap
    move.w  (a1), d5
    cmp.w   #BMP_FILESIGN, d5
    bne     .er_file
    
    * Get pixel offset
    move.l  BMP_OFFS_PIXELGET(a1), d1
    rol.w   #8, d1
    swap    d1
    rol.w   #8, d1
    
    * Get Image width ---
    move.l  BMP_OFFS_IMGWH(a1), d5
    * Get Image height ---
    add.l   #4, a1
    move.l  BMP_OFFS_IMGWH(a1), d6
    sub.l   #4, a1
    
    * Switch endian-ness
    rol.w   #8, d5
    swap    d5
    rol.w   #8, d5
    rol.w   #8, d6
    swap    d6
    rol.w   #8, d6
    
    * Calc bytes to subract ---
    move.l  d5, d7
    swap    d4
    add.w   d4, d7
    swap    d4
    mulu.w  #BMP_BYTESPERPIX_32, d7
    
    * Move a1 to pixels (And free d1) ---
    add.l   d1, a1
    clr.l   d1          * Unneccessary but easier for debug
    
    * Move screen coords into d1 and d2 ---
*    swap    d2
*    move.w  d2, d1
*    clr.w   d2          * Unneccessary but easier for debug
*    swap    d2
    
    * Get image offset coords ---
    * (ImageHeight  - starting y)
    sub.w   d3, d6
    
    * Subtract by 1 if != 0
    cmp.w   #0, d6
    beq     .zeroRow
    sub.w   #1, d6
    
.zeroRow
    * multiply by Image Width
    mulu.w  d5, d6      * d5 no longer needed
    clr.l   d5
    
    * Add starting x
    swap    d3
    move.w  d3, d5
    add.l   d5, d6      
    asl.l   #2, d6  * Multiply by 4, for 32 bit
    add.l   d6, a1
    clr.l   d5
    
    * Calc Bounds ---
    * Move width and height into
    * d4 High word - Rect Height
    * d4 Low word - Rect Width
    swap    d4
    move.w  d4, d5
    
    * Add starting points (if not zero)
    swap    d2
    cmp.w   #0, d2
    beq     .zeroX
    add.w   d2, d4
    
.zeroX
    swap    d2
    cmp.w   #0, d2
    beq     .zeroY
    swap    d4
    add.w   d2, d4
    swap    d4
    
.zeroY
    * Swap because you swap in rowLoop
    swap    d4
    
* ===== 32 Bit Draw Loop =============================
        
    * d0 needed for trap codes
    * Pen color needs to be in d1
    * screen coords need to be in d1 and d2
    * -- d3 will hold d1 when context switching
    * -- d6 will hold the color offset
.rowLoop_32
    * Swap back to get width
    swap    d4
    swap    d2
.colLoop_32

    * Get color ---
    * Rotate for ABGR
    * Get next color
    move.l  (a1), d1
    cmp.l   #0, d1
    beq     .incCol_32
*    lsr.l   #8, d1
    
    * Set Pen Color
    move.l  #80, d0
    trap    #15
    
    * Reset screen coord x
    move.w  d2, d1
    swap    d2
    
    * Draw Pixel ---
    move.l  #82, d0
    trap    #15
    
    swap    d2
    
.incCol_32
    * Move screen coord col (x) ---
    add.w   #1, d2
    add.l  #4, a1
    
    cmp.w   d4, d2
    blt     .colLoop_32
    * Closes colLoop ======================
    
    * Clear screen coord col (x) ---
    sub.w   d5, d2
    
    * Move offset backwards ---
    sub.l   d7, a1
    
    * Move screen coord row (y) ---
    swap    d2
    add.w   #1, d2
    
    * Get High word (Rect Height)
    swap    d4
    
    cmp.w   d4, d2
    blt     .rowLoop_32
    * Closes rowLoop =====================
    
    move.b  #0, d0
    movem.l (sp)+, BMP_DRAW_REGS
    rts

    
.er_file
    move.b  #1, d0
    movem.l (sp)+, BMP_DRAW_REGS
    rts
    
.er_bounds
    move.b  #2, d0
    movem.l (sp)+, BMP_DRAW_REGS
    rts
    
*---
* Draws bitmap
*
*--- In
* a1 - address of loaded BMP
* d2.l - Point in screen coordinates to start
* d3.l - Rect starting point (x, y)
* d4.l - Rect (Width, Height)
* 
*--- Out
* d0.b  - Error code 0=success, non-zero=failure
*       - 1 = File error
*       - 2 = Bounds error
*
*---    
bmp_Draw:
    movem.l BMP_DRAW_REGS, -(sp)
    
    * Check that we are looking at a bitmap
    move.w  (a1), d5
    cmp.w   #BMP_FILESIGN, d5
    bne     .er_file
    
    * Get to pixel offset
    move.l  BMP_OFFS_PIXELGET(a1), d1
    rol.w   #8, d1
    swap    d1
    rol.w   #8, d1
    
    * Get Image width ---
    move.l  BMP_OFFS_IMGWH(a1), d5
    * Get Image height ---
    add.l   #4, a1
    move.l  BMP_OFFS_IMGWH(a1), d6
    sub.l   #4, a1
    
    * Switch endian-ness
    rol.w   #8, d5
    swap    d5
    rol.w   #8, d5
    rol.w   #8, d6
    swap    d6
    rol.w   #8, d6
    
    * Calc bytes to subract ---
    move.l  d5, d7
    swap    d4
    add.w   d4, d7
    swap    d4
    mulu.w  #BMP_BYTESPERPIX_32, d7
    
    * Move a1 to pixels (And free d1) ---
    add.l   d1, a1
    clr.l   d1          * Unneccessary but easier for debug
    
    * Move screen coords into d1 and d2 ---
*    swap    d2
*    move.w  d2, d1
*    clr.w   d2          * Unneccessary but easier for debug
*    swap    d2
    
    * Get image offset coords ---
    * (ImageHeight  - starting y)
    sub.w   d3, d6
    
    * Subtract by 1 if != 0
    cmp.w   #0, d6
    beq     .zeroRow
    sub.w   #1, d6
    
.zeroRow
    * multiply by Image Width
    mulu.w  d5, d6      * d5 no longer needed
    clr.l   d5
    
    * Add starting x
    swap    d3
    move.w  d3, d5
    add.l   d5, d6      
    asl.l   #2, d6  * Multiply by 4, for 32 bit
    add.l   d6, a1
    clr.l   d5
    
    * Calc Bounds ---
    * Move width and height into
    * d4 High word - Rect Height
    * d4 Low word - Rect Width
    swap    d4
    move.w  d4, d5
    
    * Add starting points (if not zero)
    swap    d2
    cmp.w   #0, d2
    beq     .zeroX
    add.w   d2, d4
    
.zeroX
    swap    d2
    cmp.w   #0, d2
    beq     .zeroY
    swap    d4
    add.w   d2, d4
    swap    d4
    
.zeroY
    * Swap because you swap in rowLoop
    swap    d4
    
    * Now multiply by bit depth and switch to correct draw loop
*    move.l  BMP_OFFS_BPP(a1), d0
*    cmp.l   #BMP_BYTESPERPIX_32, d0
*    bne     .twenty_four
    
* ===== 32 Bit Draw Loop =============================
        
    * d0 needed for trap codes
    * Pen color needs to be in d1
    * screen coords need to be in d1 and d2
    * -- d3 will hold d1 when context switching
    * -- d6 will hold the color offset
.rowLoop_32
    * Swap back to get width
    swap    d4
    swap    d2
.colLoop_32

    * Get color ---
    * Rotate for ABGR
    * Get next color
    move.l  (a1), d1
*    lsr.l   #8, d1
    
    * Set Pen Color
    move.l  #80, d0
    trap    #15
    
    * Reset screen coord x
    move.w  d2, d1
    swap    d2
    
    * Draw Pixel ---
    move.l  #82, d0
    trap    #15
    
    swap    d2
    
    add.w   #1, d2
    add.l  #4, a1
    
    cmp.w   d4, d2
    blt     .colLoop_32
    * Closes colLoop ======================
    
    * Clear screen coord col (x) ---
    sub.w   d5, d2
    
    * Move offset backwards ---
    sub.l   d7, a1
    
    * Move screen coord row (y) ---
    swap    d2
    add.w   #1, d2
    
    * Get High word (Rect Height)
    swap    d4
    
    cmp.w   d4, d2
    blt     .rowLoop_32
    * Closes rowLoop =====================
    
    move.b  #0, d0
    movem.l (sp)+, BMP_DRAW_REGS
    rts

    
.er_file
    move.b  #1, d0
    movem.l (sp)+, BMP_DRAW_REGS
    rts
    
.er_bounds
    move.b  #2, d0
    movem.l (sp)+, BMP_DRAW_REGS
    rts


*---
* Takes in a little endian and converts it
* to big endian
*
* --- In
* d1.l  - Little endian value
*
* --- Out
* d1.l - Big endian value
* 
*---    
bmp_Endian:
    
    *---
    * 03 02 01 00
    * 03 02 00 01 Rotate.w #8, d1
    * 00 01 03 02 Swap     d1
    * 00 01 02 03 Rotate.w #8, d1
    *---
    
    rol.w   #8, d1
    swap    d1
    rol.w   #8, d1
    
    rts














*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~

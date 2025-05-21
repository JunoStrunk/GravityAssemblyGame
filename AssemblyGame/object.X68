*-----------------------------------------------------------
* Title      : General object
* Written by : Juno Strunk
* Date       : 10/4/24
* Description:
*-----------------------------------------------------------

* Object header needs to hold coordinates and bitmap information (for now)

OBJ_INIT_REGS               REG d0-d2/a1
OBJ_DRAW_REGS               REG d2-d4
OBJ_COLLIDE_REGS            REG d2-d4


* constants for header struct (internal)
OBJ_OFFS_SCREENCOORDS       EQU 0
OBJ_OFFS_BMPCOORDS          EQU 4
OBJ_OFFS_BMPSIZE            EQU 8
OBJ_OFFS_BMPADD             EQU 12
OBJ_OFFS_CENTER             EQU 16
OBJ_OFFS_CORNER             EQU 20
OBJ_HEADER_SIZE             EQU 24 * !!! update this value based on your header layout

* --- Init Obj
* Input
*   - d0.l  - Rect Coordinates
*   - d1.l  - BMP Size
*   - d2.l  - Screen Coordinates
*   - a1    - BMP Address
*
* Output
*   - a0    - Address to Obj
* ---
OBJ_init:
    
    * Allocate Space
    movem.l  OBJ_INIT_REGS, -(sp)
    
    move.l  #OBJ_HEADER_SIZE, d1
    
    bsr     mem_Alloc
    tst.b   d0
    bne     .error
    
    movem.l  (sp)+, OBJ_INIT_REGS
    
    * Fill in values
    move.l  d2, OBJ_OFFS_SCREENCOORDS(a0)
    move.l  d0, OBJ_OFFS_BMPCOORDS(a0)
    move.l  d1, OBJ_OFFS_BMPSIZE(a0)
    move.l  a1, OBJ_OFFS_BMPADD(a0)
    
    * Find corner and fill in value
    add.w   d1, d2
    swap    d1
    swap    d2
    add.w   d1, d2
    swap    d1
    swap    d2
    move.l  d2, OBJ_OFFS_CORNER(a0)
    
    * Find center and fill in value
    lsr.w   #1, d1
    swap    d1
    lsr.w   #1, d1
    swap    d1
    
    move.l  d1, OBJ_OFFS_CENTER(a0)

.done
    move.b  #0, d0
    rts
    
.error
    movem.l  (sp)+, OBJ_INIT_REGS
    move.b  #1, d0
    rts

* --- Set Coords
* Input
*   - a0    - Obj
*   - d0.l  - New Screen Coords
* ---
OBJ_setCoords:
    move.l  d0, OBJ_OFFS_SCREENCOORDS(a0)
    move.l  OBJ_OFFS_BMPSIZE(a0), d1
    
    add.w   d1, d0
    swap    d1
    swap    d0
    add.w   d1, d0
    swap    d1
    swap    d0
    move.l  d0, OBJ_OFFS_CORNER(a0)
    rts

* --- Get Coords
* Input
*   - a0    - Obj
* 
* Output
*   - d0    - Screen Coords
OBJ_getCoords:
    move.l  OBJ_OFFS_SCREENCOORDS(a0), d0
    rts

* --- Draw Obj
* Input
*   - a0.l  - Obj
*   - d0.l  - Coords
*
* ---
OBJ_draw:
    movem.l OBJ_DRAW_REGS, -(sp)
    
    * --- BMP_DRAW
    * a1 - address of loaded BMP
    * d2.l - Point in screen coordinates to start
    * d3.l - Rect starting point (x, y)
    * d4.l - Rect (Width, Height)
    move.l  OBJ_OFFS_BMPADD(a0), a1
    move.l  OBJ_OFFS_SCREENCOORDS(a0), d2
    move.l  OBJ_OFFS_BMPCOORDS(a0), d3
    move.l  OBJ_OFFS_BMPSIZE(a0), d4
    
    jsr     bmp_DrawTrans

.done
    movem.l (sp)+, OBJ_DRAW_REGS
    move.b  #0, d0
    rts
    
.error
    movem.l (sp)+, OBJ_DRAW_REGS
    move.b  #1, d0
    rts
    
* --- Draw Obj
* Input
*   - d0    - Proposed Coords
*   - a0.l  - This Obj
*   - a1.l  - Other Obj
*
* Output
*   - d0.b  - 0 = true, 1 = false
* ---    
OBJ_Collide:
    movem.l OBJ_COLLIDE_REGS, -(sp)
    
    move.l  OBJ_OFFS_BMPSIZE(a0), d2        ;a0(x+w, y+h)
    add.w   d0, d2
    swap    d0
    swap    d2
    add.w   d0, d2
    swap    d0
    swap    d2

    move.l  OBJ_OFFS_SCREENCOORDS(a1), d1   ;a1(x, y)
    move.l  OBJ_OFFS_CORNER(a1), d3        ;a1(x+w, y+h)
    
    * If a1(y) > a0(y+h) no collide!
    cmp.w   d2, d1
    bgt     .no_Collide
    
    * If a1(y+h) < a0(y) no collide!
    cmp.w   d0, d3
    blt     .no_Collide
    
    swap    d0
    swap    d1
    swap    d2
    swap    d3
    
    * If a1(x) > a0(x+w) no collide!
    cmp.w   d2, d1
    bgt     .no_Collide
    
    * If a1(x+w) < a0(x) no collide!
    cmp.w   d0, d3
    blt     .no_Collide

.collide
    movem.l (sp)+, OBJ_COLLIDE_REGS
    move.b  #0, d0
    rts
    
.no_Collide
    movem.l (sp)+, OBJ_COLLIDE_REGS
    move.b  #1, d0
    rts

*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~

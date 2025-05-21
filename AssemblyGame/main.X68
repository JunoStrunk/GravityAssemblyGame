*-----------------------------------------------------------
* Title      : Main function for Assembly game
* Written by : Juno Strunk
* Date       : 9/2/24
* Description:
*-----------------------------------------------------------
    ORG    $1000
    
* === EQU's, REG's & Includes ===

    INCLUDE     "memory.x68"
    INCLUDE     "file.x68"
    INCLUDE     "bitmap.x68"
    INCLUDE     "object.x68"
    
TASK_PRINT                  EQU     13
SENTINEL                    EQU     $deaddead

DRAWRECT                    REG     d2-d4
DRAWBMP                     REG     d2-d4

HEAP_BYTES                  EQU     $300000

WASD_CODES                  EQU     $41445357

W_CHECKBIT                  EQU     0
A_CHECKBIT                  EQU     24
S_CHECKBIT                  EQU     8
D_CHECKBIT                  EQU     16

WHITECOLOR                  EQU     $00FFFFFF
BLACKCOLOR                  EQU     $00000000

MOVE                        EQU     10

DELAY_FRAME	                EQU 	23
FRAME_DELAY_TIME            EQU     2
DRAWING_MODE_TRAP_CODE	    EQU     92
DOUBLE_BUFFERED_MODE	    EQU 	17
REPAINT_SCREEN_TRAP_CODE	EQU 	94

START:                  ; first instruction of program

    * d2 - Player position
    * a2 - Player object address

    * Set double buffering to true
*    move.b	#DRAWING_MODE_TRAP_CODE,d0
*    move.b	#DOUBLE_BUFFERED_MODE,d1
*    trap	#15

    * Initialize Heap
    lea     StartOfMem, a1
    move.l  #HEAP_BYTES, d1
    bsr     mem_InitHeap
    tst.b   d0
    bne     .error
    
    * Load Background ---
    lea     Background, a1
    move.l  #$12C046, d1
    bsr     bmp_Load
    tst.b   d0
    bne     .error
    
    lea     BackgroundData, a0
    move.l  a1, (a0)
    move.l  d1, 4(a0)
    
    * Draw Background ---
    * d2.l - Point in screen coordinates to start
    * d3.l - Rect starting point (x, y)
    * d4.l - Rect (Width, Height)
    clr.l   d2
    clr.l   d3
    move.l  #$028001E0, d4
    bsr     bmp_Draw
    tst.b   d0
    bne     .error

    * Create Player Object ---
    * Load BMP
    lea     UFO, a1
    move.l  #$2000, d1
    bsr     bmp_Load
    tst.b   d0
    bne     .error
    
    move.l  a1, a3
    
    * Obj Init
    *   - d0.l  - Rect Coordinates
    *   - d1.l  - BMP Size
    *   - d2.l  - Screen Coordinates
    *   - a1    - BMP Address
    clr.l   d0
    move.l  #$002A001E, d1
    move.w  #100, d2
    swap    d2
    move.w  #100, d2
    jsr     OBJ_init
    
    * Save off Player Object
    move.l  a0, a2
    
    jsr     OBJ_draw
    
    * Create Sample Player for Collision test ---
    * Obj Init
    *   - d0.l  - Rect Coordinates
    *   - d1.l  - BMP Size
    *   - d2.l  - Screen Coordinates
    *   - a1    - BMP Address
    clr.l   d0
    move.l  #$002A001E, d1
    move.w  #400, d2
    swap    d2
    move.w  #400, d2
    move.l  a3, a1
    jsr     OBJ_init
    
    * Save off new object
    move.l  a0, (ObjArray)
    
    jsr     OBJ_draw
    
    move.l  #$00640064, d2    
.gameLoop
    
    * Uses d4 for input handling
    bsr     handle_Input
    
    bsr     delayFrame
    jsr     swapBuffers
    
    move.b  GAMERUNNING, d0
    cmp.b   #0, d0
    bne     .gameLoop
    bra     .done
    
.error
    moveq   #TASK_PRINT, d0
    lea     ErrorLabel, a1
    trap    #15

.done

    SIMHALT             ; halt simulator
    
* === Subroutines ===

handle_Input:

    * Get Input ---
    * Get keys pressed
    move.b  #19, d0
    move.l  #WASD_CODES, d1
    trap    #15
    move.l  d1, d4
    * Now d4 has $FF in bytes where keys were pressed
    
    cmp.l   #0, d4
    beq     .done
    
    bsr     DrawBehind
    
    move.l  a2, a0
    
    * Check keys down
    btst.l  #W_CHECKBIT, d4
    beq     .checkS

    * if not equal, w pressed
    sub.w   #MOVE, d2
    
.checkS
    btst.l  #S_CHECKBIT, d4
    beq     .checkA
    
    * if not equal, s pressed
    add.w   #MOVE, d2

.checkA
    swap    d2
    btst.l  #A_CHECKBIT, d4
    beq     .checkD
    
   * if not equal, a pressed
    sub.w   #MOVE, d2
    
.checkD
    btst.l  #D_CHECKBIT, d4
    beq     .collision
    
    * if not equal, d pressed
    add.w   #MOVE, d2    

.collision
    
    * Handle Collisions
    swap    d2
    move.l  d2, d0
    move.l  a2, a0
    move.l  (ObjArray), a1
    jsr     OBJ_Collide
    tst.b   d0
    bne     .draw
    
    jsr     OBJ_getCoords
    move.l  d0, d2
    
.draw
    move.l  d2, d0
    bsr     OBJ_setCoords
    
    bsr     OBJ_draw
    
.done
    move.b  #0, d0
    rts
    
.error
    move.b  #1, d0
    rts

* = Draw Rectangle =
* - In
* --- d1.l - Draw color
* --- d2.w - left x
* --- d3.w - top y
* 
* - Out
* --- d0.b - Success(0)/Failure(nonzero)
draw_Rect:
    movem.l DRAWRECT, -(sp)
    
    * Set pen color
    move.b  #80, d0
    trap    #15
        
    * Calculate bottom right based on width/height of 50px
    move.w  d2, d1
    move.w  d3, d2
    move.w  d1, d3
    add.w   #50, d3
    move.w  d2, d4
    add.w   #50, d4
    
    move.l  #87, d0
    trap    #15
    
    movem.l (sp)+, DRAWRECT
    move.b  #0, d0
    rts

DrawBehind:
    movem.l DRAWBMP, -(sp)
    lea     BackgroundData, a0
    move.l  (a0), a1
    move.l  4(a0), d1
    move.l  d2, d3
    move.l  #$002A001E, d4
    
    * Draw BMP
    bsr     bmp_Draw
    tst.b   d0
    bne     .error

.done
    movem.l (sp)+, DRAWBMP
    move.b  #0, d0
    rts
    
.error
    movem.l (sp)+, DRAWBMP
    move.b  #1, d0
    rts

    
delayFrame:
        move.l  #DELAY_FRAME, d0
        move.l  #FRAME_DELAY_TIME, d1
        TRAP    #15
        rts
        
swapBuffers:
	move.b  #REPAINT_SCREEN_TRAP_CODE,d0
    trap    #15
	rts     

* === Static Memory ===
ErrorLabel      dc.b    'An error was encountered',0
Background      dc.b    'BMPS/Galaxy.bmp',0
BackgroundData  ds.l    2
UFO             dc.b    'BMPS/UFO.bmp',0

ObjArray        ds.l    1   ; Holds addresses to 4 objs

GAMERUNNING     dc.b    1

            * longword aligned memory buffer
                ds.l    0
StartOfMem
                dcb.b   HEAP_BYTES,0
EndOfMem
                dc.l    SENTINEL

    END    START        ; last line of source
    







*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~

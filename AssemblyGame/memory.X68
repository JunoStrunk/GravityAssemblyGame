*-----------------------------------------------------------
* Title      : Memory management module
* Written by : Juno Strunk
* Date       : 9/20/24
* Description: 
*-----------------------------------------------------------

* Reg directive for offloading registers
NONVOL_REGS                 REG d2-d7/a2-a6
MHEADER_REGS                REG d1-d2/a0    ; Registers for make header
D2D3_REGS                   REG d2-d3

* constants for callers of mem_Audit
MEM_AUDIT_OFFS_FREE_CNT     EQU 0
MEM_AUDIT_OFFS_USED_CNT     EQU 4
MEM_AUDIT_OFFS_FREE_MEM     EQU 8
MEM_AUDIT_OFFS_USED_MEM     EQU 12
MEM_AUDIT_OVERHEAD_SIZE     EQU 16
MEM_AUDIT_RETURN_SIZE       EQU 20

* constant for get size
MEM_OFFSET_GETSIZE          EQU -8 * Update with header

* constants for header struct (internal)
MEM_OFFSET_SIZE             EQU 0
MEM_OFFSET_NEXT             EQU 4 * Includes header size
MEM_HEADER_SIZE             EQU 8 * !!! update this value based on your header layout

*---
* Initializes the start of the heap
* 
* a1 - start address of heap
* d1.l - size of heap
*
* out d0.b - 0 = success, non-zero = failure
*---
mem_InitHeap:
    * Offload d2
    move.l  d2, -(sp)

    * Keep track of start address
    move.l  a1, MEM_START_HEAP
    move.l  d1, d0
    add.l   a1, d0
    move.l  d0, MEM_END_HEAP

    * Make header
    move.l  #1, d0
    * d1 already set
    move.l  d1, d2    
    move.l  a1, a0
    bsr     make_Header
    * d0 set to success or failure in make_Header
    
    move.l  (sp)+, d2
    rts

*---
* Accumulates some statistics for memory usage
*
* out d0.b - 0 = success, non-zero = error
* out (sp) - count of free blocks
* out (sp+4) - count of used blocks
* out (sp+8) - total remaining free memory
* out (sp+12) - total allocated memory
mem_Audit:
    * d0 - Size of alloc
    * d1 - Next alloc
    
    * Add 4 (1 lw) to SP, so that we're not writing
    * into our return address
    add.l   #4, sp
    
    * Clear outputs
    move.l   #0, MEM_AUDIT_OFFS_FREE_CNT(sp)
    move.l   #0, MEM_AUDIT_OFFS_USED_CNT(sp)
    move.l   #0, MEM_AUDIT_OFFS_FREE_MEM(sp)    
    move.l   #0, MEM_AUDIT_OFFS_USED_MEM(sp)
    move.l   #0, MEM_AUDIT_OVERHEAD_SIZE(sp)

    * Start at beginning of heap
    move.l  MEM_START_HEAP, a0
    
.search
    cmp.l   MEM_END_HEAP, a0
    bge     .done
    
    add.l   #MEM_HEADER_SIZE, MEM_AUDIT_OVERHEAD_SIZE(sp)
    
    * Get header information
    move.l  MEM_OFFSET_SIZE(a0), d0 ; size of alloc
    move.l  MEM_OFFSET_NEXT(a0), d1 ; next alloc
    
    * Test last bit in size header to see if free
    btst    #$1F, MEM_OFFSET_SIZE(a0)
    bne     .free

.allocd
    * Add values to used
    add.l   #1, MEM_AUDIT_OFFS_USED_CNT(sp)
    add.l   d0, MEM_AUDIT_OFFS_USED_MEM(sp)
    bra     .inc
    
.free
    * Add values to free
    neg.l   d0
    add.l   #1, MEM_AUDIT_OFFS_FREE_CNT(sp)
    add.l   d0, MEM_AUDIT_OFFS_FREE_MEM(sp)

.inc
    * Add size of block to a0
    add.l   d1, a0
    bra     .search
    
.done
    * Reset SP and return
    sub.l   #4, sp
    move.l  #0, d0
    rts
    
.error
    * Reset SP and return
    sub.l   #4, sp
    move.l  #1, d0
    rts
          
*---
* Allocates a chunk of memory from the heap
*
* d1.l - size
*
* out a0 - start address of allocation
* out d0.b - 0 = success, non-zero = failure
*---
mem_Alloc:
    * Offload non-volatile regs
    movem.l D2D3_REGS, -(sp)
    
    * Start at the beginning of the heap
    move.l  MEM_START_HEAP, a0
    
    * Iterate through heap to find free space
    * a0 - Address of allocation
    * d2 - MEM_OFFSET_SIZE(a0)
    * d3 - MEM_OFFSET_NEXT(a0)
.search
    
    * See if address is less than end
    cmp.l   MEM_END_HEAP, a0
    bge     .error  ; no space found in heap
    
    * Get size of block (Just size no header)
    move.l  MEM_OFFSET_SIZE(a0), d2
    * Get size of block (size + header)
    move.l  MEM_OFFSET_NEXT(a0), d3
        
    * Test last bit in size header to see if free
    btst    #$1F, MEM_OFFSET_SIZE(a0)
    bne     .free_found
    
.inc
    * Add size of block to a0
    add.l   d3, a0
    bra     .search
    
.free_found
    
    neg.l   d2
    * Check if free space is big enough
    cmp.l   d1, d2
    blt     .inc        ; if not big enough increment and keep searching
    beq     .no_Split   ; if just big enough, skip the splitting
    
    * Split block ---
    
    * Offload for when we think there isn't a split
    * But there really is (not enough space for header)
    move.l  d3, -(sp)
    
    * Set up values found by getting d1 + HEADERSIZE
    move.l  a0, a1
    add.l   #MEM_HEADER_SIZE, d1
    add.l   d1, a1
    move.l  d1, d2
    sub.l   d1, d3
    sub.l   #MEM_HEADER_SIZE, d1 
    * a1 - Address of next block
    * d2 - MEM_OFFSET_SIZE of NEW ALLOC'D block
    * d3 - MEM_OFFSET_NEXT of next block
    
    movem.l MHEADER_REGS, -(sp)
    
    * Make split block header ---
    * --- make_Header inputs
    * a0 - Start of allocation
    * d0.b - 0 = Alloc'd, non-zero = free
    * d1.l - Size of allocation (Including header)
    * d2.l - Bytes until next header
    * ---
    
    move.l  a1, a0
    move.b  #1, d0  ; d0 = 1 since header will be free
    move.l  d3, d1  ; d1 and d2 have remaining block
    move.l  d3, d2
    bsr     make_Header
    * If unable to make header (not enough space)
    * Then reset d2 to be to the end of the original block
    
    movem.l (sp)+, MHEADER_REGS
    
    * Reload d3
    move.l  (sp)+, d3   

    tst.b   d0
    bne     .no_Split
    
    bra     .fill_Alloc
    
.no_Split
    move.l  d3, d2
.fill_Alloc    

    * Make header
    * a0 already has allocStart
    clr.b   d0                      ; d0 = 0, sets header to used
    add.l   #MEM_HEADER_SIZE, d1    ; make_Header expects allocation + header size
    * d2 should be set above
    bsr     make_Header
    tst.b   d0
    bne     .error
    
    bra     .done
    
.error
    move.b  #1, d0
    
.done
    movem.l (sp)+, D2D3_REGS
    rts
    
*---
* Frees a chunk of memory from the heap
*
* a1 - start address of allocation
*
* out d0.b - 0 = success, non-zero = failure
*---
mem_Free:
    * Get size
    sub.l   #MEM_HEADER_SIZE, a1
    move.l  MEM_OFFSET_SIZE(a1), d1
    
    * Check and make sure block is allocated
    BMI     .error ; double free!
    
    * Otherwise free
    neg.l   d1
    move.l  d1, MEM_OFFSET_SIZE(a1)
    
    move.l  MEM_START_HEAP, a0
    bsr     mem_Coalesce
    
    move.l  #0, d0  ; no error
    bra     .done

.error
    move.l  #1, d0
    
.done
    rts
    
*---
* Reduces a current memory allocation to a smaller number of bytes
*
* a1 - start address of allocation
* d1.l - new size
* 
* out d0.b - 0 = success, non-zero = failure
*---
mem_Shrink: 
    * subtract d1 from old alloc's size to get size of new space
    * Update old header size
    * add d1 to a1 to get start of new free space
    * make header of new space
    
    * Add new size to start of alloc
    * to get new start of freed alloc
    move.l  a1, a0
    add.l   d1, a0
    
    * Subtract header size from a1 to get start of alloc
    sub.l   #MEM_HEADER_SIZE, a1
    
    * Move old size into d0
    move.l  MEM_OFFSET_SIZE(a1), d0
    
    * Make sure d1 is less than current size
    cmp.l   d0, d1
    beq     .done
    bgt     .error
    
    * Make sure block is actually allocated
    btst    #$1F, d0
    bne     .error
    
    * Set new size into header
    move.l  d1, MEM_OFFSET_SIZE(a1)
    
    * Subtract new size from old size
    sub.l  d1, d0
    * d0 = Size of new freed block (Header + Buffer) ---
    
    * Set size/next offset of freed block
    move.l  d0, MEM_OFFSET_SIZE(a0)
    sub.l   #MEM_HEADER_SIZE, MEM_OFFSET_SIZE(a0)
    neg.l   MEM_OFFSET_SIZE(a0)
    move.l  d0, MEM_OFFSET_NEXT(a0)
    
    * Get size of new next of allocd block
    move.l  MEM_OFFSET_NEXT(a1), d1
    sub.l   d0, d1
    
    * Set new next into header
    move.l  d1, MEM_OFFSET_NEXT(a1)
    
    bsr     mem_Coalesce
    
.done
    move.l  #0, d0
    rts
    
.error
    move.b  #1, d0
    rts
    
*---
* Merges free blocks starting at memory address
*
* a0 - Start of allocations to search
*---
mem_Coalesce:
    * Offload non-volatile regs
*    movem.l D2D3_REGS, -(sp)

    * Check for not in range
    cmp.l   MEM_START_HEAP, a0
    blt     .error
    
.search
    
    * See if address is less than end
    cmp.l   MEM_END_HEAP, a0
    bge     .done   ; no space found in heap
    
    * Get size of block (Just size no header)
    move.l  MEM_OFFSET_SIZE(a0), d0
    * Get size of block (size + header)
    move.l  MEM_OFFSET_NEXT(a0), d1
        
    * Test last bit in size header to see if free
    btst    #$1F, MEM_OFFSET_SIZE(a0)
    bne     .free_found
    
.inc
    * Add size of block to a0
    add.l   d1, a0
    bra     .search
    
.free_found
    * Look forward to see if next one is free as well
    move.l  a0, a1
    add.l   d1, a1
    
    * Make sure address is in range
    cmp.l   MEM_END_HEAP, a1
    bge     .done
    
    * Test last bit in size header to see if free
    btst    #$1F, MEM_OFFSET_SIZE(a1)
    beq     .inc    ; if not free keep looking
    
    * Get lower block's size, add to higher block
    move.l  MEM_OFFSET_SIZE(a1), d0
    sub.l   #MEM_HEADER_SIZE, d0
    add.l   d0, MEM_OFFSET_SIZE(a0)
    neg.l   d0
    add.l   d0, MEM_OFFSET_NEXT(a0)
    
    bra     .search ; keep looking after merging

.error
    move.b  #1, d0
    rts
    
.done
    move.b  #0, d0
    rts
    
*---
* Inserts the passed in information at header offsets
* Automatically sets next offset equal to size, may
* need adjusted for dead memory
*
* a0 - Start of allocation
* d0.b - 0 = Alloc'd, non-zero = free
* d1.l - Size of allocation(Including header)
* d2.l - Bytes until next header
*
* Out ---
* a0 - Start of buffer
* d0.b  - 0 = success, non-zero = failure
*---
make_Header:
    
    * Check if there is even enough size
    cmp.l   #MEM_HEADER_SIZE, d1
    ble     .error

    * Make Header ---
    
    * Subtract out header size
    * Make negative because it's all free
    sub.l   #MEM_HEADER_SIZE, d1
    
    * Set offset to next
    move.l  d2, MEM_OFFSET_NEXT(a0)
    
    * If making free header make size negative
    * Otherwise just set the size
    cmp.b   #0, d0
    beq     .setSize
    neg.l   d1
    
.setSize
    move.l  d1, MEM_OFFSET_SIZE(a0)
    add.l   #MEM_HEADER_SIZE, a0
    move.b  #0, d0
    bra     .done

.error
    move.b  #1, d0

.done
    rts
    
*---
* Take address of allocation (starting at buffer)
* and get the size
*
* a0 - Start of alloc'd buffer
* 
* Out---
* d0.b - 0 = success, non-zero = failure
* d1.l - Size of buffer
*---
mem_GetSize:
    move.b  #0, d0
    move.l  MEM_OFFSET_GETSIZE(a0), d1
    
    rts

MEM_START_HEAP          ds.l    1
MEM_END_HEAP            ds.l    1












*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~

.equ SYSCALL_NUM_GETSTRING,   1
.equ SYSCALL_NUM_PUTSTRING,   2
.equ SYSCALL_NUM_RESET_TIMER, 3
.equ SYSCALL_NUM_SET_TIMER,   4

/*
 * syscall_handler
 * %d0: syscall number
 * %dx: syscall argument
 */
syscall_handler:
    movem.l %D1-%D7/%A0-%A6, -(%SP)

	cmpi.l #SYSCALL_NUM_GETSTRING, %D0
	beq CALL_GETSTRING

	cmpi.l #SYSCALL_NUM_PUTSTRING, %D0
	beq CALL_PUTSTRING
    
    cmpi.l #SYSCALL_NUM_RESET_TIMER, %D0
    beq CALL_RESET_TIMER
    

	cmpi.l #SYSCALL_NUM_SET_TIMER, %D0
	beq CALL_SET_TIMER
    
    
END_SYSCALL_HNDR:
    movem.l (%SP)+, %D1-%D7/%A0-%A6
	rte

CALL_GETSTRING:
	jsr GETSTRING
	 bra END_SYSCALL_HNDR

CALL_PUTSTRING:
	jsr PUTSTRING
	bra END_SYSCALL_HNDR
	
CALL_RESET_TIMER:
	jsr RESET_TIMER
	bra END_SYSCALL_HNDR
CALL_SET_TIMER:
	jsr SET_TIMER
	bra END_SYSCALL_HNDR

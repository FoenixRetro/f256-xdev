;
; Merlin32 Cross Dev Stub for the Jr Micro Kernel
;
; To Assemble "merlin32 -v xdev.s"
;

; Most of the time this does nothing, it checks to see if it needs to do
; something for the FoenixMgr, if not, it just runs the next kernel firmware
; program
;

; Current Functions:
;   Launch Program that is loaded into memory, via runpgx, or runpgz 
;   Copy a file to the SDCARD if FoenixMgr has placed one in memory (pcopy)
;

		mx %11

; some Kernel Stuff
		put kernel_api.s

; Kernel uses MMU configurations 0 and 1
; User programs default to # 3
; I'm going to need 2 & 3, so that I can launch the PGX/PGZ with config #3
;
; and 0-BFFF mapped into 1:1
;

; Some Global Direct page stuff

; MMU modules needs 0-1F

	dum $20
temp0 ds 4
temp1 ds 4
temp2 ds 4
temp3 ds 4
	dend

; Event Buffer at $30
event_type = $30
event_buf  = $31
event_ext  = $32

event_file_data_read  = event_type+kernel_event_event_t_file_data_read
event_file_data_wrote = event_type+kernel_event_event_t_file_wrote_wrote 

; arguments
args_buf = $40
args_buflen = $42

old_sp = $A0

mmu_lock_springboard = $60 ; about 17 bytes

crossdev_signature = $80
crossdev_pc        = $88  ; jump to here

; File uses $B0-$BF
; Term uses $C0-$CF
; Kernel uses $F0-FF

; 8k Kernel Program, so it can live anywhere

		org $A000
		dsk xdev.bin
sig		db $f2,$56		; signature
		db 1            ; 1 8k block
		db 5            ; mount at $a000
		da start		; start here
		db 1			; version
		db 0			; reserved
		db 0			; reserved
		db 0			; reserved
		asc 'xdev' 		; This will require some discussion with Gadget
		db 0
		;asc '<file>'	; argument list
		db 0
		asc 'CrossDev - FoenixMgr[runpgx,runpgz,pcopy].'	; description
		db 0

start
		; check for springboard
		ldx #7
]lp
		lda |txt_crossdev,x
		cmp <crossdev_signature,x
		bne :no_crossdev

		dex
		bpl ]lp

		; break the signature, so the next reset will work 
		stz <crossdev_signature

		; we need to unmap ourselves so slot 5 is mapped to slot 5
		jsr mmu_unlock

		lda #5
		sta old_mmu0+5	; when lock is called it will map $A000 to physcial $A000

		; need to place a copy of mmu_lock, where it won't be unmapped
		ldx #mmu_lock_end-mmu_lock
]lp		lda mmu_lock,x
		sta mmu_lock_springboard,x
		dex
		bpl ]lp

		; construct more stub code
		lda #$20   ; jsr mmu_lock_springboard
		sta temp0
		lda #<mmu_lock_springboard
		sta temp0+1
		lda #>mmu_lock_springboard
		sta temp0+2 

		lda #$6C ; jmp (|abs)
		sta temp0+3

		lda #<crossdev_pc
		sta <temp0+4
		lda #>crossdev_pc
		sta <temp0+5

		jmp temp0

:no_crossdev

		; check for pcopy, file copy request
		ldx #7
]lp
		lda |txt_copyfile,x
		cmp <crossdev_signature,x
		bne :no_pcopy

		dex
		bpl ]lp

		; break the signature, so the next reset will work 
		stz <crossdev_signature

		jsr pcopy

:no_pcopy
		; just boot the machine, into the next program

		lda #$42	; assuming we are block $41, maybe there's a way to sniff this?
		sta kernel_args_run_block_id
		jmp kernel_RunBlock

;------------------------------------------------------------------------------
txt_crossdev asc 'CROSSDEV'
txt_copyfile asc 'COPYFILE'

;------------------------------------------------------------------------------
; Strings and other includes

		put mmu.s
		put term.s
		put file.s
		put crc32.s
		put pcopy.s

; pad to the end
		ds $C000-*,$EA
; really pad to end, because merlin is buggy
		ds \

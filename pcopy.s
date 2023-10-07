;
; Merlin32 pcopy program, for Jr
;
		mx %11

; pretty much all the contiguous memory
; about 447K 
MAX_LENGTH = $6FC00

;------------------------------------------------------------------------------
; Some Global Direct page stuff

; MMU modules needs 0-1F

; Event Buffer at $30

;args = $300

xfer_data = $10000

; first thing is a c string with the name of the file
; second thing is the length of the file (3) bytes
; third thing is the zip crc32
; followed by file data

; File uses $B0-$BF
; Term uses $C0-$CF
; Kernel uses $F0-FF
; crc32 uses  $F2-FF

		dum $2000
filename ds 256
crc32    ds 4
len24    ds 3
		dend

;

pcopy
		jsr TermInit					; Clear Terminal, etc
		jsr mmu_unlock					; Set us up, so we can read/write system memory

		; Looking for data message
		lda #<txt_look_for_data
		ldx #>txt_look_for_data
		jsr TermPUTS

		ldy #^xfer_data
		lda #<xfer_data
		ldx #>xfer_data
		jsr TermPrintAXYH
		jsr TermCR

		lda #<xfer_data
		ldx #>xfer_data
		ldy #^xfer_data
		jsr set_read_address

		; Print out the filename
		; copy the filename into our mapped space
		ldx #0
]name	jsr readbyte
		sta filename,x
		inx
		cmp #0
		bne ]name

		lda #<txt_filename
		ldx #>txt_filename
		jsr TermPUTS

		lda #<filename
		ldx #>filename
		jsr TermPUTS
		jsr TermCR

;-----------------------------------------------

		; Print out the CRC 32
		lda #<txt_crc32
		ldx #>txt_crc32
		jsr TermPUTS

		ldx #0
]crc32  jsr readbyte
		sta crc32,x
		inx
		cpx #4
		bcc ]crc32

		lda crc32+3
		jsr TermPrintAH
		lda crc32+2
		jsr TermPrintAH
		lda crc32+1
		jsr TermPrintAH
		lda crc32+0
		jsr TermPrintAH
		jsr TermCR

;--------------------------------------------------

		; Print out the length
		lda #<txt_length
		ldx #>txt_length
		jsr TermPUTS

		ldx #0
]len	jsr readbyte
		sta len24,x
		inx
		cpx #3
		bcc ]len

		lda len24
		ldx len24+1
		ldy len24+2
		jsr TermPrintAXYH
		jsr TermCR

		lda len24+2
		cmp #^MAX_LENGTH
		bcc :length_good
		bne :length_bad
		lda len24+1
		cmp #>MAX_LENGTH
		bcc :length_good
		bne :length_bad
		lda len24
		cmp #<MAX_LENGTH
		bcc :length_good
		beq :length_good
:length_bad

		jsr TermCR
		lda #<txt_bad_len
		ldx #>txt_bad_len
		jsr TermPUTS
]bad_len bra ]bad_len

:length_good

;--------------------------------------------------

:start   = temp1
:length  = temp2


		; save data start for the write later, if we decide to write
		jsr get_read_address
		sta :start
		stx :start+1
		sty :start+2

; stuff the length in a temp, and setup length for crc
		lda len24
		sta :length			; used for the read in
;		sta crc_num
		lda len24+1
		sta :length+1
;		sta crc_num+1
		lda len24+2 		; used for CRC status
		sta :length+2
;		sta crc_num+2

; display crc
		lda #<txt_calc32
		ldx #>txt_calc32+1
		jsr TermPUTS

; Do a CRC, but do it in hunks so program doesn't seem broken
		jsr fancy_crc

; Display the result CRC
		lda crc+2
		ldx crc+3
		jsr TermPrintAXH
		lda crc
		ldx crc+1
		jsr TermPrintAXH
		jsr TermCR

; match
		lda #<txt_match
		ldx #>txt_match
		jsr TermPUTS

		do 1
		lda crc32
		cmp crc
		bne :no
		lda crc32+1
		cmp crc+1
		bne :no
		lda crc32+2
		cmp crc+2
		bne :no
		lda crc32+3
		cmp crc+3
		bne :no
		fin

		lda #<txt_yes
		ldx #>txt_yes
		jsr TermPUTS
		jsr TermCR
		bra :save_that_file
:no
		lda #<txt_no
		ldx #>txt_no
		jsr TermPUTS

; crc did not match
		jsr mmu_lock
]fuckno bra ]fuckno

:save_that_file

		lda #<txt_create
		ldx #>txt_create
		jsr TermPUTS

		lda #<filename
		ldx #>filename
		jsr TermPUTS
		jsr TermCR

; Create the file

		lda #<event_type
		sta kernel_args_events
		lda #>event_type
		sta kernel_args_events+1

		lda #<filename
		ldx #>filename
		jsr fcreate
		bcc :good

		pha
		lda #<txt_fail
		ldx #>txt_fail
		jsr TermPUTS

		pla
		jsr TermPrintAH
		jsr TermCR
		jsr mmu_lock
]failed bra ]failed

:good
		lda #<txt_write
		ldx #>txt_write
		jsr TermPUTS

		lda :length
		ldx :length+1
		ldy :length+2
		jsr TermPrintAXYH
		jsr TermCR

		lda :start
		ldx :start+1
		ldy :start+2
		jsr set_read_address
; Where we reading from in memory
		lda :start+2
		jsr TermPrintAH
		lda :start+1
		jsr TermPrintAH
		lda :start+0
		jsr TermPrintAH
		jsr TermCR

		lda :length
		ldx :length+1
		ldy :length+2
		jsr fwrite

		jsr fclose

		jsr TermCR
		jsr TermCR

		lda #<txt_Complete
		ldx #>txt_Complete
		jsr TermPUTS

		jsr mmu_lock

]done   bra ]done
;$$TODO - return here

;-----------------------------------------------
;
; Do the CRC
;
fancy_crc

:crc_count = temp3
CRC_BLOCK_SIZE = 64

		; initialize the count down
		lda :length
		sta :crc_count
		lda :length+1
		sta :crc_count+1
		lda :length+2
		sta :crc_count+2
		stz :crc_count+3

		ldx term_x
		ldy term_y
		phx
		phy

; salt crc
		stz crc
		stz crc+1
		stz crc+2
		stz crc+3

; crc_num = blocksize
		lda #<CRC_BLOCK_SIZE
		sta crc_num+0
		lda #>CRC_BLOCK_SIZE
		sta crc_num+1
		lda #^CRC_BLOCK_SIZE
		sta crc_num+2

]loop
		; Display length completed
		lda :crc_count+2
		ldx :crc_count+3
		jsr TermPrintAXH
		lda :crc_count
		ldx :crc_count+1
		jsr TermPrintAXH
		ply
		plx
		phx
		phy
		; Reset Cursor
		jsr TermSetXY

		; if :crc_count < BLOCK_SIZE
		;    crc_num = :crc_count

		lda :crc_count+2
		cmp crc_num+2
		bcc :less
		bne :go

		lda :crc_count+1
		cmp crc_num+1
		bcc :less
		bne :go

		lda :crc_count+0
		cmp crc_num+0
		bcc :less
		bne :go
:less
		; last bit, let's go!
		lda :crc_count+0
		sta crc_num+0

		lda :crc_count+1
		sta crc_num+1

		lda :crc_count+2
		sta crc_num+2

:go
; calc crc
		jsr calc_crc32

		sec
		lda :crc_count+0
		sbc crc_num+0
		sta :crc_count+0
		lda :crc_count+1
		sbc crc_num+1
		sta :crc_count+1
		lda :crc_count+2
		sbc crc_num+2
		sta :crc_count+2

		ora :crc_count+1
		ora :crc_count+0

		bne ]loop

		ply
		plx

		rts

txt_look_for_data asc 'Looking for data at $'
		db 0
txt_filename      asc '          filename: '
		db 0
txt_length        asc '            length: $'
		db 0
txt_crc32         asc '             CRC32: $'
		db 0
txt_calc32		  asc '  Calculated CRC32: $'
		db 0
txt_match		  asc '         CRC Match: '
		db 0
txt_create        asc '            Create: '
		db 0
txt_write		  asc '             Write: $'
		db 0
txt_fail          asc '            Failed: $'
		db 0
txt_bad_len       asc ' Invalid Length'
		db

txt_Complete      asc ' Copy Completed'
		db 0
txt_yes asc 'yes'
		db 13,0
txt_no  asc 'no, data corrupt'
		db 13,0

txt_done db 13
		asc 'pcopy is done.'
		db 13,0
		


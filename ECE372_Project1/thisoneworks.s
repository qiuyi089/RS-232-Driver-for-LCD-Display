.text
.global _start
.global INT_DIRECTOR

_start:
@@@@@@@@SET UP THE STACK@@@@@@@@@@@@@@@@@@@@@@@@@@@
	LDR R13,=STACK1  @Point to base of STACK for svc mod
	ADD R13,R13,#0x1000 @Point to top of STACK
	CPS #0x12    @Switch to IRQ mode
	LDR R13,=STACK2  @Point to IRQ mode
	ADD R13,R13,#0x1000  @Point to top of STACK
	CPS #0x13  @Back to SVC mode
@@@@@@@ Turn on UART2 CLK @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	LDR R0,=0x02 @Enable clock for GPIO
	LDR R1, =0x44E00070 @CM_PER_UART2_CLKCTRL
	STR R0, [R1] @wake up the clock
@@@@@@@@ Turn on GPIO1 CLK @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	LDR R1,=0x44E000AC @Address of GPIO1_CLKCTRL register
	STR R0,[R1] @Enable GPIO1
	@Detect falling edge on GPIO1_31 which is pin 20
	ldr R0,=0x4804C000 @base address of GPIO1 register
	ADD R1,R0,#0x14C @R1 = address of GPIO1_FALLINGDETECT register
	MOV R2,#0x80000000 @Load value for bit 31
	LDR R3,[R1] @Read GPIO1_FALLINGDETECT register
	ORR R3,R3,R2 @Modify (set bit 21)
	STR R3,[R1] @Write back
	ADD R1,R0,#0x34 @Address of GPIO1_IRQSTATUS_SET_0 register
	STR R2, [R1] @Enable GPIO1_21 request on POINTRPEND1
@@@@@@@@@@@@@@ TIMER5 @@@@@@@@@@@@@@@@@@@@@@@@@@
	@turn on Timer5 CLK
	mov R2,#0x2 @value to enable Timer5 CLK
	ldr R1,=0x44E000EC  @address of CM_PER_TIMER2_CLKCTRL
	str R2,[R1] @turn on
	ldr R1,=0x44E00518  @address of PRCMCLKSEL_TIMER5 register
	str R2,[R1] @select 32Khz CLK for Timer5
	@initialize timer5 registers, with count, overflow interrupt generation
	ldr R1,=0x48046000  @Base address for Timer5 register
	mov R2,#0x1 @value to reset Timer5
	str R2,[R1,#0x10] @write to Timer5 CFG register
	mov R2,#0x2 @value to enable overflow interrupt
	str R2,[R1,#0x2C] @write to Timer5 IRQENABLE_SET
	ldr R2,=0xFFFF8000 @count value for 1 seconds
	str R2,[R1,#0x40] @Timer5 TLDR load register
	str R2,[R1,#0x3C] @write to Timer5 TCRR count register


@@@@@@@@@@@Switch to mode 1@@@@@@@@@@@@@@@@@
	LDR R1, =0x44E10954 @address of the  control module register + Spi0_d0 = 0x954
	LDR R2,=0x09 @value to switch it to mode 1
	STR R2, [R1] @switch the pin to mode 1
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	@initialize UART2
	LDR R1, =0x48024000 @address of UART2
	LDR R2, =0x4802400C @address of UART2_LCR
	MOV R3,#0x83 @the value to switch UART2 to mode A
	STR R3,[R2] @switch to mode A by writing 0x83 to the LCR
	LDR R2, =0x48024004 @address of UART2 DLH
	MOV R3,#0x01
	STR R3, [R2] @write 0x01 to DLH for a 9600 baud rate
	LDR R2, =0x48024000 @address of UART2 DLL
	MOV R3, #0x38
	STR R3, [R2] @write 0x38 to DLL for a 9600 baud rate
	ADD R2, R1, #0x20 @address of MDR1 register for UART2
	MOV R3, #0x00
	STR R3, [R2] @store 0x00 to MDR1 register to reset the bits.
	LDR R2, =0x4802400C @address of UART2_LCR
	MOV R3, #0x03
	STR R3,[R2] @store 0x00 to LCR to switch the UART2 back to operation mode and keep the 8-bit data word length
	LDR R2, =0x48024008 @address of the FIFO Control Register
	MOV R3, #0x06
	STR R3,[R2] @disable RX FIFO and TX FIFO

	@initialize INTC
	ldr R1,=0x48200000 @base address for INTC
	mov R2,#0x2 @value to reset INTC
	str R2,[R1,#0x10] @write to INTC Config register
	mov R2,#0x20000000    @unmask INTC INT 93, Timer5 interrupt
	str R2,[R1,#0xC8] @write to INTC_MIR_CLEAR2
	mov R2,#0x04 @value to unmask INTC INT 98, GPIOINTA
	str R2,[R1,#0xE8] @write to INTC_MIR_CLEAR3 register

	@initialize INTC for UART2
	LDR R1,=0x482000C8 @Address of INTC_MIR_CLEAR2 register
	MOV R2,#0x400 @value to unmask INTC INT 74 UART2
	STR R2,[R1] @Write to INTC_MIR_CLEAR2 register

	@Make sure processor IRQ enabled in CPSR
	MRS R3,CPSR @Copy CPSR to R3
	BIC R3,#0x80 @clear bit 7
	MSR CPSR_c,R3 @Write back to CPSR
	@Wait for interrupt
Loop: NOP
	B Loop

INT_DIRECTOR:
	STMFD SP!,{R0-R9,LR} @Push registers on stack
@@@@@@@@@@@@@ Check if it was UART2 @@@@@@@@@@@@@@@@@@@@@@@@@@@
	LDR R0,=0x482000D8 @value of the INTC_PENDING_IRQ2
	LDR R1, [R0] @load the value of the INTC_PENDING_IRQ2 register
	CMP R1,#0x00000400 @check the third bit to see if it from UART2
	BEQ SEND @go to send if it is else go check the button
@@@@@@@@@@@@ Check if it was timer @@@@@@@@@@@@@@@@@@@@@@@@@@@
	LDR R0,=0x482000F8 @Address of INTC-PENDING_IRQ3 register
	LDR R1,[R0] @read INTC-PENDING_IRQ3 register
	TST R1,#0x00000004 @test bit 2
	BEQ TCHK  @Not from GPIOINT1A, check for timer5, else
@@@@@@@@@@@@@ Check if it was the button @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	LDR R0,=0x4804C02C @load GPIO1_IRQSTATUS_0 register address
	LDR R1,[R0] @read STATUS register
	TST R1,#0x80000000 @Check if bit 31 = 1
	BNE BUTTON_SVC @if bit 31 = 1, then button pushed
	BEQ PASS_ON @if bit 31 = 0, then go back to wait loop
TCHK:
	ldr R1,=0x482000D8 @address of INTC_PENDING_IRQ2 register
	ldr R0,[R1] @read value
	TST R0,#0x20000000 @check if interrupt from Timer5
	BEQ PASS_ON @if no then go back to wait loop, if yes then check for overflow
	ldr R1,=0x48046028 @address of Timer5 IRQSTATUS register
	ldr R0,[R1] @read the value
	TST R0,#0x2 @check bit 1
	BNE SEND2 @if overflow then go SEND
	B PASS_ON @else go back to wait loop

PASS_ON:
	LDMFD SP!,{R0-R9,LR} @restore register
	SUBS PC,LR,#4 @pass execution on to wait Loop for now
BUTTON_SVC:
	MOV R1,#0x80000000 @Value turns off GPIO1_31 interrupt request and also turn off INTC interrupt request
	STR R1,[R0] @write to GPIO1_IRQSTATUS_0 register
	@@@@@@@@@@@@ Enable the IER UART  for interrupt
	LDR R2, =0x48024004 @address of IER_UART2 interrupt Enable register
	MOV R3, #0x00000002 @Bit THRIT
	STR R3, [R2] @Enable the interrupt by write 1 to bit 1 of THRIT
	@@@@@@@@@@@@ start the timer5
	ldr R1,=0x48046000 @address of Timer5 TCLR register
	ldr R2,=0xFFFF8000 @value load for 2 seconds
	str R2,[R1,#0x40] @Timer5 TLDR load register
	str R2,[R1,#0x3C] @write to Timer5 TCRR count register

	mov R2,#0x01  @value to make timer wait for 2 seconds
	ldr R1,=0x48046038 @address of Timer5 TCLR register
	str R2,[R1] @write to TCLR register
	B SEND @go back to loops

SEND2:
	LDR R0, =CHAR_PTR2 @send character, R0 = address of pointer store
	LDR R1, [R0] @R1 = address of desire character in text string
	LDR R2, =CHAR_COUNT2 @R2 = address of count store location
	LDR R3, [R2] @get current character count value
	LDRB R4, [R1], #1 @read char to send from string, inc ptr in R1 by 1
	STR R1, [R0] @put incremented address back in CHAR_PTR location
	LDR R5, =0x48024000 @point at UART transmit buffer
	STRB R4, [R5] @write CHARACTER to transmit buffer.THrit send a signal
	SUBS R3, R3, #1 @decrement character counter by 1
	STR R3, [R2] @store character value counter back in memory
	CMP R3,#0
	BNE PASS_ON @geater than or equal zero, more characters
	BEQ LAST_SEND

SEND:
	LDR R0, =CHAR_PTR @send character, R0 = address of pointer store
	LDR R1, [R0] @R1 = address of desire character in text string
	LDR R2, =CHAR_COUNT @R2 = address of count store location
	LDR R3, [R2] @get current character count value
	LDRB R4, [R1], #1 @read char to send from string, inc ptr in R1 by 1
	STR R1, [R0] @put incremented address back in CHAR_PTR location
	LDR R5, =0x48024000 @point at UART transmit buffer
	STRB R4, [R5] @write CHARACTER to transmit buffer.THrit send a signal
	SUBS R3, R3, #1 @decrement character counter by 1
	STR R3, [R2] @store character value counter back in memory
	CMP R3,#0
	BNE PASS_ON @geater than or equal zero, more characters
	BEQ LAST_SEND

LAST_SEND:
	@turn off timer 5 interrupt request and enable INTC for next IRQ
	ldr R1,=0x48046028  @load address of Timer5 IRQSTATUS register
	mov R2,#0x2 @value to reset Timer5 Overflow IRQ request
	str R2,[R1] @write
	@Turn off NEWIRQA bit in INTC_CONTROL, so processor can respondto new IRQ
	LDR R0,=0x48200048 @address of INTC_CONTROL register
	MOV R1,#01 @value to clear bit 0
	STR R1,[R0] @write to INTC_CONTROL register
	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	LDR R0, =CHAR_PTR @send character, R0 = address of pointer store
	LDR R1, [R0] @R1 = address of desire character in text string
	LDR R2, =CHAR_COUNT @R2 = address of count store location
	LDR R3, [R2] @get current character count value
	LDRB R4, [R1], #1 @read char to send from string, inc ptr in R1 by 1
	STR R1, [R0] @put incremented address back in CHAR_PTR location
	LDR R5, =0x48024000 @point at UART transmit buffer
	STRB R4, [R5] @write CHARACTER to transmit buffer.THrit send a signal
	SUBS R3, R3, #1 @decrement character counter by 1
	STR R3, [R2] @store character value counter back in memory
	LDR R3, =MESSAGE @done, reload. get address of start of string
	STR R3, [R0] @write in char pointer store location in memory
	MOV R3, #8 @load original number of char in string again
	STR R3, [R2] @write back to memory for next message send
@@@@@@@@@@@@@@@ Shut off the UART INTERRUPTS @@@@@@@@@@@@@@@@@@@@@@@@
	LDR R0,=0x48024004 @load address of IER_UART2
	LDR R1,=0x00 @disable the THRIT bit
	STR R1,[R0]
	B PASS_ON


.data
.align 2
@ SYS_IRQ: .WORD 0 @location to store system IRQ address
MESSAGE:
.byte 0x7C
.byte 0x2D
.ascii "Martin"
CHAR_PTR: .word MESSAGE
CHAR_COUNT: .word 8
MESSAGE2:
.byte 0x7C
.byte 0x2D
.ascii " "
CHAR_PTR2: .word MESSAGE2
CHAR_COUNT2: .word 3

.align 2
STACK1: .rept 1024
		.word 0x0000
		.endr
STACK2: .rept 1024
		.word 0x0000
		.endr
.END

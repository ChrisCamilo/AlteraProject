#	PROJETO REMOTO - MICROPROCESSADORES II
#	PROFESSORA ADRIANE SERAPIAO	
#	ALUNO: CHRISTIAN CAMILO	

# 320x240, 1024 bytes/row, 2 bytes per pixel: DE1-SoC, DE2, DE2-115 -> especificacao do VGA da placa
.equ 	WIDTH, 320
.equ 	HEIGHT, 240
.equ 	LOG2_BYTES_PER_ROW, 10
.equ 	LOG2_BYTES_PER_PIXEL, 1
.equ	STACK, 0x10000
.equ    RED_LED_BASE, 0x10000000
.equ 	HEX3_HEX0_BASE, 0x10000020
.equ	SWITCH_BASE, 0x10000040
.equ	PUSHBUTTONS_BASE, 0x10000050
.equ	JTAG_UART_BASE, 0x10001000
.equ    INTERVAL_TIMER_BASE, 0x10002000
.equ 	PIXEL_BUFFER, 0x08000000

.org 0x20
	subi 	sp, sp, 12	/* Exception Handler */
 	stw 	ra, 8(sp)
  	stw 	fp, 4(sp)
  	stw 	r15, 0(sp)
  	addi 	fp, sp, 4

	rdctl 	et, ipending	
	beq		et, r0, OTHER_EXCEPTIONS
	subi 	ea, ea, 4

	andi 	r15, et, 1	# checa o irq0
	beq  	r15, r0, OTHERS_INTERRUPTS
	call 	EXT_IRQ0 

OTHERS_INTERRUPTS:
	andi	r15, et, 2
	beq		r15, r0, OTHER_EXCEPTIONS
	call	EXT_IRQ1
	br		END_HANDLER
OTHER_EXCEPTIONS:

END_HANDLER:
	ldw 	ra, 8(sp)
	ldw 	fp, 4(sp)
	ldw 	r15, 0(sp)
	addi 	sp, sp, 12
	
	eret	/*End Exception */

.macro 	SWITCH_CASE CODE			# analogia a um switch case (porém, pode ser mais entendido como vários if's),
	ldw		r17, 0(r15)				# onde ele irá analisar o valor de OP_CODES e, caso seja o valor, ele vai para a label correspondente
	beq		r16, r17, \CODE			# que foi passada para a macro 
	addi	r15, r15, 4
.endm

.macro	SET_STATUS STATUS_BASE x  	# macro que serve para atualizar o Status dado a label e o valor a ser inserido
	movia	r15, \STATUS_BASE
	addi	r16, r0, \x
	stw		r16, 0(r15)
.endm

.macro 	CONVERT_TO_CODE			# subtrai o valor ASCII do input guardado na memoria
	ldw		r16, 0(r17)			# para se comparar com os valores de OP_CODES
	subi	r16, r16, 0x30
	muli	r16, r16, 10
	addi	r17, r17, 4
	ldw		r17, 0(r17)
	subi	r17, r17, 0x30
	add		r16, r16, r17
.endm

.macro	WRITE_ON_HEX x
	add		r20, r14, \x		# indexa o valor passado na tabela SEVEN_SEG_DECODE_TABLE
	add		r21, r0, r0
	ldb		r21, 0(r20)			# r21 recebe o código da tabela 
	stb		r21, 0(r15)			# escreve no display
	addi	r15, r15, 1			# anda para o proximo LED do display
.endm

.macro	DIVIDE_TIME x			# macro para achar o valor 
	addi	r17, r0, \x
	div		r18, r16, r17		# r18 = quociente => no último LED será usado esse valor, mas ele, por ora, é usado para continuar achando os restos das divisões
	mul 	r19, r18, r17
	sub 	r19, r16, r19		# r19 = resto da divisão => valor que será escrito no LED
.endm

.org 0x100

EXT_IRQ0:
	subi	sp, sp, 20	
	stw		ra, 0(sp)
	stw		fp, 4(sp)
	stw		r4, 8(sp)
	stw 	r5, 12(sp)
	stw		r6, 16(sp)
    addi	fp, sp, 20
	
	call	STOP_TIMER
	
	RED_LED:
		movia	r4, RED_LED_STATUS
		ldw		r4, 0(r4)
		beq		r4, r0, CRONOMETER
		call	RED_LED_ANIMATION
	CRONOMETER:
		addi	r6, r0, 2
		movia	r4, CRONOMETER_STATUS
		ldw		r4, 0(r4)
		beq		r4, r0, RE_TIMER
		beq		r4, r6, RE_TIMER
		
		movia	r4, CRONOMETER_COUNTER
		ldw		r5, 0(r4)
		addi	r5, r5, 1
		cmpeqi	r6, r5, 5
		beq		r6, r0, UPDATE_COUNTER
	
		stw		r0, 0(r4)
		call	UPDATE_CRONOMETER
		br		RE_TIMER
		
	UPDATE_COUNTER:
		stw		r5, 0(r4)
	RE_TIMER:
		movia	r4, 0x9680
		movi	r5, 0x98
		call	SET_TIMER
		
	END_IRQ0:
		ldw		ra, 0(sp)
        ldw		fp, 4(sp)
		ldw		r4, 8(sp)
        ldw		r5, 12(sp)
		ldw		r6, 16(sp)
        addi	sp, sp, 20
	ret

EXT_IRQ1:					# analisa a interrupção do pushbutton
	subi	sp, sp, 16		
	stw		ra, 0(sp)
	stw		fp, 4(sp)
	stw		r15, 8(sp)
	stw 	r16, 12(sp)
    addi	fp, sp, 16
	
	movia	r15, CRONOMETER_STATUS
	ldw		r15, 0(r15)
	addi	r16, r0, 1
	
	beq		r15, r16, PAUSE				# se o cronometro estiver ativo, ele irá pausar
	bne		r15, r0, RESUME				# se o cronometro estiver inativo, ele irá resumir a contagem
	br		RESET_BUTTON
	
	PAUSE:	
	SET_STATUS 	CRONOMETER_STATUS, 2	
	call	STOP_TIMER
	br		RESET_BUTTON
	
	RESUME:
	SET_STATUS 	CRONOMETER_STATUS, 1
	call	START_TIMER

	RESET_BUTTON:
		movia	r15, PUSHBUTTONS_BASE
		addi	r16, r0, 0x2
		stwio	r16, 12(r15)
		
	END_IRQ1:
		ldw		ra, 0(sp)
		ldw		fp, 4(sp)
		ldw		r15, 8(sp)
		ldw		r16, 12(sp)
		addi	sp, sp, 16
	ret

.global _start
_start:
	movia	sp, STACK
	mov 	fp, sp
	
	CLEAN_ALL:  # usado inicialização do que é usado a fim de evitar bugs
		movia	r18, RED_LED_STATUS
		stw		r0, 0(r18)
		movia	r18, CRONOMETER_STATUS
		stw		r0, 0(r18)
		movia	r18, CRONOMETER_COUNTER
		stw		r0, 0(r18)
		movia	r18, CRONOMETER_VALUE
		stw		r0, 0(r18)
		movia	r18, RED_LED_BASE
		stwio	r0, 0(r18)
		movia	r18, HEX3_HEX0_BASE
		stwio	r0, 0(r18)
		movia	r18, INTERVAL_TIMER_BASE
		movi	r19, 0b01000	# STOP = 1, START = 0, CONT = 0, ITO = 0 
		sthio	r19, 4(r18)
		stwio	r0, 8(r18)
		stwio	r0, 12(r18)
		call	BLANK

	movia	r18, PUSHBUTTONS_BASE
	addi 	r3, r0, 2
	stwio	r3, 8(r18)
	
	movia	r18, JTAG_UART_BASE
	addi	r19, r0, '\n'
	
	movi	r3, 3	
	wrctl	ienable, r3	# habilta interrupção no irq0 e irq1
	subi	r3, r3, 2	# r3 == 1
	wrctl	status, r3	# habilta interrupção no processador

	MAIN_LOOP:
		movia	r15, OP_CODES
		
		movia	r17, MESSAGE
		call	SHOW_MESSAGE
		call	READ_COMMAND
		
		movia	r17, INPUT
		
		CONVERT_TO_CODE
		SWITCH_CASE CASE_00
		SWITCH_CASE CASE_01
		SWITCH_CASE CASE_10
		SWITCH_CASE CASE_11
		SWITCH_CASE CASE_20
		SWITCH_CASE CASE_21
		SWITCH_CASE CASE_30
		SWITCH_CASE CASE_31

		br		CASE_INVALID
		
		CASE_00:
			call	TURN_ON_RED_LED
			br		NEW_LINE
		CASE_01:
			call	TURN_OFF_RED_LED
			br		NEW_LINE
		CASE_10:
			movia	r4, RED_LED_STATUS
			ldw		r4, 0(r4)
			movia	r5, RED_LED_BASE
			ldwio	r5, 0(r5)
			bne		r4, r0, ALREADY_ANIMATING		# usado para avisar que já está em andamento
			beq		r5, r0, NO_LED_TURNED_ON		# usado para não habilitar a animação com tudo apagado
			br		TURN_ON_ANIMATION
			
			ALREADY_ANIMATING:
				movia	r17, INVALID_RED_LED_ANIMATION_MSG
				call	SHOW_MESSAGE
				br		NEW_LINE
			
			NO_LED_TURNED_ON:
				movia	r17, INVALID_RED_LED_ANIMATION_MSG_2
				call	SHOW_MESSAGE
				br		NEW_LINE
			
			TURN_ON_ANIMATION:
				SET_STATUS 	RED_LED_STATUS, 1
				movia	r4, 0x9680
				movi	r5, 0x98
				call	SET_TIMER
			br		NEW_LINE
		CASE_11:
			call	STOP_TIMER
			SET_STATUS 	RED_LED_STATUS, 0
			br		NEW_LINE
		CASE_20:
			movia	r4, CRONOMETER_STATUS
			ldw		r4, 0(r4)
			bne		r4, r0, ALREADY_FUNC		# usado para verificar se o cronometro já nao está ativo
			br		TURN_ON
			
			ALREADY_FUNC:
				movia 	r17, INVALID_CRONOMETER_MSG
				call	SHOW_MESSAGE
				br		NEW_LINE
			TURN_ON:
				SET_STATUS 	CRONOMETER_STATUS, 1
				call	UPDATE_CRONOMETER
				movia	r4, 0x9680
				movi	r5, 0x98
				call	SET_TIMER
			br		NEW_LINE
		CASE_21:
			call	CANCEL_CRONOMETER
			br		NEW_LINE
		CASE_30:
			call	SHOW_UNESP_IN_VGA
			br		NEW_LINE
		CASE_31:
			movia	r17, AWAIT_CLEAN
			call	SHOW_MESSAGE
			call	BLANK
			movia	r17, CLEAN_CONCLUDED
			call	SHOW_MESSAGE
			br		NEW_LINE
		CASE_INVALID:
			movia	r17, INVALID
			call	SHOW_MESSAGE
			
		NEW_LINE:
			stwio	r19, 0(r18)
			br		MAIN_LOOP

WAIT:
	br		WAIT

SHOW_MESSAGE:
	subi	sp, sp, 20		
	stw		ra, 0(sp)
	stw		fp, 4(sp)
	stw		r15, 8(sp)
	stw 	r16, 12(sp)
	stw 	r17, 16(sp)
    addi	fp, sp, 20
	
	movia	r15, JTAG_UART_BASE
	
	CHECK_WSPACE:
		ldwio	r16, 4(r15)			# lê o registrador de controle do JTAG UART 
		andhi	r16, r16, 0xffff	# Checa o WSPACE
		beq		r16, r0, NO_SPACE	
		mov		r16, r17			# carrega o endereço da mensagem
		WRITE_MESSAGE:
			ldb		r17, 0(r16)
			beq		r17, r0, NO_SPACE
			stwio   r17, 0(r15)		# Mostra o caracter no JTAG UART
			addi	r16, r16, 1
			br		WRITE_MESSAGE
			
	NO_SPACE:	
		ldw		ra, 0(sp)
        ldw		fp, 4(sp)
		ldw		r15, 8(sp)
        ldw		r16, 12(sp)
        ldw		r17, 16(sp)
        addi	sp, sp, 20
		ret

READ_COMMAND:
	subi	sp, sp, 48	
	stw		ra, 0(sp)
	stw		fp, 4(sp)
	stw		r14, 8(sp)
	stw 	r15, 12(sp)
	stw 	r16, 16(sp)
    stw 	r17, 20(sp)
	stw 	r18, 24(sp)
	stw 	r19, 28(sp)
	stw 	r20, 32(sp)
	stw 	r21, 36(sp)
	stw 	r22, 40(sp)
	stw 	r23, 44(sp)
	addi	fp, sp, 48

	movia	r14, INPUT
	movia	r15, JTAG_UART_BASE
	addi	r18, r0, 2
	addi	r19, r0, 0x7f			# valor referente ao 'backspace'
	addi	r20, r0, 0x8			# valor usado para andar para trás no JTAG UART
	addi	r21, r0, ' '			# Usado para apagar o char no terminal
	addi	r22, r0, 2				# Referente ao número máximo de caracteres que podem ser digitados
	addi	r23, r0, 0x0a			# Referente ao 'enter'

	GET_CHAR:
		ldwio   r16, 0(r15)			# Verifica se o JTAG UART possui novos dados e
		andi    r17, r16, 0x8000	# lê o caracter          
		beq     r17, r0, GET_CHAR		
		andi    r17, r16, 0x00ff	# Os dados estão no bits menos significativos
		beq		r17, r23, FINISH_COMMAND
		beq		r17, r19, BACKSPACE
		beq		r18, r0, GET_CHAR		
		br		PUT_CHAR

	BACKSPACE:
		beq		r18, r22, GET_CHAR
		stwio	r20, 0(r15)			# anda para trás
		stwio	r21, 0(r15)			# sobrescreve com ' '
		stwio	r20, 0(r15)			# anda para trás novamente
		addi	r18, r18, 1			# aumenta o numero de caracteres que ainda podem ser digitados pelo usuario
		stw		r0, 0(r14)			# zera uma das posicoes do input guardado na memoria
		subi	r14, r14, 4			# volta uma posicao no endereço de memoria do input
		br		GET_CHAR

	PUT_CHAR:
		ldwio   r16, 4(r15)			# lê o registrador de controle do JTAG UART 
		andhi   r16, r16, 0xffff	# Checa o WSPACE
		beq     r16, r0, GET_CHAR	
		stwio   r17, 0(r15)			# Mostra o caracter no JTAG UART
		subi	r18, r18, 1
		stw		r17, 0(r14)
		addi	r14, r14, 4

	br 		GET_CHAR

	FINISH_COMMAND:
		stwio	r21, 0(r15)			# escreve um espaço no final
		ldw		ra, 0(sp)
		ldw		fp, 4(sp)
		ldw		r14, 8(sp)
		ldw 	r15, 12(sp)
		ldw 	r16, 16(sp)
		ldw 	r17, 20(sp)
		ldw 	r18, 24(sp)
		ldw 	r19, 28(sp)
		ldw 	r20, 32(sp)
		ldw 	r21, 36(sp)
		ldw 	r22, 40(sp)
		ldw 	r23, 44(sp)
		addi	sp, sp, 48
		ret

TURN_ON_RED_LED:			# funcao que le a entrada do led desejado, realiza slli's até alcancar o led e escreve no RED_LED_BASE
	subi	sp, sp, 20		
	stw		ra, 0(sp)
	stw		fp, 4(sp)
	stw		r15, 8(sp)
	stw 	r16, 12(sp)
	stw 	r17, 16(sp)
    addi	fp, sp, 20

	call	READ_COMMAND	# le o comando referente ao LED correspondente (01 a 32)

	movia	r15, RED_LED_BASE
	movia	r17, INPUT

	CONVERT_TO_CODE
	
	beq		r16, r0, INVALID_RANGE_RLED
	cmpgti	r17, r16, 32
	bne		r17, r0, INVALID_RANGE_RLED
	addi	r17, r0, 1

	br		COND_WHILE
	WHILE:
		slli	r17, r17, 1
	COND_WHILE:
		subi	r16, r16, 1
		beq		r16, r0, WRITE_ON_RED_LED
		br		WHILE
		
	WRITE_ON_RED_LED:
		ldwio	r16, 0(r15)
		and		r16, r17, r16
		bne		r16, r0, LIGHT_ON_MSG
		ldwio	r16, 0(r15)
		or		r17, r17, r16
		stwio	r17, 0(r15)
		br		END_TURN_ON
	
	INVALID_RANGE_RLED:
		movia	r17, INVALID_RED_LED
		call	SHOW_MESSAGE
		br		END_TURN_ON

	LIGHT_ON_MSG:	# caso o led já esteja aceso
		movia	r17, LIGHT_ON_RED_LED
		call	SHOW_MESSAGE
		
	END_TURN_ON:
		ldw		ra, 0(sp)
        ldw		fp, 4(sp)
		ldw		r15, 8(sp)
        ldw		r16, 12(sp)
        ldw		r17, 16(sp)
        addi	sp, sp, 20
	ret

TURN_OFF_RED_LED:
	subi	sp, sp, 20		
	stw		ra, 0(sp)
	stw		fp, 4(sp)
	stw		r15, 8(sp)
	stw 	r16, 12(sp)
	stw 	r17, 16(sp)
    addi	fp, sp, 20
	
	movia	r15, RED_LED_BASE
	ldwio	r16, 0(r15)
	beq		r16, r0, ALL_TURNED_OFF
	
	call	READ_COMMAND
	
	movia	r17, INPUT
	
	CONVERT_TO_CODE
	
	beq		r16, r0, INVALID_RANGE
	cmpgti	r17, r16, 32
	bne		r17, r0, INVALID_RANGE
	addi	r17, r0, 1
	
	br		COND_LOOP
	LOOP:
		slli	r17, r17, 1
	COND_LOOP:
		subi	r16, r16, 1
		beq		r16, r0, UPDATE_RED_LED
		br		LOOP
		
	UPDATE_RED_LED:
		ldwio	r16, 0(r15)
		and		r17, r16, r17
		beq		r17, r0, ALREADY_TURNED_OFF
		xor		r16, r16, r17 
		stwio	r16, 0(r15)
		br		END_TURN_OFF	
	
	ALL_TURNED_OFF:
		movia	r17, ALL_RED_LED_OFF
		call	SHOW_MESSAGE
		br		END_TURN_OFF
	
	INVALID_RANGE:
		movia	r17, INVALID_RED_LED
		call	SHOW_MESSAGE
		br		END_TURN_OFF
	
	ALREADY_TURNED_OFF:
		movia	r17, LIGHT_OFF_RED_LED
		call	SHOW_MESSAGE
	
	END_TURN_OFF:
		ldw		ra, 0(sp)
        ldw		fp, 4(sp)
		ldw		r15, 8(sp)
        ldw		r16, 12(sp)
        ldw		r17, 16(sp)
        addi	sp, sp, 20
	ret

RED_LED_ANIMATION:
	subi	sp, sp, 32		
	stw		ra, 0(sp)
	stw		fp, 4(sp)
	stw     r15, 8(sp)
	stw 	r16, 12(sp)
	stw 	r17, 16(sp)
	stw		r18, 20(sp)
	stw		r19, 24(sp)
	stw		r20, 28(sp)
    addi	fp, sp, 32
    
	movia	r16, INTERVAL_TIMER_BASE
	movi	r17, 0b01000	# STOP = 1, START = 0, CONT = 0, ITO = 0 
	sthio	r17, 4(r16)
    
	movia	r15, SWITCH_BASE
	movia	r20, RED_LED_BASE
	add		r19, r0, r0

	ldwio	r17, 0(r15)
	ldwio	r18, 0(r20)
	andi	r17, r17, 0x1	# referente ao switch 0
	
	beq		r17, r0, LED_CLOCKWISE		# se o switch não estiver em 1, os leds irão animar em sentido horário
	ror		r19, r17, r17				# r19 fica com o valor máximo que o r17 pode ir
	br		LED_COUNTER_CLOCKWISE		# caso contrário, irá ser em sentido anti-horário
	
	ROTATE_RIGHT:
		ror		r18, r18, r17
		br		UPDATE_CLOCKWISE
	LED_CLOCKWISE:
		andi	r17, r18, 0x1
		blt		r0, r17, ROTATE_RIGHT
		
		srli	r18, r18, 1
		UPDATE_CLOCKWISE:	
			stwio	r18, 0(r20)
			br		RETURN_TO_NORMAL

	ROTATE_LEFT:
		roli	r18, r18, 1
		br		UPDATE_COUNTER_CLOCKWISE
	LED_COUNTER_CLOCKWISE:
		and		r17, r18, r19
		beq		r19, r17, ROTATE_LEFT
		
		slli	r18, r18, 1
		UPDATE_COUNTER_CLOCKWISE:	
			stwio	r18, 0(r20)
	
	RETURN_TO_NORMAL:
	   	ldw		ra, 0(sp)
        ldw		fp, 4(sp)
        ldw		r15, 8(sp)
        ldw		r16, 12(sp)
        ldw		r17, 16(sp)
        ldw		r18, 20(sp)
		ldw		r19, 24(sp)
		ldw		r20, 28(sp)
		addi	sp, sp, 32
	
	ret

START_TIMER:
	subi	sp, sp, 16		
	stw		ra, 0(sp)
	stw		fp, 4(sp)
	stw		r15, 8(sp)
	stw 	r16, 12(sp)
    addi	fp, sp, 16
	
	movia	r16, INTERVAL_TIMER_BASE
    movi	r15, 0b00111	# START = 1, CONT = 1, ITO = 1 
	sthio	r15, 4(r16)
	
	ldw		ra, 0(sp)
    ldw		fp, 4(sp)
	ldw		r15, 8(sp)
    ldw		r16, 12(sp)
    addi	sp, sp, 16
	
	ret

STOP_TIMER:
	subi	sp, sp, 16	
	stw		ra, 0(sp)
	stw		fp, 4(sp)
	stw		r15, 8(sp)
	stw 	r16, 12(sp)
    addi	fp, sp, 16
	
	movia	r15, CRONOMETER_STATUS
	movia	r16, RED_LED_STATUS
	ldw		r15, 0(r15)
	ldw		r16, 0(r16)
	
	or		r15, r15, r16
	addi	r16, r0, 2
	# analisa se os leds e o cronometro estao ligados
	# analisa se 1 dos dois está ligado
	bne		r15, r16, END_STOP_TIMER	
	
	movia	r15, INTERVAL_TIMER_BASE
    movi	r16, 0b01000	# STOP = 1, START = 0, CONT = 0, ITO = 0 
	sthio	r16, 4(r15)
	
	END_STOP_TIMER:
		ldw		ra, 0(sp)
		ldw		fp, 4(sp)
		ldw		r15, 8(sp)
		ldw		r16, 12(sp)
		addi	sp, sp, 16

	ret

SET_TIMER:
	subi	sp, sp, 16	
	stw		ra, 0(sp)
	stw		fp, 4(sp)
	stw		r15, 8(sp)
	stw 	r16, 12(sp)
    addi	fp, sp, 16
	
	movia	r16, INTERVAL_TIMER_BASE
	sthio	r4, 8(r16)		# seta o timer novamente com o valor inicial
	sthio	r5, 12(r16)
	sthio	r0, 0(r16)		# T0 = 1 -> T0 = 0
	movi	r15, 0b00111	# START = 1, CONT = 1, ITO = 1 
	sthio	r15, 4(r16)			
	
	ldw		ra, 0(sp)
    ldw		fp, 4(sp)
	ldw		r15, 8(sp)
    ldw		r16, 12(sp)
    addi	sp, sp, 16

	ret

UPDATE_CRONOMETER:
	subi	sp, sp, 44
	stw		ra, 0(sp)
	stw		fp, 4(sp)
	stw		r14, 8(sp)
	stw 	r15, 12(sp)
	stw 	r16, 16(sp)
	stw 	r17, 20(sp)
	stw 	r18, 24(sp)
	stw 	r19, 28(sp)
	stw 	r20, 32(sp)
	stw 	r21, 36(sp)
	stw		r22, 40(sp)
	addi	fp, sp, 44
	
	movia	r14, SEVEN_SEG_DECODE_TABLE	# Tabela de indexação
	movia	r15, CRONOMETER_VALUE		
	ldw		r16, 0(r15)					# Valor atual do cronômetro
	
	cmpeqi	r17, r16, 3600				# Compara com o valor máximo de 1 hora
	beq		r17, r0, SEVEN_SEG_DECODER
	add		r16, r0, r0					# Reseta o valor caso chegue a 1 hora
	
	# r18 = guarda o quociente da divisão
	# r19 = guarda o resto da divisão
	SEVEN_SEG_DECODER:
		add		r22, r16, r0
		DIVIDE_TIME 10	# Acha o primeiro digito dos segundos
		
		HEX0:
			WRITE_ON_HEX r19 # Escreve o resto da divisão no Display
		
		mov		r16, r18	# quociente vira novo dividendo
		DIVIDE_TIME 6	# Acha o segundo digito dos segundos
		
		HEX1:
			WRITE_ON_HEX r19
	
		mov		r16, r18		
		DIVIDE_TIME 10	# Acha o primeiro digito das horas
	
		HEX2:
			WRITE_ON_HEX r19
		HEX3:
			WRITE_ON_HEX r18 # Escreve o quociente no Display
			
	WRITE_ON_DISPLAY:
		# escreve no display
		movia	r15, CRONOMETER_VALUE
		ldw		r16, 0(r15)
		movia	r17, HEX3_HEX0_BASE
		stwio	r16, 0(r17)

	addi	r22, r22, 1
	stw		r22, 0(r15)
	
	ldw		ra, 0(sp)
	ldw		fp, 4(sp)
	ldw		r14, 8(sp)
	ldw 	r15, 12(sp)
	ldw 	r16, 16(sp)
	ldw 	r17, 20(sp)
	ldw 	r18, 24(sp)
	ldw 	r19, 28(sp)
	ldw 	r20, 32(sp)
	ldw 	r21, 36(sp)
	ldw		r22, 40(sp)
	addi	sp, sp, 44
    
	ret

CANCEL_CRONOMETER:
	subi	sp, sp, 16		
	stw		ra, 0(sp)
	stw		fp, 4(sp)
	stw		r15, 8(sp)
	stw		r16, 12(sp)
    addi	fp, sp, 16

	movia	r15, CRONOMETER_VALUE
	stw		r0, 0(r15)
	
	SET_STATUS	CRONOMETER_STATUS 0
	
	movia	r15, HEX3_HEX0_BASE
	stwio	r0, 0(r15)
	
	movia	r15, RED_LED_STATUS
	ldw		r15, 0(r15)
	bne		r15, r0, CONTINUE_RED_LED
	
	movia	r15, INTERVAL_TIMER_BASE
    movi	r16, 0b01000	# STOP = 1, START = 0, CONT = 0, ITO = 0 
	sthio	r16, 4(r15)
	stwio	r0, 8(r15)
	stwio	r0, 12(r15)
	br		END_CANCEL
	
	CONTINUE_RED_LED:
		movia	r4, 0x9680
		movi	r5, 0x98
		call	SET_TIMER
	
	END_CANCEL:
		ldw		ra, 0(sp)
		ldw		fp, 4(sp)
		ldw		r15, 8(sp)
		ldw		r16, 12(sp)
		addi	sp, sp, 16
	
	ret

SHOW_UNESP_IN_VGA:
	subi	sp, sp, 24		
	stw		ra, 0(sp)
	stw		fp, 4(sp)
	stw		r10, 8(sp)
	stw		r11, 12(sp)
	stw		r12, 16(sp)
	stw		r17, 20(sp)
    addi	fp, sp, 24

	movia	r17, AWAIT_RENDER
	call	SHOW_MESSAGE
	
	# r10 sempre recebe o valor da cor
	movia 	r11, 0x00000f 	# azul
	mov 	r10, r0
	call 	BLANK			# Limpa a tela
	mov 	r10, r11		
	movia	r12, UNESP_LOGO_LIMITS # tabela com as posicoes a serem escritas de cada triangulo
	
	FIRST_LINE:	
		call 	TRIANGLE_FACE_UP
		call 	TRIANGLE_FACE_DOWN
		call 	TRIANGLE_FACE_UP
	SECOND_LINE:
		call 	TRIANGLE_FACE_UP
		call 	TRIANGLE_FACE_DOWN
		call 	TRIANGLE_FACE_UP
		call 	TRIANGLE_FACE_DOWN
		call 	TRIANGLE_FACE_UP
		call 	TRIANGLE_FACE_DOWN
	THIRD_LINE:
		call 	TRIANGLE_FACE_DOWN
		call 	TRIANGLE_FACE_UP
		call 	TRIANGLE_FACE_DOWN

	movia	r17, RENDER_CONCLUDED
	call	SHOW_MESSAGE

	END_SHOW_UNESP:
		ldw		ra, 0(sp)
		ldw		fp, 4(sp)
		ldw		r10, 8(sp)
		ldw		r11, 12(sp)
		ldw		r12, 16(sp)
		ldw		r17, 20(sp)
		addi	sp, sp, 24
		ret
	
BLANK:
	subi 	sp, sp, 20
    stw 	ra, 0(sp)		
    stw 	fp, 4(sp)
    stw 	r16, 8(sp)
    stw 	r17, 12(sp)
	stw		r18, 16(sp)
	addi	fp, sp, 20
	
    mov 	r18, r10
	
    movi 	r16, WIDTH-1
    FOR_EXT_BLANK:	
		movi 	r17, HEIGHT-1
		FOR_INT_BLANK:  
			mov 	r4, r16
            mov 	r5, r17
            mov 	r6, r18
            call 	WRITE_PIXEL	
            subi 	r17, r17, 1
            bge 	r17, r0, FOR_INT_BLANK
        subi 	r16, r16, 1
        bge 	r16, r0, FOR_EXT_BLANK
    
    ldw 	ra, 0(sp)
	ldw 	fp, 4(sp)
    ldw 	r16, 8(sp)
    ldw 	r17, 12(sp)
	ldw		r18, 16(sp)
    addi 	sp, sp, 20
    ret

# r4: col (x)
# r5: row (y)
# r6: colour value
WRITE_PIXEL:
	subi 	sp, sp, 24
    stw 	ra, 0(sp)		
    stw 	fp, 4(sp)
    stw 	r2, 8(sp)
    stw 	r3, 12(sp)
	stw		r4, 16(sp)
	stw		r5, 20(sp)
	addi	fp, sp, 24

	movi 	r2, LOG2_BYTES_PER_ROW		
    movi 	r3, LOG2_BYTES_PER_PIXEL	
    
    sll 	r5, r5, r2
    sll 	r4, r4, r3
    add 	r5, r5, r4
    movia 	r4, PIXEL_BUFFER
    add 	r5, r5, r4
    
    bne 	r3, r0, WRITE_16_BIT	# 8bpp or 16bpp?
  	WRITE_8_BIT:
		stbio 	r6, 0(r5)			# Write 8-bit pixel
    	br		END_WRITE_PIXEL
    
	WRITE_16_BIT:	
		sthio 	r6, 0(r5)			# Write 16-bit pixel
	END_WRITE_PIXEL:
		ldw		ra, 0(sp)
		ldw		fp, 4(sp)
		ldw		r2, 8(sp)
		ldw		r3, 12(sp)
		ldw		r4, 16(sp)
		ldw		r5, 20(sp)
		addi	sp, sp, 24
		ret

TRIANGLE_FACE_UP:
    subi	sp, sp, 44
	stw		ra, 0(sp)
	stw		fp, 4(sp)
	stw		r4, 8(sp)
	stw		r16, 12(sp)
	stw 	r17, 16(sp)
    stw		r18, 20(sp)
	stw		r19, 24(sp)
	stw		r20, 28(sp)
	stw		r21, 32(sp)
	stw		r22, 36(sp)
	stw		r23, 40(sp)
	addi	fp, sp, 44
	
	mov 	r18, r10
	ldw		r20, 0(r12)		# x inicial
	ldw		r21, 4(r12)		# limite do x
	ldw		r17, 8(r12)		# y inicial
	ldw		r19, 12(r12)	# limite do y
    movi 	r23, 0		# usado para esticar o triangulo renderizado
	
    FOR_EXT_T_UP:	
		mov		r16, r20
        FOR_INT_T_UP:  
			mov		r4, r16
            mov		r5, r17
            mov 	r6, r18
            call 	WRITE_PIXEL
            subi 	r16, r16, 1
            bge 	r16, r21, FOR_INT_T_UP
		addi	r23, r23, 1
		
		cmpeqi 	r22, r23, 2
		bne		r22, r0, RESET_COUNTER_T_UP
		subi 	r20, r20, 1
		addi 	r21, r21, 1
		RETURN_T_UP:
			subi 	r17, r17, 1
			blt 	r19, r17, FOR_EXT_T_UP
			br		END_T_UP
	
	RESET_COUNTER_T_UP:
		movi 	r23, 0
		br		RETURN_T_UP
	
	END_T_UP:
	addi	r12, r12, 16
	ldw		ra, 0(sp)
    ldw		fp, 4(sp)
	ldw		r4, 8(sp)
	ldw		r16, 12(sp)
    ldw		r17, 16(sp)
	ldw		r18, 20(sp)
	ldw		r19, 24(sp)
	ldw		r20, 28(sp)
	ldw		r21, 32(sp)
	ldw		r22, 36(sp)
	ldw		r23, 40(sp)
    addi	sp, sp, 44
	
	ret

TRIANGLE_FACE_DOWN:
	subi	sp, sp, 44
	stw		ra, 0(sp)
	stw		fp, 4(sp)
	stw		r4, 8(sp)
	stw		r16, 12(sp)
	stw 	r17, 16(sp)
    stw		r18, 20(sp)
	stw		r19, 24(sp)
	stw		r20, 28(sp)
	stw		r21, 32(sp)
	stw		r22, 36(sp)
	stw		r23, 40(sp)
	addi	fp, sp, 44
	
	mov 	r18, r10
   	ldw		r20, 0(r12)
	ldw		r21, 4(r12)
	ldw		r17, 8(r12)
	ldw		r19, 12(r12)
	movi 	r23, 0
	
    FOR_EXT_T_DOWN:	
		mov		r16, r20
        FOR_INT_T_DOWN:  
			mov		r4, r16
            mov		r5, r17
            mov 	r6, r18
            call 	WRITE_PIXEL
            subi 	r16, r16, 1
            bge 	r16, r21, FOR_INT_T_DOWN
		addi	r23, r23, 1
		
		cmpeqi 	r22, r23, 2
		bne		r22, r0, RESET_COUNTER_T_DOWN
		subi 	r20, r20, 1
		addi 	r21, r21, 1
		RETURN_T_DOWN:
			addi 	r17, r17, 1
			blt 	r17, r19, FOR_EXT_T_DOWN
			br		END_T_DOWN
	
	RESET_COUNTER_T_DOWN:
		movi 	r23, 0
		br		RETURN_T_DOWN
	
	END_T_DOWN:
	addi	r12, r12, 16
	ldw		ra, 0(sp)
    ldw		fp, 4(sp)
	ldw		r4, 8(sp)
	ldw		r16, 12(sp)
    ldw		r17, 16(sp)
	ldw		r18, 20(sp)
	ldw		r19, 24(sp)
	ldw		r20, 28(sp)
	ldw		r21, 32(sp)
	ldw		r22, 36(sp)
	ldw		r23, 40(sp)
    addi	sp, sp, 44
	
	ret

.org 0x2000
INPUT:
.word	0,0
OP_CODES:
.word 	00, 01, 10, 11, 20, 21, 30, 31
RED_LED_STATUS:
.word	0
CRONOMETER_STATUS:
.word	0
CRONOMETER_COUNTER:
.word	0
CRONOMETER_VALUE:
.word	0
UNESP_LOGO_LIMITS: # Starter eixo x, limite eixo x, Starter eixo y, limite eixo y 
LINE1:
.word	WIDTH-188, WIDTH-238, HEIGHT-155, HEIGHT-205 
.word	WIDTH-153, WIDTH-203, HEIGHT-205, HEIGHT-155
.word	WIDTH-118, WIDTH-168, HEIGHT-155, HEIGHT-205
LINE2:
.word	WIDTH-223, WIDTH-273, HEIGHT-95, HEIGHT-145
.word	WIDTH-188, WIDTH-238, HEIGHT-145, HEIGHT-95
.word	WIDTH-153, WIDTH-203, HEIGHT-95, HEIGHT-145
.word	WIDTH-118, WIDTH-168, HEIGHT-145, HEIGHT-95
.word	WIDTH-83, WIDTH-133, HEIGHT-95, HEIGHT-145
.word	WIDTH-48, WIDTH-98, HEIGHT-145, HEIGHT-95
LINE3:
.word	WIDTH-153, WIDTH-203, HEIGHT-85, HEIGHT-35
.word	WIDTH-118, WIDTH-168, HEIGHT-35, HEIGHT-85
.word	WIDTH-83, WIDTH-133, HEIGHT-85, HEIGHT-35

.org 0x2500
SEVEN_SEG_DECODE_TABLE:
.byte 0b00111111, 0b00000110, 0b01011011, 0b01001111    # 0, 1, 2, 3
.byte 0b01100110, 0b01101101, 0b01111101, 0b00000111    # 4, 5, 6, 7
.byte 0b01111111, 0b01100111   							# 8, 9
MESSAGE:
.asciz	"Entre com o comando: "
INVALID:
.asciz	"\nComando invalido!"
INVALID_CRONOMETER_MSG:
.asciz 	"\nCronometro ja esta ativo!"
LIGHT_ON_RED_LED:
.asciz	"\nLED vermelho ja esta aceso!"
LIGHT_OFF_RED_LED:
.asciz	"\nLED vermelho ja esta apagado!"
INVALID_RED_LED:
.asciz	"\nLED vermelho inexistente!"
ALL_RED_LED_OFF:
.asciz	"\nTodos os LEDs vermelhos estao apagados!"
INVALID_RED_LED_ANIMATION_MSG:
.asciz	"\nAnimacao de LEDs vermelhos ja esta ativa"
INVALID_RED_LED_ANIMATION_MSG_2:
.asciz	"\nNenhum LED vermelho esta aceso!"
AWAIT_RENDER:
.asciz 	"\nAguarde a renderizacao da imagem terminar"
AWAIT_CLEAN:
.asciz	"\nAguarde a limpeza da tela"
RENDER_CONCLUDED:
.asciz	"\nRenderizacao concluida!"
CLEAN_CONCLUDED:
.asciz	"\nLimpeza da tela concluida!"

.end
// ============================================================
// TP2: Sistema de Monitoreo Ambiental - Mars Sample Return
// Arquitectura ARMv8 (AArch64) - QEMU virt
// Punto de entrada: 0x40080000
// Stack: 0x40480000 (_stack_end)
// ============================================================

.section .text
.global _start

// ============================================================
// PUNTO DE ENTRADA PRINCIPAL
// ============================================================
_start:
    ldr x0, =_stack_end
    mov sp, x0
    bl system_init
    mov x19, #0

main_loop:
    bl timer_tick

    mov x0, #0
    bl process_sensor
    mov x0, #1
    bl process_sensor
    mov x0, #2
    bl process_sensor
    mov x0, #3
    bl process_sensor

    ldr x0, =timer_ticks
    ldr w1, [x0]
    mov w2, #5
    udiv w3, w1, w2
    msub w4, w3, w2, w1
    cbnz w4, skip_report
    bl generate_report
skip_report:

    add x19, x19, #1
    cmp x19, #100
    blt main_loop

    b program_end

// ============================================================
// system_init: Inicializa el sistema
// ============================================================
system_init:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    ldr x0, =timer_ticks
    str wzr, [x0]
    ldr x0, =idx_rad
    str wzr, [x0]
    ldr x0, =idx_temp
    str wzr, [x0]
    ldr x0, =idx_pres
    str wzr, [x0]
    ldr x0, =idx_part
    str wzr, [x0]
    ldr x0, =count_rad
    str wzr, [x0]
    ldr x0, =count_temp
    str wzr, [x0]
    ldr x0, =count_pres
    str wzr, [x0]
    ldr x0, =count_part
    str wzr, [x0]

    ldp x29, x30, [sp], #16
    ret

// ============================================================
// timer_tick: Incrementa el contador de tiempo
// ============================================================
timer_tick:
    ldr x0, =timer_ticks
    ldr w1, [x0]
    add w1, w1, #1
    str w1, [x0]
    ret

// ============================================================
// process_sensor: Procesa un sensor completo
// Entrada: X0 = ID del sensor (0-3)
// ============================================================
process_sensor:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]

    mov x19, x0
    bl sensor_read
    mov x20, x0

    cmp x19, #0
    beq use_rad_buffer
    cmp x19, #1
    beq use_temp_buffer
    cmp x19, #2
    beq use_pres_buffer
    b use_part_buffer

use_rad_buffer:
    ldr x21, =buffer_rad
    ldr x22, =idx_rad
    ldr x3, =count_rad
    b write_to_buffer

use_temp_buffer:
    ldr x21, =buffer_temp
    ldr x22, =idx_temp
    ldr x3, =count_temp
    b write_to_buffer

use_pres_buffer:
    ldr x21, =buffer_pres
    ldr x22, =idx_pres
    ldr x3, =count_pres
    b write_to_buffer

use_part_buffer:
    ldr x21, =buffer_part
    ldr x22, =idx_part
    ldr x3, =count_part

write_to_buffer:
    mov x0, x21
    mov x1, x20
    mov x2, x22
    bl buffer_write

    mov x0, x20
    mov x1, x19
    bl check_alert
    mov x21, x0

    cbz x21, no_alert

    ldr x0, =timer_ticks
    ldr w3, [x0]

    mov x0, x19
    mov x1, x20
    mov x2, x21
    bl log_event

no_alert:
    ldp x19, x20, [sp, #16]
    ldp x21, x22, [sp, #32]
    ldp x29, x30, [sp], #48
    ret

// ============================================================
// sensor_read: Lee dato de sensor simulado
// ============================================================
sensor_read:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    cmp x0, #3
    bhi sensor_read_error

    adr x1, sensor_table
    ldr w2, [x1, x0, lsl #2]

    ldr x3, =timer_ticks
    ldr w4, [x3]
    and w4, w4, #0xF

    cmp x0, #0
    beq sensor_read_rad
    cmp x0, #1
    beq sensor_read_temp
    cmp x0, #2
    beq sensor_read_pres
    b sensor_read_part

sensor_read_rad:
    add w0, w2, w4
    b sensor_read_done

sensor_read_temp:
    sub w0, w2, w4
    b sensor_read_done

sensor_read_pres:
    add w0, w2, w4, lsl #2
    b sensor_read_done

sensor_read_part:
    add w0, w2, w4, lsl #1
    b sensor_read_done

sensor_read_error:
    mov w0, #0

sensor_read_done:
    ldp x29, x30, [sp], #16
    ret

// ============================================================
// buffer_write: Escribe muestra en buffer circular
// ============================================================
buffer_write:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    ldr w4, [x2]
    str w1, [x0, w4, uxtw #2]

    add w4, w4, #1
    cmp w4, #100
    csel w4, wzr, w4, eq
    str w4, [x2]

    ldr w5, [x3]
    cmp w5, #100
    add w5, w5, #1
    csel w5, w5, wzr, lt
    str w5, [x3]

    ldp x29, x30, [sp], #16
    ret

// ============================================================
// moving_average: Calcula promedio de ultimas N muestras
// ============================================================
moving_average:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]

    mov x19, x0
    mov x20, x1
    ldr w21, [x2]

    cmp w21, w20
    csel w20, w21, w20, lt

    cbz w20, moving_avg_zero

    mov x5, #0
    mov x6, #0

moving_avg_loop:
    cmp x6, x20
    bge moving_avg_done

    ldr w7, [x19, x6, lsl #2]
    sxtw x7, w7
    add x5, x5, x7

    add x6, x6, #1
    b moving_avg_loop

moving_avg_done:
    sdiv x0, x5, x20
    b moving_avg_exit

moving_avg_zero:
    mov x0, #0

moving_avg_exit:
    ldp x19, x20, [sp, #16]
    ldp x21, x22, [sp, #32]
    ldp x29, x30, [sp], #48
    ret

// ============================================================
// check_alert: Verifica condiciones de alerta
// ============================================================
check_alert:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    cmp x1, #3
    bhi check_alert_none

    adr x2, thresholds
    mov x3, #12
    mul x3, x3, x1
    add x2, x2, x3

    ldr w4, [x2]
    ldr w5, [x2, #4]
    ldr w6, [x2, #8]

    cmp x1, #1
    beq check_alert_temp

    cmp w0, w6
    bge check_alert_level3
    cmp w0, w5
    bge check_alert_level2
    cmp w0, w4
    bge check_alert_level1
    b check_alert_none

check_alert_temp:
    cmp w0, w6
    ble check_alert_level3
    cmp w0, w5
    ble check_alert_level2
    cmp w0, w4
    ble check_alert_level1
    cmp w0, #0
    bgt check_alert_level1
    b check_alert_none

check_alert_level3:
    mov x0, #3
    b check_alert_done

check_alert_level2:
    mov x0, #2
    b check_alert_done

check_alert_level1:
    mov x0, #1
    b check_alert_done

check_alert_none:
    mov x0, #0

check_alert_done:
    ldp x29, x30, [sp], #16
    ret

// ============================================================
// log_event: Registra evento en buffer circular
// ============================================================
log_event:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    cbz x2, log_event_done

    ldr x4, =event_index
    ldr w5, [x4]

    ldr x6, =event_buffer
    mov x7, #16
    mul x7, x5, x7
    add x6, x6, x7

    str w0, [x6]
    str w1, [x6, #4]
    str w2, [x6, #8]
    str w3, [x6, #12]

    add w5, w5, #1
    cmp w5, #50
    csel w5, wzr, w5, eq
    str w5, [x4]

    ldr x4, =event_count
    ldr w5, [x4]
    cmp w5, #50
    add w5, w5, #1
    csel w5, w5, wzr, lt
    str w5, [x4]

log_event_done:
    ldp x29, x30, [sp], #16
    ret

// ============================================================
// generate_report: Genera reporte de estado
// ============================================================
generate_report:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    ldr x0, =buffer_rad
    mov x1, #10
    ldr x2, =count_rad
    bl moving_average
    ldr x3, =avg_rad
    str w0, [x3]

    ldr x0, =buffer_temp
    mov x1, #10
    ldr x2, =count_temp
    bl moving_average
    ldr x3, =avg_temp
    str w0, [x3]

    ldr x0, =buffer_pres
    mov x1, #10
    ldr x2, =count_pres
    bl moving_average
    ldr x3, =avg_pres
    str w0, [x3]

    ldr x0, =buffer_part
    mov x1, #10
    ldr x2, =count_part
    bl moving_average
    ldr x3, =avg_part
    str w0, [x3]

    ldp x29, x30, [sp], #16
    ret

// ============================================================
// program_end: Finaliza el programa (semihosting)
// ============================================================
program_end:
    mov x0, #0x18
    movk x0, #0x0200, lsl #16
    mov x1, #0
    hlt #0xF000

end_loop:
    wfi
    b end_loop

// ============================================================
// SECCION DE DATOS
// ============================================================
.section .data
.balign 8

buffer_rad:
    .space 400
buffer_temp:
    .space 400
buffer_pres:
    .space 400
buffer_part:
    .space 400

.balign 4
idx_rad:    .word 0
idx_temp:   .word 0
idx_pres:   .word 0
idx_part:   .word 0

.balign 4
count_rad:  .word 0
count_temp: .word 0
count_pres: .word 0
count_part: .word 0

.balign 4
avg_rad:    .word 800
avg_temp:   .word -600
avg_pres:   .word 6000
avg_part:   .word 5

.balign 8
event_buffer:
    .space 800
event_index: .word 0
event_count: .word 0

.balign 4
timer_ticks: .word 0

// ============================================================
// SECCION DE DATOS DE SOLO LECTURA
// ============================================================
.section .rodata
.balign 4

sensor_table:
    .word 800
    .word -600
    .word 6000
    .word 5

.balign 4
thresholds:
    .word 1200
    .word 1400
    .word 1500
    .word -100
    .word -110
    .word -120
    .word 5000
    .word 4500
    .word 4000
    .word 30
    .word 40
    .word 50

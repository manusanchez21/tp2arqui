.section .text
.global _start

_start:
    ldr x0, =_stack_end
    mov sp, x0

    mov x19, #0                  // Contador de iteraciones del bucle principal (0..4)

main_loop:
    cmp x19, #100                  // 5 ciclos completos de monitoreo
    b.ge skip_report

    // Incrementar el contador de tiempo global (timer_ticks)
    ldr x0, =timer_ticks
    ldr w1, [x0]
    add w1, w1, #1
    str w1, [x0]

    // --- Procesar los 4 sensores ---
    mov x0, #0
    bl process_sensor

    mov x0, #1
    bl process_sensor

    mov x0, #2
    bl process_sensor

    mov x0, #3
    bl process_sensor

    add x19, x19, #1
    b main_loop

generate_report:
    // Subrutina o hito de reporte
    ret

skip_report:
    b program_end

program_end:
    /* Fin de ejecución con semihosting */
    mov x0, #0x18
    movk x0, #0x0200, lsl #16
    mov x1, #0
    hlt #0xF000

/* =========================================================================
   Subrutina de Integración: process_sensor
   ========================================================================= */
process_sensor:
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]

    mov x19, x0                  // x19 = sensor_id

    // 1. Lectura del sensor
    mov x0, x19
    bl sensor_read
    mov x20, x0                  // x20 = valor medido

    // 2. Selección de punteros
    ldr x21, =buffer_rad
    ldr x22, =idx_rad
    ldr x23, =count_rad
    ldr x24, =avg_rad

    cmp x19, #1
    b.eq setup_temp
    cmp x19, #2
    b.eq setup_pres
    cmp x19, #3
    b.eq setup_part
    b setup_done

setup_temp:
    ldr x21, =buffer_temp
    ldr x22, =idx_temp
    ldr x23, =count_temp
    ldr x24, =avg_temp
    b setup_done

setup_pres:
    ldr x21, =buffer_pres
    ldr x22, =idx_pres
    ldr x23, =count_pres
    ldr x24, =avg_pres
    b setup_done

setup_part:
    ldr x21, =buffer_part
    ldr x22, =idx_part
    ldr x23, =count_part
    ldr x24, =avg_part

setup_done:
    // 3. Guardar en el buffer circular
    mov x0, x21                  // buffer_ptr
    mov x1, x20                  // valor
    mov x2, x22                  // idx_ptr
    mov x3, x23                  // count_ptr
    bl buffer_write

    // 4. Calcular Promedio Móvil
    mov x0, x21
    mov x1, #10
    mov x2, x23
    bl moving_average
    mov x20, x0

    str w20, [x24]               // Guardar promedio en avg_*

    // 5. Evaluar Nivel de Alerta
    mov x0, x20
    mov x1, x19
    bl check_alert

    // 6. Registrar en el buffer de eventos si existe alerta (nivel > 0)
    cbz x0, skip_log

    mov x2, x0
    mov x0, x19
    mov x1, x20
    ldr x3, =timer_ticks
    ldr w3, [x3]
    bl log_event

skip_log:
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

/* =========================================================================
   Subrutinas individuales
   ========================================================================= */
sensor_read:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    cmp x0, #3
    b.hi sensor_read_error
    ldr x1, =sensor_table
    ldr w2, [x1, x0, lsl #2]
    ldr x3, =timer_ticks
    ldr w4, [x3]
    and w4, w4, #0xF
    cmp x0, #0
    b.eq sensor_read_rad
    cmp x0, #1
    b.eq sensor_read_temp
    cmp x0, #2
    b.eq sensor_read_pres
    b sensor_read_part

sensor_read_rad:
    add w0, w2, w4
    b sensor_read_done
sensor_read_temp:
    sub w0, w2, w4
    b sensor_read_done
sensor_read_pres:
    add w0, w2, w4
    b sensor_read_done
sensor_read_part:
    add w0, w2, w4
    b sensor_read_done
sensor_read_error:
    mov x0, #0
sensor_read_done:
    sxtw x0, w0
    ldp x29, x30, [sp], #16
    ret

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
    b.ge buffer_write_skip_count
    add w5, w5, #1
    str w5, [x3]
buffer_write_skip_count:
    ldp x29, x30, [sp], #16
    ret

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
    b.ge moving_avg_done
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

check_alert:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    cmp x1, #3
    b.hi check_alert_none
    ldr x2, =thresholds
    mov x3, #12
    madd x3, x1, x3, xzr
    add x2, x2, x3
    ldr w4, [x2]
    ldr w5, [x2, #4]
    ldr w6, [x2, #8]
    cmp x1, #1
    b.eq check_alert_temp
    cmp w0, w6
    b.ge check_alert_level3
    cmp w0, w5
    b.ge check_alert_level2
    cmp w0, w4
    b.ge check_alert_level1
    b check_alert_none
check_alert_temp:
    cmp w0, w6
    b.le check_alert_level3
    cmp w0, w5
    b.le check_alert_level2
    cmp w0, w4
    b.le check_alert_level1
    b check_alert_none
check_alert_none:
    mov x0, #0
    b check_alert_done
check_alert_level1:
    mov x0, #1
    b check_alert_done
check_alert_level2:
    mov x0, #2
    b check_alert_done
check_alert_level3:
    mov x0, #3
check_alert_done:
    ldp x29, x30, [sp], #16
    ret

log_event:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    cbz x2, log_event_done
    ldr x4, =event_index
    ldr w5, [x4]
    sxtw x5, w5
    ldr x6, =event_buffer
    lsl x7, x5, #4
    add x6, x6, x7
    str w0, [x6]
    str w1, [x6, #4]
    str w2, [x6, #8]
    str w3, [x6, #12]
    add w5, w5, #1
    cmp w5, #50
    csel w5, wzr, w5, eq
    str w5, [x4]
    ldr x8, =event_count
    ldr w9, [x8]
    cmp w9, #50
    b.ge log_event_done
    add w9, w9, #1
    str w9, [x8]
log_event_done:
    ldp x29, x30, [sp], #16
    ret

/* =========================================================================
   SECCIÓN DE DATOS
   ========================================================================= */
.section .data
.balign 8
buffer_rad:   .space 400
buffer_temp:  .space 400
buffer_pres:  .space 400
buffer_part:  .space 400

.balign 4
idx_rad:      .word 0
idx_temp:     .word 0
idx_pres:     .word 0
idx_part:     .word 0

.balign 4
count_rad:    .word 0
count_temp:   .word 0
count_pres:   .word 0
count_part:   .word 0

.balign 4
avg_rad:      .word 0
avg_temp:     .word 0
avg_pres:     .word 0
avg_part:     .word 0

.balign 8
event_buffer: .space 800
event_index:  .word 0
event_count:  .word 0

.balign 4
timer_ticks:  .word 0

.section .rodata
.balign 4
sensor_table:
    .word 1000, -500, 4000, 20

thresholds:
    .word 1200, 1400, 1500
    .word -100, -110, -120
    .word 5000, 4500, 4000
    .word 30, 40, 50

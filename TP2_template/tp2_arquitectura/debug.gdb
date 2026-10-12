# ============================================================
# debug.gdb - Script maestro de depuracion TP2 ARMv8
# ============================================================

# Conectar a QEMU
target remote localhost:1234

# Arquitectura ARMv8
set architecture aarch64
set disassembly-flavor att
set confirm off
set pagination off

# Cargar simbolos
file main.elf

# ------------------------------------------------------------
# Cargar comandos personalizados desde Python
# ------------------------------------------------------------
source debug_commands.py

# ------------------------------------------------------------
# Breakpoints principales
# ------------------------------------------------------------
break _start
break system_init
break process_sensor
break sensor_read
break buffer_write
break check_alert
break log_event
break moving_average
break generate_report

# ------------------------------------------------------------
# Layout del dashboard
# ------------------------------------------------------------
dashboard -layout source assembly registers stack breakpoints expressions
dashboard -style syntax_highlighting monokai
dashboard source -style height 10
dashboard assembly -style height 12
dashboard assembly -style opcodes on
dashboard registers -style height 16

# ------------------------------------------------------------
# Display automatico
# ------------------------------------------------------------
display/i $pc
display/x $sp

echo \n
echo ============================================================\n
echo   TP2 ARMv8 - Sesion de depuracion iniciada\n
echo ============================================================\n
echo   Comandos disponibles:\n
echo     show_all       - Estado completo del sistema\n
echo     show_buffers   - Estado de los 4 buffers circulares\n
echo     show_thresholds- Umbrales de alerta\n
echo     show_events    - Buffer de eventos\n
echo     show_stack     - Estado de la pila\n
echo     show_regs      - Registros ARMv8 relevantes\n
echo ============================================================\n
echo \n

# Iniciar ejecucion
continue

# Test: sesion interactiva con dashboard
target remote localhost:1234
set architecture aarch64
file main.elf
source debug_commands.py

break _start
break system_init
break process_sensor
break buffer_write
break check_alert
break log_event
break generate_report

# Cargar dashboard
dashboard -layout source assembly registers stack breakpoints expressions

echo \nSesion interactiva. Comandos: show_all, show_buffers, etc.\n

continue

# Test: recorrido completo del sistema
target remote localhost:1234
set architecture aarch64
file main.elf
source debug_commands.py

# Breakpoints selectivos
break process_sensor
break buffer_write
break check_alert
break log_event

# Mostrar estado al final de cada iteracion del main_loop
break generate_report
commands
  silent
  echo \n>>> Reporte generado\n
  show_all
  continue
end

continue

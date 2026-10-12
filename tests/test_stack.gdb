# Test: inspeccionar pila y contexto
target remote localhost:1234
set architecture aarch64
file main.elf
source debug_commands.py

# Breakpoints en prologo/epilogo de funciones
break process_sensor
break moving_average

commands
  silent
  echo \n>>> Entrada a funcion\n
  show_stack
  bt
  continue
end

continue

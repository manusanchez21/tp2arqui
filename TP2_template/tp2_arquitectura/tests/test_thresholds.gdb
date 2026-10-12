# Test: inspeccionar umbrales y alertas
target remote localhost:1234
set architecture aarch64
file main.elf
source debug_commands.py

# Breakpoint en check_alert
break check_alert

commands
  silent
  echo \n>>> check_alert: sensor y valor\n
  printf "  x0 (valor) = %d\n", $x0
  printf "  x1 (sensor) = %d\n", $x1
  continue
end

continue

# Test: inspeccionar registro de eventos
target remote localhost:1234
set architecture aarch64
file main.elf
source debug_commands.py

# Breakpoint en log_event
break log_event

commands
  silent
  echo \n>>> log_event: nuevo evento\n
  printf "  sensor=%d valor=%d alerta=%d timestamp=%d\n", $x0, $x1, $x2, $x3
  show_events
  continue
end

continue

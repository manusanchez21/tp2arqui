# Test: inspeccionar buffers circulares
target remote localhost:1234
set architecture aarch64
file main.elf
source debug_commands.py

# Breakpoints en escritura de buffer
break buffer_write

# Al detenerse, mostrar estado de buffers
commands
  silent
  echo \n>>> buffer_write llamado\n
  show_buffers
  continue
end

continue

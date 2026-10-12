# ============================================================
# debug_commands.py - Comandos GDB personalizados para TP2
# ============================================================

import gdb

def read_u32(addr):
    """Lee un uint32 de memoria."""
    return int(gdb.parse_and_eval("*(unsigned int*)%d" % addr))

def read_s32(addr):
    """Lee un int32 de memoria."""
    return int(gdb.parse_and_eval("*(int*)%d" % addr))

def symbol_addr(name):
    """Devuelve la direccion de un simbolo."""
    try:
        return int(gdb.parse_and_eval("&%s" % name))
    except gdb.error:
        return 0

class ShowAll(gdb.Command):
    """Estado completo del sistema TP2."""
    def __init__(self):
        super(ShowAll, self).__init__("show_all", gdb.COMMAND_USER)
    def invoke(self, arg, from_tty):
        print("")
        print("=" * 60)
        print("  ESTADO COMPLETO DEL SISTEMA TP2")
        print("=" * 60)
        gdb.execute("show_buffers")
        print("")
        gdb.execute("show_thresholds")
        print("")
        gdb.execute("show_events")
        print("")
        gdb.execute("show_timer")
        print("")
        gdb.execute("show_stack")

class ShowBuffers(gdb.Command):
    """Muestra el estado de los 4 buffers circulares."""
    def __init__(self):
        super(ShowBuffers, self).__init__("show_buffers", gdb.COMMAND_USER)
    def invoke(self, arg, from_tty):
        print("── BUFFERS CIRCULARES ──")
        sensors = ["RAD ", "TEMP", "PRES", "PART"]
        idx_names = ["idx_rad", "idx_temp", "idx_pres", "idx_part"]
        cnt_names = ["count_rad", "count_temp", "count_pres", "count_part"]
        avg_names = ["avg_rad", "avg_temp", "avg_pres", "avg_part"]
        buf_names = ["buffer_rad", "buffer_temp", "buffer_pres", "buffer_part"]
        for i, sensor in enumerate(sensors):
            idx = read_u32(symbol_addr(idx_names[i]))
            cnt = read_u32(symbol_addr(cnt_names[i]))
            avg = read_s32(symbol_addr(avg_names[i]))
            base = symbol_addr(buf_names[i])
            print("  %s  write_idx=%3d  count=%3d  avg=%6d" % (sensor, idx, cnt, avg))
            vals = []
            for j in range(min(cnt, 5)):
                vals.append(read_s32(base + j * 4))
            print("         Primeras muestras: %s" % " ".join("%6d" % v for v in vals))

class ShowThresholds(gdb.Command):
    """Muestra los umbrales de alerta por sensor."""
    def __init__(self):
        super(ShowThresholds, self).__init__("show_thresholds", gdb.COMMAND_USER)
    def invoke(self, arg, from_tty):
        print("── UMBRALES DE ALERTA ──")
        base = symbol_addr("thresholds")
        sensors = ["RAD ", "TEMP", "PRES", "PART"]
        print("  Sensor  Nivel1   Nivel2   Nivel3")
        for i, sensor in enumerate(sensors):
            n1 = read_s32(base + i * 12 + 0)
            n2 = read_s32(base + i * 12 + 4)
            n3 = read_s32(base + i * 12 + 8)
            print("  %s   %6d  %6d  %6d" % (sensor, n1, n2, n3))

class ShowEvents(gdb.Command):
    """Muestra el buffer de eventos registrados."""
    def __init__(self):
        super(ShowEvents, self).__init__("show_events", gdb.COMMAND_USER)
    def invoke(self, arg, from_tty):
        print("── BUFFER DE EVENTOS ──")
        base = symbol_addr("event_buffer")
        idx = read_u32(symbol_addr("event_index"))
        cnt = read_u32(symbol_addr("event_count"))
        print("  event_index=%d  event_count=%d" % (idx, cnt))
        if cnt == 0:
            print("  (sin eventos registrados)")
            return
        print("  #  Sensor  Valor    Nivel  Timestamp")
        n = min(cnt, 10)
        for i in range(n):
            e = base + i * 16
            sid = read_u32(e + 0)
            val = read_s32(e + 4)
            lvl = read_u32(e + 8)
            ts = read_u32(e + 12)
            print("  %d  %6d  %6d  %5d  %9d" % (i, sid, val, lvl, ts))

class ShowTimer(gdb.Command):
    """Muestra el contador de timer."""
    def __init__(self):
        super(ShowTimer, self).__init__("show_timer", gdb.COMMAND_USER)
    def invoke(self, arg, from_tty):
        t = read_u32(symbol_addr("timer_ticks"))
        print("── TIMER ──")
        print("  timer_ticks = %d" % t)

class ShowStack(gdb.Command):
    """Muestra el estado de la pila."""
    def __init__(self):
        super(ShowStack, self).__init__("show_stack", gdb.COMMAND_USER)
    def invoke(self, arg, from_tty):
        print("── PILA ──")
        sp = int(gdb.parse_and_eval("$sp"))
        stack_top = symbol_addr("_stack_end")
        used = stack_top - sp
        print("  SP        = 0x%016x" % sp)
        print("  Stack top = 0x%016x" % stack_top)
        print("  Usado     = %d bytes" % used)
        print("  Libre     = %d bytes" % (256 - used))
        print("  Contenido (top 8 words):")
        try:
            for i in range(8):
                addr = sp + i * 8
                val = int(gdb.parse_and_eval("*(unsigned long*)%d" % addr))
                print("    [0x%016x] = 0x%016x" % (addr, val))
        except gdb.error as e:
            print("    (no se puede leer: %s)" % e)

ShowAll()
ShowBuffers()
ShowThresholds()
ShowEvents()
ShowTimer()
ShowStack()

print("Comandos personalizados cargados: show_all, show_buffers, show_thresholds, show_events, show_timer, show_stack")

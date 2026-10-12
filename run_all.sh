#!/bin/bash
# ============================================================
# run_all.sh - Compila, lanza QEMU y conecta GDB
# Uso:
#   ./run_all.sh            -> sesion interactiva con dashboard
#   ./run_all.sh buffers    -> test de buffers
#   ./run_all.sh thresholds -> test de umbrales
#   ./run_all.sh events     -> test de eventos
#   ./run_all.sh stack      -> test de pila
#   ./run_all.sh all        -> test completo
#   ./run_all.sh clean      -> limpiar
# ============================================================

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

MODE="${1:-interactive}"

if [ "$MODE" = "clean" ]; then
    echo "Limpiando..."
    make clean
    pkill -f qemu-system-aarch64 2>/dev/null || true
    rm -f /tmp/qemu_tp2.pid /tmp/qemu_tp2.log
    echo "OK"
    exit 0
fi

echo "=== Compilando ==="
pkill -f qemu-system-aarch64 2>/dev/null || true
sleep 0.5
make clean > /dev/null 2>&1 || true
make asm

if [ ! -f kernel.img ]; then
    echo "ERROR: kernel.img no se genero"
    exit 1
fi
echo "kernel.img: $(stat -c%s kernel.img) bytes"

echo "=== Lanzando QEMU ==="
qemu-system-aarch64 -s -S -machine virt -cpu cortex-a53 -machine type=virt -nographic -smp 1 -m 64 -kernel kernel.img > /tmp/qemu_tp2.log 2>&1 &
QEMU_PID=$!
echo "QEMU PID: $QEMU_PID"
sleep 1.5

if ! kill -0 $QEMU_PID 2>/dev/null; then
    echo "ERROR: QEMU se cerro"
    cat /tmp/qemu_tp2.log
    exit 1
fi
echo $QEMU_PID > /tmp/qemu_tp2.pid

cleanup() {
    if [ -f /tmp/qemu_tp2.pid ]; then
        QPID=$(cat /tmp/qemu_tp2.pid)
        kill $QPID 2>/dev/null || true
        rm -f /tmp/qemu_tp2.pid
    fi
    echo "QEMU detenido"
}
trap cleanup EXIT INT TERM

case "$MODE" in
    interactive)
        echo "=== Sesion interactiva con dashboard ==="
        gdb-multiarch -x debug.gdb
        ;;
    buffers)
        echo "=== Test de buffers ==="
        gdb-multiarch -x tests/test_buffers.gdb
        ;;
    thresholds)
        echo "=== Test de umbrales ==="
        gdb-multiarch -x tests/test_thresholds.gdb
        ;;
    events)
        echo "=== Test de eventos ==="
        gdb-multiarch -x tests/test_events.gdb
        ;;
    stack)
        echo "=== Test de pila ==="
        gdb-multiarch -x tests/test_stack.gdb
        ;;
    all)
        echo "=== Test completo ==="
        gdb-multiarch -x tests/test_all.gdb
        ;;
    *)
        echo "Modo desconocido: $MODE"
        echo "Modos validos: interactive, buffers, thresholds, events, stack, all, clean"
        exit 1
        ;;
esac

del serialout.txt
qemu-system-i386 -m 512 -no-reboot -serial file:serialout.txt hd.img 
REM -smp 4
type serialout.txt
del serialout.txt
qemu-system-i386 -m 1024 -no-reboot -serial file:serialout.txt -usbdevice disk:hd.img -smp 2
type serialout.txt
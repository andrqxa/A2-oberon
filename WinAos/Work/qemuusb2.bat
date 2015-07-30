del serialout.txt
qemu-system-i386 -m 1024 -drive if=none,id=stick,file=hd.img -usb -device usb-ehci,id=ehci -device usb-storage,bus=ehci.0,drive=stick -serial file:serialout.txt
type serialout.txt 
/* Minimal linker script for a Multiboot i386 kernel */
ENTRY(_start)

SECTIONS {
    /* Multiboot loads the kernel at 1MB */
    . = 1M;

    /* Multiboot header must be in the first 8KB of the binary */
    .multiboot ALIGN(4) : {
        KEEP(*(.multiboot))
    }

    .text ALIGN(4K) : {
        *(.text .text.*)
    }

    .rodata ALIGN(4K) : {
        *(.rodata .rodata.*)
    }

    .data ALIGN(4K) : {
        *(.data .data.*)
    }

    .bss ALIGN(4K) : {
        *(COMMON)
        *(.bss .bss.*)
    }
}

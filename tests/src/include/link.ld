OUTPUT_ARCH( "riscv" )
ENTRY( _start )
SECTIONS
{
  . = 0x00000000;
  .text : { *(.text.init) *(.text*) }
  . = 0x00001000;
  .data : { *(.data*) *(.rodata*) *(.sdata*) }
  .bss  : { *(.bss*) *(.sbss*) *(COMMON) }
  PROVIDE(_stack_top = 0x00003ff0);
  /DISCARD/ : { *(.comment) *(.riscv.attributes) *(.eh_frame) }
}

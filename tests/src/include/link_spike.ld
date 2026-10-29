OUTPUT_ARCH( "riscv" )
ENTRY( _start )
SECTIONS
{
  . = 0x00100000;
  .text : { *(.text.init) *(.text*) }
  . = 0x00101000;
  .data : { *(.data*) *(.rodata*) *(.sdata*) }
  .bss  : { *(.bss*) *(.sbss*) *(COMMON) }
  PROVIDE(_stack_top = 0x00103ff0);
  /DISCARD/ : { *(.comment) *(.riscv.attributes) *(.eh_frame) }
}

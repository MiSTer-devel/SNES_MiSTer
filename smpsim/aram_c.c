#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define SULV_U  (0) /* Uninitialized   */
#define SULV_X  (1) /* Forcing Unknown */
#define SULV_0  (2) /* Forcing 0       */
#define SULV_1  (3) /* Forcing 1       */
#define SULV_Z  (4) /* High Impedance  */
#define SULV_W  (5) /* Weak Unknown    */
#define SULV_L  (6) /* Weak 0          */
#define SULV_H  (7) /* Weak 1          */
#define SULV__  (8) /* Don't care      */

unsigned char chr[] = { 'U','X','0','1','Z','W','L','H','-' };

unsigned char *ram = NULL;
unsigned char *dsp_regram = NULL;
unsigned char spc_regram[7];

void load_ram(void) {
  printf ("load aram\n");
  FILE *f = fopen("snes.spc", "rb");
  if(!f) perror("fopen");

  fseek(f, 0x25, SEEK_SET);
  fread(&spc_regram, 7, 1, f);

  ram = malloc(65536);
  fseek(f, 0x100, SEEK_SET);
  fread(ram, 65536, 1, f);

  dsp_regram = malloc(128);
  fread(dsp_regram, 128, 1, f);

  fseek(f, 0x101c0, SEEK_SET);
  fread(&ram[0xffc0], 64, 1, f);

  fclose(f);
}

void aram_c(char clk, char we, char din[8], char addr[16], char dout[8], char spc_reg_addr[3], char spc_reg_dout[8], char smp_reg_addr[4], char smp_reg_dout[8], char dsp_reg_addr[7], char dsp_reg_dout[8]) {
  static char last_clk = 0;
  static unsigned int last_addr = 0xffff;

  if(!ram) load_ram();

  // only do something if clock changes
  if((clk == last_clk) && (clk != SULV_0)&&(clk != SULV_L)  )
    return;

  last_clk = clk;

  unsigned int i, a = 0;
  for(i=0;i<16;i++) {
    a <<= 1;
    if((addr[i] == SULV_1)||(addr[i] == SULV_H))
      a |= 1;
  }

  unsigned int din8 = 0;
  for(i=0;i<8;i++) {
    din8 <<= 1;
    if((din[i] == SULV_1)||(din[i] == SULV_H))
      din8 |= 1;
  }

  unsigned short d8 = ram[a];
  //  printf("ram(%04x) = $%02x\n", a, d8);

  if( (a != last_addr) && (((we == SULV_1) || (we == SULV_H)))) {
//    printf("RAM WR $%04x = $%02x (is $%02x)\n", a, din8, d8);
    ram[a] = din8;
  }
  
  for(i=0;i<8;i++)
    dout[i] = (d8 & (0x80>>i))?SULV_1:SULV_0;

  last_addr = a;


  // spc
  a=0;
  for(i=0;i<3;i++) {
    a <<= 1;
    if((spc_reg_addr[i] == SULV_1)||(spc_reg_addr[i] == SULV_H))
      a |= 1;
  }
  switch(a)
  {
    case 0: d8 = spc_regram[2]; break; // A
    case 1: d8 = spc_regram[3]; break; // X
    case 2: d8 = spc_regram[4]; break; // Y
    case 3: d8 = spc_regram[0]; break; // PC
    case 4: d8 = spc_regram[1]; break; // PC
    case 5: d8 = spc_regram[5]; break; // PSW
    case 6: d8 = spc_regram[6]; break; // SP
    default: d8 = 0;
  }

  for(i=0;i<8;i++)
    spc_reg_dout[i] = (d8 & (0x80>>i))?SULV_1:SULV_0;

  //dsp
  a=0;
  for(i=0;i<7;i++) {
    a <<= 1;
    if((dsp_reg_addr[i] == SULV_1)||(dsp_reg_addr[i] == SULV_H))
      a |= 1;
  }
  d8 = dsp_regram[a];

  for(i=0;i<8;i++)
    dsp_reg_dout[i] = (d8 & (0x80>>i))?SULV_1:SULV_0;

  // smp
  a=0;
  for(i=0;i<4;i++) {
    a <<= 1;
    if((smp_reg_addr[i] == SULV_1)||(smp_reg_addr[i] == SULV_H))
      a |= 1;
  }
  d8 = ram[0xf0+a];
  for(i=0;i<8;i++)
    smp_reg_dout[i] = (d8 & (0x80>>i))?SULV_1:SULV_0;

}


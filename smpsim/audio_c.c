//ffmpeg -f s16le -ar 32k -ac 2 -i snes.aud snes.wav

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

FILE *raw = NULL;

void audio_c(char clk, char rdy, char r[16], char l[16]) {
  static char last_clk = 0;
  static int ignore = 100;
  static int vskip = 1;
  static int cap_frames = -1;
  static int vdetect = 0;
  static int last_vs_time = -1;
  static int clk_cnt = 0;

  // only work on rising clock edge
  if(clk == last_clk) return;
  last_clk = clk;

  if((clk == SULV_0) || (clk == SULV_L)) return;

  //check for new data
  if((rdy == SULV_0) || (rdy == SULV_L)) return;

  unsigned int i;
  signed short ar = 0, al = 0;
  for(i=0;i<16;i++) {
    ar <<= 1; al <<= 1;
    if((r[i] == SULV_1)||(r[i] == SULV_H)) ar |= 1;
    if((l[i] == SULV_1)||(l[i] == SULV_H)) al |= 1;
  }

  if(!raw) {
      raw = fopen("snes.aud", "wb");
  }
  fwrite(&ar, sizeof(ar), 1, raw);
  fwrite(&al, sizeof(al), 1, raw);
}

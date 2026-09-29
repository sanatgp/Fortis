#include <string.h>
static float X[3240*61], Y[3240*148];
void fortis_pack(float* f, int col){ memcpy(X+(size_t)col*61, f, 61*4); }
void fortis_unpack(float* o, int col){ memcpy(o, Y+(size_t)col*148, 148*4); }
void mlp_forward_batched(void){}

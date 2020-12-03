#include "EXT.c"
#include<stdio.h>
#include<stdlib.h>

int main() {
    unsigned int INIT, ACCEPT, EpsBEG, EpsEND ,EpsBLK;
    unsigned int SELFLOOP[256], MASK[256];

    char *PATTERN;
    int size = 200;
    PATTERN = (char*) malloc(size);
    gets(PATTERN);

    int ret_code = parseEXT(PATTERN, &INIT, &ACCEPT, &EpsBEG, &EpsEND, &EpsBLK, MASK, SELFLOOP);
    if(ret_code) {
        printf("Valid EXT Pattern\n");
        printf("INIT : %x \n",INIT);
        printf("ACCEPT : %x \n",ACCEPT);
        printf("EpsBEG : %x \n",EpsBEG);
        printf("EpsEND : %x \n",EpsEND);
        printf("EpsBLK : %x \n",EpsBLK);
        printf("MASK[A] : %x \n",MASK['A']);
        printf("MASK[B] : %x \n",MASK['B']);
        printf("MASK[C] : %x \n",MASK['C']);
        printf("SELFLOOP[A] : %x \n",SELFLOOP['A']);
        printf("SELFLOOP[B] : %x \n",SELFLOOP['B']);
        printf("SELFLOOP[C] : %x \n",SELFLOOP['C']);
    }
    else printf("Invalid EXT Pattern\n");

    return 0;
}
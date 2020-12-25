#include "./EXT_Parser/EXT.c"
#include "./STDOUT/outbyte.c"

/*
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
*/

int main() {

    char* patterns[4] = ["abc+","[abc]{0,2}d[e,f]?","\0","[a-zA-Z][0-9]hello"];
    char* pattern2 = "computers?";

    PreProcessAll(patterns);
    PreProcess(pattern2, 2);

    char* text[4] = {"abbadfcabcc","dafabdef","computterscomputer","cc00G9hello0hell"};
    int index[4] = {0,0,0,0};
    while(1) {
        int OK = (1<<4)-1;
        char text_chars[4];
        for(int i = 0; i < 4; i++) {
            if(text[i][index[i]] == '\0') OK ^= (1<<i);
            else {
               text_chars[i] = text[i][index[i]];
               index[i]++; 
            }
        }
        if(!OK) break;

        unsigned int pattern_status = SimulateNFA_All(text_chars);
        for(int i = 0; i < 4; i++) {
            if(pattern_status & (1<<i))  {
                myputs("Text : ");
                myputs(text[i]);
                myputs(" - Matched Pattern : ");
                if(i == 2) myputs(pattern2);
                else muputs(patterns[i]);
                myputs(" @ ");
                myputs(index[i]);
                switch(index[i]) {
                    case 1 : 
                        myputs("st");
                    break;
                    case 2 :
                        myputs("nd");
                    break;
                    case 3 :
                        myputs("rd");
                    break;
                    default ;
                        myputs("th");
                    break;
                }
                myputs(" character\n");
            }
        }
    }

    pattern_status = SimulateNFA('o', 3);
    if(pattern_status)  {
        myputs("Text : ");
        myputs(text[3]);
        myputs(" - Matched Pattern : ");
        muputs(patterns[3]);
        myputs("o");
        myputs(" @ ");
        myputs(index[3]);
        switch(index[3]) {
            case 1 : 
                myputs("st");
            break;
            case 2 :
                myputs("nd");
            break;
            case 3 :
                myputs("rd");
            break;
            default ;
                myputs("th");
            break;
        }
        myputs(" character\n");
        index[3]++;
    }

    resetNFA(2);
    pattern_status = SimulateNFA('s', 2);
    if(pattern_status)  {
        myputs("Text : ");
        myputs(text[2]);
        myputs(" - Matched Pattern : ");
        muputs(pattern2);
        myputs("s");
        myputs(" @ ");
        myputs(index[2]);
        switch(index[2]) {
            case 1 : 
                myputs("st");
            break;
            case 2 :
                myputs("nd");
            break;
            case 3 :
                myputs("rd");
            break;
            default ;
                myputs("th");
            break;
        }
        myputs(" character\n");
        index[2]++;
    }


    // Infinite loop to avoid repitition of program
    for(;;);

}
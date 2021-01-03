#include "./Pattern_Matching/PM_Utility.c"
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

    myputs("Hello world");

    char* patterns[4] = {"abc+","[abc]{0,3}d[e,f]?","\0","[a-zA-Z][0-9]hello"};
    char* pattern2 = "computers?";

    PreProcessAll_M0(patterns);
    PreProcess(pattern2, 2);

    // Parallel independent text matching
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

        // Checking SimulateNFA_ALL_M0
        unsigned int pattern_status = SimulateNFA_All_M0(text_chars);
        for(int i = 0; i < 4; i++) {
            if(pattern_status & (1<<i))  {
                myputs("Text : \n");
                myputs(text[i]);
                myputs("\n--- Matched Pattern : \n");
                if(i == 2) myputs(pattern2);
                else myputs(patterns[i]);
                myputs("\n@ ");
                myputs(convert(index[i], 10));
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
                    default :
                        myputs("th");
                    break;
                }
                myputs(" character\n\n");
            }
        }
    }

    // Checking SimulateNFA
    unsigned int pattern_status = SimulateNFA('o', 3);
    if(pattern_status)  {
        myputs("Text : \n");
        myputs(text[3]);
        myputs("\n--- Matched Pattern : \n");
        myputs(patterns[3]);
        myputs("o");
        myputs("\n@ ");
        myputs(convert(index[3], 10));
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
            default :
                myputs("th");
            break;
        }
        myputs(" character\n\n");
        index[3]++;
    }

    // Checking ResetNFA
    ResetNFA(2);
    pattern_status = SimulateNFA('s', 2);
    if(pattern_status)  {
        myputs("Text : \n");
        myputs(text[2]);
        myputs("\n--- Matched Pattern : \n");
        myputs(pattern2);
        myputs("s");
        myputs("\n@ ");
        myputs(convert(index[2], 10));
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
            default :
                myputs("th");
            break;
        }
        myputs(" character\n\n");
        index[2]++;
    }

    // Single text - parallel pattern matching

    // Checking ResetNFA_All_M1
    ResetNFA_All_M1();
    // We use the same patterns in the 4 modules as setup earlier, but now try to simulate all NFAs with single text
    char *new_text = "abcdefghijklmnopqrtuvwxyz";
    for(int i = 0; new_text[i]; i++) {
        pattern_status = SimulateNFA_All_M1(new_text[i]);
        if(pattern_status)  {
            myputs("Text : \n");
            myputs(new_text);
            myputs("\n--- Matched Pattern(s) : \n");
            for(int j = 0; j < 4; j++) {
                if(pattern_status & (1<<j)) {
                    if(j == 2) {myputs(pattern2); myputs("\n");}
                    else {myputs(patterns[j]); myputs("\n");}
                }
            }
            myputs("@ ");
            myputs(convert(i+1, 10));
            switch(i+1) {
                case 1 : 
                    myputs("st");
                break;
                case 2 :
                    myputs("nd");
                break;
                case 3 :
                    myputs("rd");
                break;
                default :
                    myputs("th");
                break;
            }
            myputs(" character\n\n");
        }
    }


    // Infinite loop to avoid repitition of program
    for(;;);

}
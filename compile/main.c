#include "./Pattern_Matching/PM_Utility.c"
#include "./STDOUT/outbyte.c"

int main() {

    char* patterns[4] = {"abc+","[abc]{0,3}d[e,f]?","\0","[a-zA-Z][0-9]hello"};
    char* pattern2 = "ab?[cd]*";

    PreProcessAll_M0(patterns);
    PreProcess(pattern2, 2);

    // Pattern Matching in a single module
    myputs("SINGLE TEXT - SINGLE COMPLEX PATTERN MATCHING\n\n");
    int pattern_status = SimulateNFA('a', 2);
    if(pattern_status) {
        myputs("Text : \n");
        myputs("a");
        myputs("\n--- Matched Pattern : \n");
        myputs(pattern2);
        myputs("\n@ ");
        myputs(convert(1, 10));
        myputs("st character\n\n");
    }

    myputs("--------------------------------------------------\n");
    
    // Single text - parallel pattern matching
    // We use the same patterns in the 4 modules as setup earlier, but now try to simulate all NFAs with single text
    char *new_text = "abcdefghijklmnopqrtuvwxyz";
    myputs("SINGLE TEXT - MULTIPLE COMPLEX PATTERNS MATCHING\n\n");
    myputs("Text : \n");
    myputs(new_text);
    for(int i = 0; new_text[i]; i++) {
        pattern_status = SimulateNFA_All_M1(new_text[i]);
        if(pattern_status)  {
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
#define W 32

/*
    The function parses the EXT pattern given and generates the preprocessed data needed by the Pattern Matching Peripheral.
    The data needed to simulate NFA in the peripheral include :
        INIT - bitmask (of length atmost W bits) which indicates one left shift of starting state of the NFA
        ACCEPT - bitmask (of length atmost W bits) which indicates accepting state of the NFA
        MOVE[0 ... 255] - (each length atmost W bits) MOVE[c][i] = 1 indicates transition from (i-1) to i th state of NFA using character c
        SELFLOOP[0 ... 255] - (each length atmost W bits) SELFLOOP[c][i] = 1 indicates self loop at i th state of NFA using character c
        EpsBEG - bitmask (of length atmost W bits) which sets high the starting position of an epsilon transition block
        EpsEND - bitmask (of length atmost W bits) which sets high the ending position of an epsilon transition block
        EpsBLK - bitmask (of length atmost W bits) which sets high all positions an epsilon transition can lead to

    The function returns takes as arguments :
        PATTERN (char *) - a string representing the pattern in regex notation
        pointer to INIT (int / long long) - 32 / 64 bit number
        pointer to oACCEPT (int / long long) - 32 / 64 bit number
        pointer to EpsBEG (int / long long) - 32 / 64 bit number
        pointer to EpsEND (int / long long) - 32 / 64 bit number
        pointer to EpsBLK (int / long long) - 32 / 64 bit number
        MOVE[] (int[256] / long long[256]) - array of 32 / 64 bit numbers
        SELFLOOP[] (int[256] / long long[256]) - array of 32 / 64 bit numbers
    
    The function returns :
        0 if given pattern not a valid EXT type regex or if the pattern results in a NFA with greater than W length, 1 otherwise
*/

int parseEXT (char *PATTERN, unsigned int *INIT, unsigned int *ACCEPT, unsigned int *EpsBEG, unsigned int *EpsEND, unsigned int *EpsBLK, unsigned int MOVE[], unsigned int SELFLOOP[]) {
    
    *INIT = 1;
    *ACCEPT = (1<<(W-1));
    *EpsBEG = *EpsEND = *EpsBLK = 0;
    for(int i = 0;i < 256;i++) {
        MOVE[i] = 0;
        SELFLOOP[i] = 0;
    }

    // escape : 1 if a backslash (\) is encountered which denotes a escape sequence
    // range : 1 if a hiphen (-) is encountered which denotes a range
    // char_class : 1 if we are decoding the character class from the regex provided
    // negate : 1 if ^ is encountered in character class when characters other than those given must be included
    int escape = 0,range = 0,char_class = 1,negate = 0;

    // state_no : deontes the number of states in the NFA minus 1
    int state_no = -1;

    // char_set : sets the characters provided in the character class HIGH
    int char_set[256] = {0};

    for(int i = 0; !char_class || PATTERN[i] != '\0'; i++) {
        if(!char_class) {
            
            state_no++;
            int tmpMask = (1<<state_no);

            if(PATTERN[i] == '+') {
                for(int c = 0;c < 256;c++) {
                    if(negate ^ char_set[c]) MOVE[c] |= tmpMask;
                }
                for(int c = 0;c < 256;c++) {
                    if(negate ^ char_set[c]) SELFLOOP[c] |= tmpMask;
                }
            }
            else if(PATTERN[i] == '?') {
                for(int c = 0;c < 256;c++) {
                    if(negate ^ char_set[c]) MOVE[c] |= tmpMask;
                }
                (*EpsBLK) |= tmpMask;
            }
            else if(PATTERN[i] == '*') {
                for(int c = 0;c < 256;c++) {
                    if(negate ^ char_set[c]) MOVE[c] |= tmpMask;
                }
                for(int c = 0;c < 256;c++) {
                    if(negate ^ char_set[c]) SELFLOOP[c] |= tmpMask;
                }
                (*EpsBLK) |= tmpMask;
            }
            else if(PATTERN[i] == '{') {
                int lb = 0, ub = 0;
                i++;
                while(PATTERN[i] >= '0' && PATTERN[i] <= '9') {
                    lb = lb*10 + (PATTERN[i]-'0');
                    i++;
                }
                if(PATTERN[i] != ',') return 0;
                i++;
                while(PATTERN[i] >= '0' && PATTERN[i] <= '9') {
                    ub = ub*10 + (PATTERN[i]-'0');
                    i++;
                }
                if(PATTERN[i] != '}' || ub < lb || state_no+ub > W) return 0;
                state_no += (ub-1);
                int x = ub-lb, j = 0;
                for(;j < x;j++) {
                    (*EpsBLK) |= tmpMask;
                    for(int c = 0;c < 256;c++) {
                        if(negate ^ char_set[c]) MOVE[c] |= tmpMask;
                    }
                    tmpMask <<= 1;
                }
                for(;j < ub;j++) {
                    for(int c = 0;c < 256;c++) {
                        if(negate ^ char_set[c]) MOVE[c] |= tmpMask;
                    }
                    tmpMask <<= 1;
                }
            }
            else {
                for(int c = 0;c < 256;c++) {
                    if(negate ^ char_set[c]) MOVE[c] |= tmpMask;
                }
                if(PATTERN[i] != '\0') i--;
            }

            if(state_no >= W) return 0;

            char_class = 1;

            // printf("LENGTH : %d and POS : %d and CHARACTER : %c \n",state_no,i,PATTERN[i]);
        }

        else {

            // Resetting all info to process next character class separately
            for(int c = 0;c < 256;c++) char_set[c] = 0;
            negate = 0;
            escape = 0;
            range = 0;

            if(PATTERN[i] == '[') {
                i++;
                int st = i;
                while(PATTERN[i] != '\0') {
                    if(escape) {
                        switch(PATTERN[i]) {
                            case 'n' :
                                char_set['\n'] = 1;     // new line
                            break;
                            case 'r' :
                                char_set['\r'] = 1;     // carriage return 
                            break;
                            case 'v' :
                                char_set['\v'] = 1;     // vertical tab
                            break;
                            case 'a' :
                                char_set['\a'] = 1;     // alert bell
                            break;
                            case 'b' :
                                char_set['\b'] = 1;     // backspace
                            break;
                            case 't' :
                                char_set['\t'] = 1;     // horizontal tab
                            break;
                            case 'f' :
                                char_set['\f'] = 1;     // form feed
                            break;
                            case '0' :  
                                char_set['\0'] = 1;     // null
                            break;
                            case 's' :  
                                char_set[' '] = 1;      // single whitespace
                            break;
                            case '\\' :
                                char_set['\\'] = 1;     // backslash
                            break;
                            default :
                                char_set[PATTERN[i]] = 1;
                            break;
                        }
                        escape = 0;
                    }
                    else if(range) {
                        if(PATTERN[i] < PATTERN[i-2]) {
                            return 0;
                        }
                        for(int c = PATTERN[i-2];c <= PATTERN[i];c++) char_set[c] = 1;
                        range = 0;
                    }
                    else if(PATTERN[i] == '\\') escape = 1;
                    else if(PATTERN[i] == '-') {
                        if(i == st || (i == st+1 && negate) || PATTERN[i+1] == ']') char_set['-'] = 1;
                        else range = 1;
                    }
                    else if(i == st && PATTERN[i] == '^') negate = 1;
                    else if(PATTERN[i] == ']') {
                        if(i == st+1 && negate) char_set[']'] = 1;
                        else break;
                    }
                    else char_set[PATTERN[i]] = 1;
                    i++;
                }
                if(PATTERN[i] == '\0') return 0;
            }
            else if(PATTERN[i] == '\\') {
                i++;
                switch(PATTERN[i]) {
                    case 'n' :
                        char_set['\n'] = 1;
                    break;
                    case 'r' :
                        char_set['\r'] = 1;
                    break;
                    case 'v' :
                        char_set['\v'] = 1;
                    break;
                    case 'a' :
                        char_set['\a'] = 1;
                    break;
                    case 'b' :
                        char_set['\b'] = 1;
                    break;
                    case 't' :
                        char_set['\t'] = 1;
                    break;
                    case 'f' :
                        char_set['\f'] = 1;
                    break;
                    case '0' :
                        char_set['\0'] = 1;
                    break;
                    case 's' :  
                        char_set[' '] = 1;
                    break;
                    case '\\' :
                        char_set['\\'] = 1;
                    break;
                    default :
                        char_set[PATTERN[i]] = 1;
                    break;
                }
            }
            else char_set[PATTERN[i]] = 1;

            char_class = 0;

        }

    }

    *ACCEPT = (1<<state_no);

    for(int i = 0;i < W-1;i++) {
        int tmpMask = (1<<i);
        int pres_bit = ( ((*EpsBLK) & tmpMask) != 0 ), nxt_bit = ( ((*EpsBLK) & (tmpMask<<1)) != 0);
        if(!pres_bit && nxt_bit) (*EpsBEG) |= tmpMask;
        else if(pres_bit && !nxt_bit) (*EpsEND) |= tmpMask;
    }
    if((*EpsBLK) & (1<<(W-1))) (*EpsEND) |= (1<<(W-1));

    return 1;
}

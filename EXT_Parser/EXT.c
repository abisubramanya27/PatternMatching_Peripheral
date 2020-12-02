#define W 32
/*
    The function parses the EXT pattern given and generates the preprocessed data needed by the Pattern Matching Peripheral.
    The data needed to simulate NFA in the peripheral include :
        INIT - bitmask (of length atmost W bits) which indicates starting state of the NFA
        ACCEPT - bitmask (of length atmost W bits) which indicates accepting state of the NFA
        MASK[0 ... 255] - (each length atmost W bits) MASK[c][i] = 1 indicates transition from (i-1) to i th state of NFA using character c
        SELFLOOP[0 ... 255] - (each length atmost W bits) SELFLOOP[c][i] = 1 indicates self loop at i th state of NNFA using character c

    The function returns takes as arguments :
        PATTERN (char *) - a string representing the pattern in regex notation
        INIT (int / long long) - 32 / 64 bit number
        ACCEPT (int / long long) - 32 / 64 bit number
        MASK[] (int[256] / long long[256]) - array of 32 / 64 bit numbers
        SELFLOOP[] (int[256] / long long[256]) - array of 32 / 64 bit numbers
    
    The function returns :
        STATUS - 0 if not a valid EXT type regex, 1 otherwise
*/


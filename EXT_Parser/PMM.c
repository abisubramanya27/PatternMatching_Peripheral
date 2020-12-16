#include "EXT.c"

#define PMM_WRITE_LS32B_OFFSET 0x10000
#define PMM_WRITE_MS32B_OFFSET 0x10004
#define PMM_WRITE_CONTROL_OFFSET 0x10008
#define PMM_READ_DATA_ACCEPTED_OFFSET 0x1000C
#define PMM_READ_PATTERN_ACCEPTED_OFFSET 0x1000C
#define NO_MODULES 4

// Function to write data to Data Buffer (64 bits) in Peripheral Interface. LSB = 1 denotes lower 32 bits, LSB = 0 denotes higher 32 bits
void Input1_2(int data, int LSB = 1) {
    int *p = (LSB) ? (int*)PMM_WRITE_LS32B_OFFSET : (int*)PMM_WRITE_MS32B_OFFSET;
    *p  = data;
}

// The above function overloaded to write long long data to Data Buffer as intended
void Input1_2(long long data) {
    int *p1 = int*)PMM_WRITE_LS32B_OFFSET, *p2 = (int*)PMM_WRITE_MS32B_OFFSET;
    int LS32B = data & ((1<<32)-1), MS32B = data>>32;
    *p1 = LS32B;
    *p2 = MS32B;
} 

// Function to pass control data to Periperal Interface
void Input3(int opcode, int address, int module_ID) {
    int *p = (int *)PMM_WRITE_CONTROL_OFFSET;
    *p = (opcode<<30) | (address<<16) | module_ID;
}

// Function to complete the handshaking with peripheral by waiting till DATA ACCEPTED signal is high, 
// and then sending a No Operation instrucion to make DATA VALID signal low and complete one operation
void Complete_Handshaking(unsigned int REQD_DATA_ACCEPTED) {
    int *p1 = (int *)PMM_READ_DATA_ACCEPTED_OFFSET;
    // Waiting till the operations are completed in the peripherals
    while((*p1) != REQD_DATA_ACCEPTED);

    int p2 = (int *)PMM_WRITE_CONTROL_OFFSET;
    // Sending a No operation to the necessary peripherals to conclude the handshaking 
    for(int i = 0; i < 4; i++) {
        if(REQD_DATA_ACCEPTED & (1<<i)) {
            *p2 = i;    // opcode = 00 -> No Operation ; Only MODULE_ID therefore has to be sent
        }
    }

    // Waiting for the No operation to be reflected by the peripheral
    while((*p1) != 0);
}


/* 
    Function to send preprocessing information to the modules in peripheral together and make use of parallel processing capability of peripheral.
    Arguments :
        patterns[4] - each is a char* string representing a pattern to be sent to the Ith module. "\0" represents empty pattern (i.e) Ith module need not be used
    Returns :
        An integer which is a bitmask, where Ith place being 1 implies that module was used, 
            0 implies either the module wasn't required or the provided pattern couldn't be processed
 */
int PreProcessAll(char *patterns[]) {

    unsigned int INIT[4], ACCEPT[4], EpsBEG[4], EpsEND[4] ,EpsBLK[4];
    unsigned int SELFLOOP[4][256], MOVE[4][256];

    unsigned int REQD_DATA_ACCEPTED = 0;

    for(int i = 0; i < NO_MODULES; i++) {
        if(patterns[i][0] != '\0') {
            int ret_code = parseEXT(patterns[i], &INIT[i], &ACCEPT[i], &EpsBEG[i], &EpsEND[i], &EpsBLK[i], MOVE[i], SELFLOOP[i]);
            if(ret_code) {
                REQD_DATA_ACCEPTED |= (1<<i);
            }
        }
    }

    // Writing EpsBEG to peripheral
    int opcode = 1, address = (1<<12);
    for(int i = 0; i < NO_MODULES; i++) {
        if(REQD_DATA_ACCEPTED & (1<<i)) {
            Input1_2(EpsBEG[i]);
            Input3(opcode, address, i);
        }
    }

    Complete_Handshaking(REQD_DATA_ACCEPTED);

    // Writing EpsBLK to peripheral
    opcode = 1, address = (1<<12) + 4;
    for(int i = 0; i < NO_MODULES; i++) {
        if(REQD_DATA_ACCEPTED & (1<<i)) {
            Input1_2(EpsBLK[i]);
            int opcode = 1;
            int address = (1<<12) + 4;
            Input3(opcode, address, i);
        }
    }

    // Writing EpsEND to peripheral
    opcode = 1, address = (1<<12) + 8;
    for(int i = 0; i < NO_MODULES; i++) {
        if(REQD_DATA_ACCEPTED & (1<<i)) {
            Input1_2(EpsEND[i]);
            Input3(opcode, address, i);
        }
    }

    Complete_Handshaking(REQD_DATA_ACCEPTED);

    // Writing INIT to peripheral
    opcode = 1, address = (1<<12) + 12;
    for(int i = 0; i < NO_MODULES; i++) {
        if(REQD_DATA_ACCEPTED & (1<<i)) {
            Input1_2(INIT[i]);
            Input3(opcode, address, i);
        }
    }

    Complete_Handshaking(REQD_DATA_ACCEPTED);

    // Writing ACCEPT to peripheral
    opcode = 1, address = (1<<12) + 16;
    for(int i = 0; i < NO_MODULES; i++) {
        if(REQD_DATA_ACCEPTED & (1<<i)) {
            Input1_2(ACCEPT[i]);
            Input3(opcode, address, i);
        }
    }

    Complete_Handshaking(REQD_DATA_ACCEPTED);

    // Writing SELFLOOP to peripheral
    opcode = 1;
    for(int j = 0; j < 256; j++) {

        address = (j<<2);
        for(int i = 0; i < 4; i++) {
            if(REQD_DATA_ACCEPTED & (1<<i)) {
                Input1_2(SELFLOOP[i][j]);
                Input3(opcode, address, i);
            }
        }

        Complete_Handshaking(REQD_DATA_ACCEPTED);

    }

    // Writing MOVE to peripheral
    opcode = 1;
    for(int j = 0; j < 256; j++) {

        address = (1<<11) + (j<<2);
        for(int i = 0; i < 4; i++) {
            if(REQD_DATA_ACCEPTED & (1<<i)) {
                Input1_2(MOVE[i][j]);
                Input3(opcode, address, i);
            }
        }

        Complete_Handshaking(REQD_DATA_ACCEPTED);

    }

    return REQD_DATA_ACCEPTED;
    
}

/*
    Function to send preprocessing information to a specific module in the peripheral
*/
int PreProcess(char *pattern, int module) {

    unsigned int INIT, ACCEPT, EpsBEG, EpsEND ,EpsBLK;
    unsigned int SELFLOOP[256], MOVE[256];

    int OK = 0;
    if(pattern[0] != '\0') {
        int ret_code = parseEXT(pattern, &INIT, &ACCEPT, &EpsBEG, &EpsEND, &EpsBLK, MOVE, SELFLOOP);
        if(ret_code) {
            OK = 1;
        }
    }

    // Writing EpsBEG to peripheral
    int opcode = 1, address = (1<<12);
    if(OK) {
        Input1_2(EpsBEG);
        Input3(opcode, address, module);
    }

    Complete_Handshaking(OK<<module);

    // Writing EpsBLK to peripheral
    opcode = 1, address = (1<<12) + 4;
    for(int i = 0; i < NO_MODULES; i++) {
        if(REQD_DATA_ACCEPTED & (1<<i)) {
            Input1_2(EpsBLK[i]);
            int opcode = 1;
            int address = (1<<12) + 4;
            Input3(opcode, address, i);
        }
    }

    // Writing EpsEND to peripheral
    opcode = 1, address = (1<<12) + 8;
    for(int i = 0; i < NO_MODULES; i++) {
        if(REQD_DATA_ACCEPTED & (1<<i)) {
            Input1_2(EpsEND[i]);
            Input3(opcode, address, i);
        }
    }

    Complete_Handshaking(OK<<module);

    // Writing INIT to peripheral
    opcode = 1, address = (1<<12) + 12;
    for(int i = 0; i < NO_MODULES; i++) {
        if(REQD_DATA_ACCEPTED & (1<<i)) {
            Input1_2(INIT[i]);
            Input3(opcode, address, i);
        }
    }

    Complete_Handshaking(REQD_DATA_ACCEPTED);

    // Writing ACCEPT to peripheral
    opcode = 1, address = (1<<12) + 16;
    for(int i = 0; i < NO_MODULES; i++) {
        if(REQD_DATA_ACCEPTED & (1<<i)) {
            Input1_2(ACCEPT[i]);
            Input3(opcode, address, i);
        }
    }

    Complete_Handshaking(REQD_DATA_ACCEPTED);

    // Writing SELFLOOP to peripheral
    opcode = 1;
    for(int j = 0; j < 256; j++) {

        address = (j<<2);
        for(int i = 0; i < 4; i++) {
            if(REQD_DATA_ACCEPTED & (1<<i)) {
                Input1_2(SELFLOOP[i][j]);
                Input3(opcode, address, i);
            }
        }

        Complete_Handshaking(REQD_DATA_ACCEPTED);

    }

    // Writing MOVE to peripheral
    opcode = 1;
    for(int j = 0; j < 256; j++) {

        address = (1<<11) + (j<<2);
        for(int i = 0; i < 4; i++) {
            if(REQD_DATA_ACCEPTED & (1<<i)) {
                Input1_2(MOVE[i][j]);
                Input3(opcode, address, i);
            }
        }

        Complete_Handshaking(REQD_DATA_ACCEPTED);

    }

    return REQD_DATA_ACCEPTED;

}


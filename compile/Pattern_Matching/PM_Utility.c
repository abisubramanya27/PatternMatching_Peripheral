#include "./EXT_Parser.c"

#define PMP_INTERFACE_BASE 0x400000
#define PMP_WRITE_LS32B_OFFSET 0x00
#define PMP_WRITE_MS32B_OFFSET 0x04
#define PMP_WRITE_CONTROL_OFFSET 0x08
#define PMP_READ_DATA_ACCEPTED_OFFSET 0x0C
#define PMP_READ_PATTERN_ACCEPTED_OFFSET 0x10
#define NO_MODULES 4

// Function to write data to Data Buffer (64 bits) in Peripheral Interface. LSB = 1 denotes lower 32 bits, LSB = 0 denotes higher 32 bits
void Input1_2(unsigned int data, int LSB) {
    int *p = (LSB) ? (int*)(PMP_INTERFACE_BASE + PMP_WRITE_LS32B_OFFSET) : (int*)(PMP_INTERFACE_BASE + PMP_WRITE_MS32B_OFFSET);
    *p  = data;
}

// The above function overloaded to write long long data to Data Buffer as intended
void Input1_2LL(long long data) {
    int *p1 = (int*)(PMP_INTERFACE_BASE + PMP_WRITE_LS32B_OFFSET), *p2 = (int*)(PMP_INTERFACE_BASE + PMP_WRITE_MS32B_OFFSET);
    unsigned int LS32B = data & 0xFFFFFFFF, MS32B = data>>32;
    *p1 = LS32B;
    *p2 = MS32B;
} 

// Function to pass control data to Periperal Interface
void Input3(int opcode, int address, int module_ID) {
    int *p = (int *)(PMP_INTERFACE_BASE + PMP_WRITE_CONTROL_OFFSET);
    *p = (opcode<<30) | (address<<16) | module_ID;
}

// Function to complete the handshaking with peripheral by waiting till DATA ACCEPTED signal is high, 
// and then sending a No Operation instrucion to make DATA VALID signal low and complete one operation.
// Returns - the PATTERN_ACCEPTED status
unsigned int Complete_Handshaking(unsigned int REQD_DATA_ACCEPTED) {
    int *p1 = (int *)(PMP_INTERFACE_BASE + PMP_READ_DATA_ACCEPTED_OFFSET);
    // Waiting till the operations are completed in the modules (under operation)
    while( ((*p1) & REQD_DATA_ACCEPTED) != REQD_DATA_ACCEPTED );

    int *p = (int *)(PMP_INTERFACE_BASE + PMP_READ_PATTERN_ACCEPTED_OFFSET);
    unsigned int PATTERN_ACCEPTED_STATUS = (*p);

    int *p2 = (int *)(PMP_INTERFACE_BASE + PMP_WRITE_CONTROL_OFFSET);
    // Sending a No operation to the necessary modules to conclude the handshaking 
    for(int i = 0; i < NO_MODULES; i++) {
        if(REQD_DATA_ACCEPTED & (1<<i)) {
            *p2 = i;    // opcode = 00 -> No Operation ; Only MODULE_ID therefore has to be sent
        }
    }

    // Waiting for the No operation to be reflected in the modules (under operation)
    while( ((*p1) & REQD_DATA_ACCEPTED) != 0 );

    return PATTERN_ACCEPTED_STATUS;
}


/* 
    Function to send preprocessing information to the modules in peripheral together and make use of parallel processing capability of peripheral.
    Arguments :
        patterns[4] - each is a char* string, Ith string is the pattern to be sent to the Ith module. "\0" represents empty pattern (i.e) Ith module need not be used
    Returns :
        An integer which is a bitmask, where Ith place being 1 implies that module was used, 
                                                             0 implies either the module wasn't required or the provided pattern couldn't be processed
 */
int PreProcessAll(char *patterns[NO_MODULES]) {

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

    // opcode = 1 : Input for preprocessing
    // Writing EpsBEG to peripheral
    int opcode = 1, address = (1<<12);
    for(int i = 0; i < NO_MODULES; i++) {
        if(REQD_DATA_ACCEPTED & (1<<i)) {
            Input1_2(EpsBEG[i], 1);
            Input3(opcode, address, i);
        }
    }

    Complete_Handshaking(REQD_DATA_ACCEPTED);

    // Writing EpsBLK to peripheral
    opcode = 1, address = (1<<12) + 4;
    for(int i = 0; i < NO_MODULES; i++) {
        if(REQD_DATA_ACCEPTED & (1<<i)) {
            Input1_2(EpsBLK[i], 1);
            Input3(opcode, address, i);
        }
    }

    // Writing EpsEND to peripheral
    opcode = 1, address = (1<<12) + 8;
    for(int i = 0; i < NO_MODULES; i++) {
        if(REQD_DATA_ACCEPTED & (1<<i)) {
            Input1_2(EpsEND[i], 1);
            Input3(opcode, address, i);
        }
    }

    Complete_Handshaking(REQD_DATA_ACCEPTED);

    // Writing INIT to peripheral
    opcode = 1, address = (1<<12) + 12;
    for(int i = 0; i < NO_MODULES; i++) {
        if(REQD_DATA_ACCEPTED & (1<<i)) {
            Input1_2(INIT[i], 1);
            Input3(opcode, address, i);
        }
    }

    Complete_Handshaking(REQD_DATA_ACCEPTED);

    // Writing ACCEPT to peripheral
    opcode = 1, address = (1<<12) + 16;
    for(int i = 0; i < NO_MODULES; i++) {
        if(REQD_DATA_ACCEPTED & (1<<i)) {
            Input1_2(ACCEPT[i], 1);
            Input3(opcode, address, i);
        }
    }

    Complete_Handshaking(REQD_DATA_ACCEPTED);

    // Writing SELFLOOP to peripheral
    opcode = 1;
    for(int j = 0; j < 256; j++) {

        address = (j<<2);
        for(int i = 0; i < NO_MODULES; i++) {
            if(REQD_DATA_ACCEPTED & (1<<i)) {
                Input1_2(SELFLOOP[i][j], 1);
                Input3(opcode, address, i);
            }
        }

        Complete_Handshaking(REQD_DATA_ACCEPTED);

    }

    // Writing MOVE to peripheral
    opcode = 1;
    for(int j = 0; j < 256; j++) {

        address = (1<<11) + (j<<2);
        for(int i = 0; i < NO_MODULES; i++) {
            if(REQD_DATA_ACCEPTED & (1<<i)) {
                Input1_2(MOVE[i][j], 1);
                Input3(opcode, address, i);
            }
        }

        Complete_Handshaking(REQD_DATA_ACCEPTED);

    }

    return REQD_DATA_ACCEPTED;
    
}


/*
    Function to send preprocessing information to a specific module in the peripheral
    Arguments :
        pattern - char* string representing a pattern to be sent to the Ith module. "\0" represents empty pattern (i.e) module need not be used
        module - integer representing the module number to be targetted
    Returns :
        An integer - 1 implies that module was used, 
                     0 implies either the module wasn't required or the provided pattern couldn't be processed
*/
int PreProcess(char *pattern, int module) {

    unsigned int INIT, ACCEPT, EpsBEG, EpsEND ,EpsBLK;
    unsigned int SELFLOOP[256], MOVE[256];

    if(pattern[0] == '\0') return 0;
    int ret_code = parseEXT(pattern, &INIT, &ACCEPT, &EpsBEG, &EpsEND, &EpsBLK, MOVE, SELFLOOP);
    if(!ret_code) return 0;

    // opcode = 1 : Input for preprocessing
    // Writing EpsBEG to peripheral
    int opcode = 1, address = (1<<12);
    Input1_2(EpsBEG, 1);
    Input3(opcode, address, module);

    Complete_Handshaking(1<<module);

    // Writing EpsBLK to peripheral
    opcode = 1, address = (1<<12) + 4;
    Input1_2(EpsBLK, 1);
    Input3(opcode, address, module);

    // Writing EpsEND to peripheral
    opcode = 1, address = (1<<12) + 8;
    Input1_2(EpsEND, 1);
    Input3(opcode, address, module);

    Complete_Handshaking(1<<module);

    // Writing INIT to peripheral
    opcode = 1, address = (1<<12) + 12;
    Input1_2(INIT, 1);
    Input3(opcode, address, module);

    Complete_Handshaking(1<<module);

    // Writing ACCEPT to peripheral
    opcode = 1, address = (1<<12) + 16;
    Input1_2(ACCEPT, 1);
    Input3(opcode, address, module);

    Complete_Handshaking(1<<module);

    // Writing SELFLOOP to peripheral
    opcode = 1;
    for(int j = 0; j < 256; j++) {

        address = (j<<3);
        Input1_2(SELFLOOP[j], 1);
        Input3(opcode, address, module);

        Complete_Handshaking(1<<module);

    }

    // Writing MOVE to peripheral
    opcode = 1;
    for(int j = 0; j < 256; j++) {

        address = (1<<11) + (j<<3);
        Input1_2(MOVE[j], 1);
        Input3(opcode, address, module);

        Complete_Handshaking(1<<module);

    }

    return 1;

}


/*
    Function to simulate Non-deterministic Finite Automaton in necessary modules of the peripheral parallely without waiting for one module to complete
    Arguments :
        text_char - char array where Ith character is the text character to be sent to the Ith module. "\0" represents empty pattern (i.e) Ith module need not be used
    Returns :
        An integer which is a bitmask, where Ith place being 1 implies the text (entered till now) has matched the pattern in that module, 
                                                             0 implies either the module didn't process anything, or the text hasn't matched the pattern yet
*/
int SimulateNFA_All(char text_chars[NO_MODULES]) {

    unsigned int TARGET_MODULES = 0;

    for(int i = 0; i < NO_MODULES; i++) {
        if(text_chars[i] != '\0') {
            TARGET_MODULES |= (1<<i);
            Input1_2((int)text_chars[i], 1);
            // opcode = 2 : Input for simulating NFA; address : dont care
            Input3(2, 0, i);
        }
    }

    unsigned int PATTERN_ACCEPTED_STATUS = Complete_Handshaking(TARGET_MODULES);

    return PATTERN_ACCEPTED_STATUS;

}


/*
    Function to simulate Non-deterministic Finite Automaton in the specified module of the peripheral
    Arguments :
        text_char - text character to be sent to the target module. "\0" represents empty pattern (i.e) module need not be used
        module - integer representing the module number to be targetted
    Returns :
        An integer - 1 implies the text (entered till now) has matched the pattern in the target module, 
                     0 implies either the module didn't process anything, or the text hasn't matched the pattern yet
*/
int SimulateNFA(char text_char, int module) {

    if(text_char == '\0') return 0;

    Input1_2((int)text_char, 1);
    // opcode = 2 : Input for simulating NFA; address : dont care
    Input3(2, 0, module);

    unsigned int PATTERN_ACCEPTED_STATUS = Complete_Handshaking((1<<module));

    return (PATTERN_ACCEPTED_STATUS & (1<<module)) != 0;

}


/*
    Function to reset the state of NFA in required modules parallely
    Arguments :
        bitmask - Ith position 1 represents Ith module has to be reset, 0 represents no change
*/
void ResetNFA_All(unsigned int bitmask) {

    for(int i = 0; i < NO_MODULES; i++) {
        if(bitmask & (1<<i)) {
            // opcode = 3 : Reset state instruction; address : dont care
            Input3(3, 0, i);
        }
    }

    Complete_Handshaking(bitmask);

}


/*
    Function to reset the state of NFA in target module
    Arguments :
        module - MODULE_ID of target module where state has to be reset
*/
void ResetNFA(int module) {

    // opcode = 3 : Reset state instruction; address : dont care
    Input3(3, 0, module);

    Complete_Handshaking((1<<module));

}

#include "./EXT_Parser.c"

#define PMP_INTERFACE_BASE 0x400000
#define PMP_WRITE_LS32B_OFFSET 0x00
#define PMP_WRITE_MS32B_OFFSET 0x04
#define PMP_WRITE_CONTROL_OFFSET 0x08
#define PMP_READ_DATA_ACCEPTED_OFFSET 0x0C
#define PMP_READ_PATTERN_ACCEPTED_OFFSET 0x10
#define NO_MODULES 4
#define SELFLOOP_ADDR_BASE 0
#define MOVE_ADDR_BASE 2048         // (1<<11)
#define EpsBEG_ADDR 4096            // (1<<12)
#define EpsBLK_ADDR 4104            // (1<<12) + 8
#define EpsEND_ADDR 4112            // (1<<12) + 16
#define INIT_ADDR 4120              // (1<<12) + 24
#define ACCEPT_ADDR 4128            // (1<<12) + 32

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
// Instruction Format -  MODE |  OPCODE  |   ADDRESS    |     TARGET_MODULE_ID
//                      1 bit |  2 bits  |   14 bits    |         15 bits
void Input3(int mode, int opcode, int address, int module_ID) {
    int *p = (int *)(PMP_INTERFACE_BASE + PMP_WRITE_CONTROL_OFFSET);
    *p = (mode<<31) | (opcode<<29) | (address<<15) | (module_ID & 0x7FFF);
}

// Function to complete the handshaking with peripheral by waiting till DATA ACCEPTED signal is high, 
// and then sending a No Operation instrucion to make DATA VALID signal low and complete one operation.
// Returns - the PATTERN_ACCEPTED status
unsigned int Complete_Handshaking(unsigned int REQD_DATA_ACCEPTED) {
    int *p1 = (int *)(PMP_INTERFACE_BASE + PMP_READ_DATA_ACCEPTED_OFFSET);
    // Waiting till the operations are completed in the modules (under operation)
    while( ((*p1) & 0xF) != REQD_DATA_ACCEPTED );

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
    Function to send different preprocessing information to the modules in the peripheral and make use of parallel processing capability of peripheral.
    (MODE 0)
    Arguments :
        patterns[4] - each is a char* string, Ith string is the pattern to be sent to the Ith module. "\0" represents empty pattern (i.e) Ith module need not be used
    Returns :
        An integer which is a bitmask, where Ith place being 1 implies that module was used, 
                                                             0 implies either the module wasn't required or the provided pattern couldn't be processed
 */
int PreProcessAll_M0(char *patterns[NO_MODULES]) {

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
    int opcode = 1, address = EpsBEG_ADDR;
    for(int i = 0; i < NO_MODULES; i++) {
        if(REQD_DATA_ACCEPTED & (1<<i)) {
            Input1_2(EpsBEG[i], 1);
            Input3(0, opcode, address, i);      // Mode = 0
        }
    }

    Complete_Handshaking(REQD_DATA_ACCEPTED);

    // Writing EpsBLK to peripheral
    opcode = 1, address = EpsBLK_ADDR;
    for(int i = 0; i < NO_MODULES; i++) {
        if(REQD_DATA_ACCEPTED & (1<<i)) {
            Input1_2(EpsBLK[i], 1);
            Input3(0, opcode, address, i);      // Mode = 0
        }
    }

    Complete_Handshaking(REQD_DATA_ACCEPTED);

    // Writing EpsEND to peripheral
    opcode = 1, address = EpsEND_ADDR;
    for(int i = 0; i < NO_MODULES; i++) {
        if(REQD_DATA_ACCEPTED & (1<<i)) {
            Input1_2(EpsEND[i], 1);
            Input3(0, opcode, address, i);      // Mode = 0
        }
    }

    Complete_Handshaking(REQD_DATA_ACCEPTED);

    // Writing INIT to peripheral
    opcode = 1, address = INIT_ADDR;
    for(int i = 0; i < NO_MODULES; i++) {
        if(REQD_DATA_ACCEPTED & (1<<i)) {
            Input1_2(INIT[i], 1);
            Input3(0, opcode, address, i);      // Mode = 0
        }
    }

    Complete_Handshaking(REQD_DATA_ACCEPTED);

    // Writing ACCEPT to peripheral
    opcode = 1, address = ACCEPT_ADDR;
    for(int i = 0; i < NO_MODULES; i++) {
        if(REQD_DATA_ACCEPTED & (1<<i)) {
            Input1_2(ACCEPT[i], 1);
            Input3(0, opcode, address, i);      // Mode = 0
        }
    }

    Complete_Handshaking(REQD_DATA_ACCEPTED);

    // Writing SELFLOOP to peripheral
    opcode = 1;
    for(int j = 0; j < 256; j++) {

        address = SELFLOOP_ADDR_BASE + (j<<3);
        for(int i = 0; i < NO_MODULES; i++) {
            if(REQD_DATA_ACCEPTED & (1<<i)) {
                Input1_2(SELFLOOP[i][j], 1);
                Input3(0, opcode, address, i);   // Mode = 0
            }
        }

        Complete_Handshaking(REQD_DATA_ACCEPTED);

    }

    // Writing MOVE to peripheral
    opcode = 1;
    for(int j = 0; j < 256; j++) {

        address = MOVE_ADDR_BASE + (j<<3);
        for(int i = 0; i < NO_MODULES; i++) {
            if(REQD_DATA_ACCEPTED & (1<<i)) {
                Input1_2(MOVE[i][j], 1);
                Input3(0, opcode, address, i);   // Mode = 0
            }
        }

        Complete_Handshaking(REQD_DATA_ACCEPTED);

    }

    return REQD_DATA_ACCEPTED;
    
}


/*
    Function to send same preprocessing information to all the modules in the peripheral in one shot and make use of parallel processing capability of peripheral.
    (MODE 1)
    Arguments :
        pattern - char* string representing the pattern to be sent to all the modules. "\0" represents empty pattern (i.e) modules need not be used
    Returns :
        An integer - 1 implies that module was used, 
                     0 implies either the modules weren't required or the provided pattern couldn't be processed
*/
int PreProcessAll_M1(char *pattern) {

    unsigned int INIT, ACCEPT, EpsBEG, EpsEND ,EpsBLK;
    unsigned int SELFLOOP[256], MOVE[256];

    if(pattern[0] == '\0') return 0;
    int ret_code = parseEXT(pattern, &INIT, &ACCEPT, &EpsBEG, &EpsEND, &EpsBLK, MOVE, SELFLOOP);
    if(!ret_code) return 0;

    unsigned int REQD_DATA_ACCEPTED = (1<<NO_MODULES)-1;

    // opcode = 1 : Input for preprocessing
    // Writing EpsBEG to peripheral
    int opcode = 1, address = EpsBEG_ADDR;
    Input1_2(EpsBEG, 1);
    Input3(1, opcode, address, 0);          // Mode = 1, target module : dont care

    Complete_Handshaking(REQD_DATA_ACCEPTED);

    // Writing EpsBLK to peripheral
    opcode = 1, address = EpsBLK_ADDR;
    Input1_2(EpsBLK, 1);
    Input3(1, opcode, address, 0);          // Mode = 1, target module : dont care

    Complete_Handshaking(REQD_DATA_ACCEPTED);

    // Writing EpsEND to peripheral
    opcode = 1, address = EpsEND_ADDR;
    Input1_2(EpsEND, 1);
    Input3(1, opcode, address, 0);          // Mode = 1, target module : dont care

    Complete_Handshaking(REQD_DATA_ACCEPTED);

    // Writing INIT to peripheral
    opcode = 1, address = INIT_ADDR;
    Input1_2(INIT, 1);
    Input3(1, opcode, address, 0);          // Mode = 1, target module : dont care

    Complete_Handshaking(REQD_DATA_ACCEPTED);

    // Writing ACCEPT to peripheral
    opcode = 1, address = ACCEPT_ADDR;
    Input1_2(ACCEPT, 1);
    Input3(1, opcode, address, 0);          // Mode = 1, target module : dont care

    Complete_Handshaking(REQD_DATA_ACCEPTED);

    // Writing SELFLOOP to peripheral
    opcode = 1;
    for(int j = 0; j < 256; j++) {

        address = SELFLOOP_ADDR_BASE + (j<<3);
        Input1_2(SELFLOOP[j], 1);
        Input3(1, opcode, address, 0);      // Mode = 1, target module : dont care

        Complete_Handshaking(REQD_DATA_ACCEPTED);

    }

    // Writing MOVE to peripheral
    opcode = 1;
    for(int j = 0; j < 256; j++) {

        address = MOVE_ADDR_BASE + (j<<3);
        Input1_2(MOVE[j], 1);
        Input3(1, opcode, address, 0);      // Mode = 1, target module : dont care

        Complete_Handshaking(REQD_DATA_ACCEPTED);

    }

    return 1;

}


/*
    Function to send preprocessing information to a specific module in the peripheral.
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

    unsigned int REQD_DATA_ACCEPTED = (1<<module);

    // opcode = 1 : Input for preprocessing
    // Writing EpsBEG to peripheral
    int opcode = 1, address = EpsBEG_ADDR;
    Input1_2(EpsBEG, 1);
    Input3(0, opcode, address, module);     // Mode = 0

    Complete_Handshaking(REQD_DATA_ACCEPTED);

    // Writing EpsBLK to peripheral
    opcode = 1, address = EpsBLK_ADDR;
    Input1_2(EpsBLK, 1);
    Input3(0, opcode, address, module);     // Mode = 0

    Complete_Handshaking(REQD_DATA_ACCEPTED);

    // Writing EpsEND to peripheral
    opcode = 1, address = EpsEND_ADDR;
    Input1_2(EpsEND, 1);
    Input3(0, opcode, address, module);     // Mode = 0

    Complete_Handshaking(REQD_DATA_ACCEPTED);

    // Writing INIT to peripheral
    opcode = 1, address = INIT_ADDR;
    Input1_2(INIT, 1);
    Input3(0, opcode, address, module);     // Mode = 0

    Complete_Handshaking(REQD_DATA_ACCEPTED);

    // Writing ACCEPT to peripheral
    opcode = 1, address = ACCEPT_ADDR;
    Input1_2(ACCEPT, 1);
    Input3(0, opcode, address, module);     // Mode = 0

    Complete_Handshaking(REQD_DATA_ACCEPTED);

    // Writing SELFLOOP to peripheral
    opcode = 1;
    for(int j = 0; j < 256; j++) {

        address = SELFLOOP_ADDR_BASE + (j<<3);
        Input1_2(SELFLOOP[j], 1);
        Input3(0, opcode, address, module); // Mode = 0

        Complete_Handshaking(REQD_DATA_ACCEPTED);

    }

    // Writing MOVE to peripheral
    opcode = 1;
    for(int j = 0; j < 256; j++) {

        address = MOVE_ADDR_BASE + (j<<3);
        Input1_2(MOVE[j], 1);
        Input3(0, opcode, address, module); // Mode = 0

        Complete_Handshaking(REQD_DATA_ACCEPTED);

    }

    return 1;

}


/*
    Function to simulate Non-deterministic Finite Automaton in necessary modules of the peripheral parallely without waiting for one module to complete.
    (MODE 0)
    Arguments :
        text_char - char array where Ith character is the text character to be sent to the Ith module. "\0" represents empty pattern (i.e) Ith module need not be used
    Returns :
        An integer which is a bitmask, where Ith place being 1 implies the text (entered till now) has matched the pattern in that module, 
                                                             0 implies either the module didn't process anything, or the text hasn't matched the pattern yet
*/
int SimulateNFA_All_M0(char text_chars[NO_MODULES]) {

    unsigned int TARGET_MODULES = 0;

    for(int i = 0; i < NO_MODULES; i++) {
        if(text_chars[i] != '\0') {
            TARGET_MODULES |= (1<<i);
            Input1_2((int)text_chars[i], 1);
            // opcode = 2 : Input for simulating NFA; address : dont care
            Input3(0, 2, 0, i);     // Mode = 0
        }
    }

    unsigned int PATTERN_ACCEPTED_STATUS = Complete_Handshaking(TARGET_MODULES);

    return (PATTERN_ACCEPTED_STATUS & TARGET_MODULES);

}


/*
    Function to simulate Non-deterministic Finite Automaton in all modules of the peripheral parallely with the same character.
    (MODE 1)
    Arguments :
        text_char - text character to be sent to the target module. "\0" represents empty pattern (i.e) modules need not be used
    Returns :
        An integer which is a bitmask, where Ith place being 1 implies the text (entered till now) has matched the pattern in that module, 
                                                             0 implies either the module didn't process anything, or the text hasn't matched the pattern yet
*/
int SimulateNFA_All_M1(char text_char) {

    if(text_char == '\0') return 0;

    unsigned int TARGET_MODULES = (1<<NO_MODULES)-1;

    Input1_2((int)text_char, 1);
    // opcode = 2 : Input for simulating NFA; address, target module : dont care
    Input3(1, 2, 0, 0);    // Mode = 1

    unsigned int PATTERN_ACCEPTED_STATUS = Complete_Handshaking(TARGET_MODULES);

    return PATTERN_ACCEPTED_STATUS;

}


/*
    Function to simulate Non-deterministic Finite Automaton in the specified module of the peripheral.
    Arguments :
        text_char - text character to be sent to the target module. "\0" represents empty pattern (i.e) module need not be used
        module - integer representing the module number to be targetted
    Returns :
        An integer - 1 implies the text (entered till now) has matched the pattern in the target module, 
                     0 implies either the module didn't process anything, or the text hasn't matched the pattern yet
*/
int SimulateNFA(char text_char, int module) {

    if(text_char == '\0') return 0;

    unsigned int TARGET_MODULE = (1<<module);

    Input1_2((int)text_char, 1);
    // opcode = 2 : Input for simulating NFA; address : dont care
    Input3(0, 2, 0, module);    // Mode = 0

    unsigned int PATTERN_ACCEPTED_STATUS = Complete_Handshaking(TARGET_MODULE);

    return (PATTERN_ACCEPTED_STATUS & TARGET_MODULE) != 0;

}


/*
    Function to reset the state of NFA in required modules without doing it separately one after the other.
    (MODE 0)
    Arguments :
        bitmask - Ith position 1 represents Ith module has to be reset, 0 represents no change
*/
void ResetNFA_All_M0(unsigned int bitmask) {

    for(int i = 0; i < NO_MODULES; i++) {
        if(bitmask & (1<<i)) {
            // opcode = 3 : Reset state instruction; address : dont care
            Input3(0, 3, 0, i);     // Mode = 0
        }
    }

    Complete_Handshaking(bitmask);

}


/*
    Function to reset the state of NFA in all modules parallely.
    (MODE 1)
    Arguments :
        module - MODULE_ID of target module where state has to be reset
*/
void ResetNFA_All_M1() {

    // opcode = 3 : Reset state instruction; address : dont care
    Input3(1, 3, 0, 0);       // Mode = 1, target module : dont care

    Complete_Handshaking((1<<NO_MODULES)-1);

}


/*
    Function to reset the state of NFA in target module.
    Arguments :
        module - MODULE_ID of target module where state has to be reset
*/
void ResetNFA(int module) {

    // opcode = 3 : Reset state instruction; address : dont care
    Input3(0, 3, 0, module);    // Mode = 0

    Complete_Handshaking((1<<module));

}

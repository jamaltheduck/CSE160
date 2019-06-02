#ifndef LINKSTATE_H
#define LINKSTATE_H

typedef nx_struct linkState{
		nx_uint8_t nextHop;
		nx_uint8_t cost;
		nx_uint8_t src;
	}linkState;
	
#endif
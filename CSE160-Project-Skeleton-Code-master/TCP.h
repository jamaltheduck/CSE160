#ifndef TCP_H
#define TCP_H

#include "includes/packet.h"
enum{
	TRANSPORT_MAX_SIZE = PACKET_MAX_PAYLOAD_SIZE,
	TRANSPORT_HEADER_SIZE = 8,
	TRANSPORT_MAX_PAYLOAD_SIZE = TRANSPORT_MAX_SIZE - TRANSPORT_HEADER_SIZE,
	TRANSPORT_MAX_PORT = 255 
};

//Types of Packets
enum{
	TRANSPORT_SYN = 0,
	TRANSPORT_ACK = 1,
	TRANSPORT_SYNACK = 2,
	TRANSPORT_FIN = 3,
	TRANSPORT_FINACK = 4,
	TRANSPORT_DATA = 5,
	TRANSPORT_TYPE_SIZE = 6
};

enum{
	NULL_TRANSPORT_PAYLOAD = 0,
	NULL_TRANSPORT_VALUE = 0,
	NULL_TRANSPORT_HEX_VALUE = 0x0000
};

typedef nx_struct TCP{
	nx_uint8_t srcPort;
	nx_uint8_t destPort;
	nx_uint8_t type;
	nx_uint16_t window;
	nx_uint16_t seq;
	nx_uint8_t len;
	nx_uint8_t payload[TRANSPORT_MAX_PAYLOAD_SIZE];
}TCP;

void createTransport(transport *output, uint8_t srcPort, uint8_t destPort, uint8_t type, uint16_t window, int16_t seq, uint8_t *payload, uint8_t packetLength);
void printTransport(transport *input);



#endif /* TCP_H */
#include "../../includes/packet.h"
#include "../../includes/socket.h"

module TCPSocketC{


}
implementation{	

	command socket_t socket(){
		
	}
	
	command error_t bind(socket_t fd, socket_addr_t *addr){
		int i;
		dbg("Project3Socket", "Binding \n");
		//make a function that checks if that port is already being used
		for(i = 0; i < 20; i++){
			if(portTracker[i] == addr->port){
				return -1;
			}
		}
		portTracker[internalPort] = addr->port;
		internalPort++;
		fd.src = addr->port;
		fd.state = CLOSED;
		fd.dest = addr->addr;
		return 0;
	}
	
	command error_t listen(socket_t fd){
		dbg("Project3Socket", "Listening...\n");
		fd.state = LISTEN;
		return 0;
	}
	
	command socket_t accept(socket_t fd){
			
			socket.src = fd.src;
			socket.dest = fd.dest;
			output.socketState = SYN_RCVD;
			currentlyConnected++;
			return socket;
	}

	command error_t connect(socket_t fd, socket_addr_t * addr){
		pack packet;
		TCP * tcpPack;
		tcpPack = (TCP*)packet.payload;
		TCP->flag = 0;
		TCP->destPort = addr->port;
		TCP->srcPort = addr->addr;
		TCP->seq = 0;
		
		makePack(&packet, TOS_NODE_ID, fd.dest.addr, 255, 4, 0, fd, 20);
		
		fd.state = 3;
		
		if(
		
		
		return -1;
	}

	async command uint8_t TCPSocket.close(TCPSocketAL *input){
		//make sure that all the packets are sent first and is received by the other side
		//which will then be in "is closing" state
		// should send a FIN packet
		// should be in closing state
		input->socketState = CLOSED;
		input->isAvailable = TRUE;
		return 0;
	}

	async command uint8_t TCPSocket.release(TCPSocketAL *input){
		input->socketState = CLOSED;
		input->isAvailable = TRUE;
		return 0;
	}
	
	async command int16_t TCPSocket.send(TCPSocketAL *input, uint8_t *writeSocketBuffer){
		nx_uint8_t payload[TRANSPORT_MAX_PAYLOAD_SIZE];
		uint8_t bytesStoredInBuffer = 0;
		uint8_t bytesWritten = 0;
		transport tcpHeader;
		// last acknowledged received
		//last frame sent
		//sws = send window size; is this basically the window size that will be given?
		//LFS-LAR <= SWS
		
		//sender should retransmit every so often.... 
		
		//num of window size is in bytes
		//dbg("Project3Socket", "Sending something? pos:%d len:%d \n", pos, len);
		
		/*
		 *
		while(len != 0){
			if(len < TRANSPORT_MAX_PAYLOAD_SIZE){
				memcpy(&payload, (writeBuffer) + bytesWritten, len);
				dbg("Project3Socket", "Checking payload: %s \n", payload);
				createTransport(&tcpHeader, input->srcPort, input->destPort, TRANSPORT_DATA, window, seq , &payload, len);
				printTransport(&tcpHeader);
				call node.sendTransport(&tcpHeader, input->destAddr);
				bytesWritten += len;
				len = 0;
			}
			else{
				memcpy(&payload, (writeBuffer) + bytesWritten, TRANSPORT_MAX_PAYLOAD_SIZE);
				dbg("Project3Socket", "Checking payload: %s \n", payload);
				createTransport(&tcpHeader, input->srcPort, input->destPort, TRANSPORT_DATA, window, seq , &payload, TRANSPORT_MAX_PAYLOAD_SIZE);
				printTransport(&tcpHeader);
				call node.sendTransport(&tcpHeader, input->destAddr);
				len -= TRANSPORT_MAX_PAYLOAD_SIZE;
				bytesWritten += TRANSPORT_MAX_PAYLOAD_SIZE;
			}
		}
		*/
		return bytesStoredInBuffer;
	}
	
	async command int16_t TCPSocket.receive(TCPSocketAL *input, uint8_t *readSocketBuffer){
		//RWS receive window size; upper bound on the number of out-of-order frames
		//LAF largest acceptable frame
		//LFR last frame received
		//LAF-LFR <= RWS
		
		//frames have seqNums
		//if SeqNum <= LFR or SeqNum > LAF; discard
		//if LFR < SeqNuM <= LAF, accept it
		//seqNumToAck, largest sequence number not yet acknowledged but anything smaller than seqNumToAck has already been received
		// LFR = seqNumToAck and LAF = LFR+RWS
		return 0;
	}
	
	async command int16_t TCPSocket.read(TCPSocketAL *input, uint8_t *readBuffer, uint16_t pos, uint16_t len){
		
		//call receive
		uint8_t bytesRead = 0;
		//dbg("Project3Socket", "Receiving something? pos:%d len:%d dest:%d readbuffer:%s \n", pos, len, input->destAddr, readBuffer);
		
		return 20;
	}

	async command int16_t TCPSocket.write(TCPSocketAL *input, uint8_t *writeBuffer, uint16_t pos, uint16_t len){
		nx_uint8_t payload[TRANSPORT_MAX_PAYLOAD_SIZE];
		uint8_t bytesStoredInBuffer = 0;
		uint8_t bytesWritten = 0;
		transport tcpHeader;
		
		//num of window size is in bytes
		dbg("Project3Socket", "Sending something? pos:%d len:%d \n", pos, len);
		
		while(sockPushBack(&input->sendBuffer,(socketData){TRANSPORT_DATA,writeBuffer[pos+bytesStoredInBuffer],pos+bytesStoredInBuffer})){
			dbg("Project3Socket","I can still store stuff %d \n", pos+bytesStoredInBuffer);
			bytesStoredInBuffer++;
		}
		return bytesStoredInBuffer;
		/*
		 * 
		while(len != 0){
			if(len < TRANSPORT_MAX_PAYLOAD_SIZE){
				memcpy(&payload, (writeBuffer) + bytesWritten, len);
				dbg("Project3Socket", "Checking payload: %s \n", payload);
				createTransport(&tcpHeader, input->srcPort, input->destPort, TRANSPORT_DATA, window, seq , &payload, len);
				printTransport(&tcpHeader);
				call node.sendTransport(&tcpHeader, input->destAddr);
				bytesWritten += len;
				len = 0;
			}
			else{
				memcpy(&payload, (writeBuffer) + bytesWritten, TRANSPORT_MAX_PAYLOAD_SIZE);
				dbg("Project3Socket", "Checking payload: %s \n", payload);
				createTransport(&tcpHeader, input->srcPort, input->destPort, TRANSPORT_DATA, window, seq , &payload, TRANSPORT_MAX_PAYLOAD_SIZE);
				printTransport(&tcpHeader);
				call node.sendTransport(&tcpHeader, input->destAddr);
				len -= TRANSPORT_MAX_PAYLOAD_SIZE;
				bytesWritten += TRANSPORT_MAX_PAYLOAD_SIZE;
			}
		}
		*/
	}

	async command bool TCPSocket.isListening(TCPSocketAL *input){
		if(input->socketState == LISTEN){
			return TRUE;
		}
		else{
			 return FALSE;
		}
	}

	async command bool TCPSocket.isConnected(TCPSocketAL *input){
		if(input->socketState == ESTABLISHED) return TRUE;
		else return FALSE;
	}	

	async command bool TCPSocket.isClosing(TCPSocketAL *input){
		if(input->socketState == CLOSING) return TRUE;
		else return FALSE;
	}

	async command bool TCPSocket.isClosed(TCPSocketAL *input){
		if(input->socketState == CLOSED) return TRUE;
		else return FALSE;
	}

	async command bool TCPSocket.isConnectPending(TCPSocketAL *input){
		if(input->socketState == SYN_SENT) return TRUE;
		else return FALSE;
	}
	
	async command void TCPSocket.copy(TCPSocketAL *input, TCPSocketAL *output){
		output->srcPort = input->srcPort; output->srcAddr = input->srcAddr;
		output->destPort = input->destPort; output->destAddr = input->destAddr;
	}
}
/*
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */

#include <Timer.h>
#include "includes/command.h"
#include "includes/packet.h"
#include "includes/CommandMsg.h"
#include "includes/sendInfo.h"
#include "includes/channels.h"
#include "linkState.h"
#include "includes/socket.h"
#include "TCP.h"

module Node{
   uses interface Boot;

   uses interface SplitControl as AMControl;
   uses interface Receive;

   uses interface SimpleSend as Sender;
   
   uses interface Packet;
   
   uses interface AMSend;

   uses interface CommandHandler;
   
   uses interface Random as Random;
   
   uses interface Timer<TMilli> as timer; // neighbor discovery
   
   uses interface Timer<TMilli> as timer2; //link state discovery
   
   uses interface Timer<TMilli> as timer3; // routing table update
   
   uses interface Timer<TMilli> as closedtimer;
   
   uses interface List<sendInfo> as neighborlist;
   
   uses interface List<linkState> as routingTable;
   
   uses interface List<uint8_t> as costList;
   
   uses interface List<socket_store_t> as socketList;
   
   uses interface List<socket_store_t> as usernameList;

}


implementation{

	bool busy = FALSE;
	
	bool isActive = TRUE;
	
	bool contains = FALSE;
	
	bool endMsg = FALSE;
	
	uint16_t seqNum = 0;
	uint16_t nSeq = 0;
	
	message_t pkt;
	
   linkState lsPack;
   
   linkState lsCompare;
   linkState lsTemp2;
   linkState lsNode;
   
   uint8_t cost1;
   uint8_t cost2;
   uint8_t costNode;

   pack sendPackage;
   
   sendInfo neighbor;
   sendInfo neighborCompare;
   
   sendBuffer packBuffer;
   
   uint8_t lsinfo[] = {0,0,0,0,5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};
   
   uint16_t ttl = 0;
   uint16_t prot = 0;
   uint16_t size = 0;
   uint16_t i = 0;
   uint16_t j = 0;
   uint16_t k = 0;
   uint8_t minCost = 0;
   uint8_t nHop = 0;
   uint16_t counter = 0;
   uint8_t closedCount = 0;
   
   
   //proj 3 variables
   socket_store_t socket;
   socket_addr_t socketAddr;
   
   uint8_t srcPort;
   uint8_t destPort;
   uint8_t tcpSeq;
   uint8_t tcpAck;
   uint8_t tcpFlag;
   uint16_t dataSend;
   TCP * tcpPack;
   
   uint16_t msgChars;

   // Prototypes
   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t* payload, uint8_t length);
   
   void lsFlood();
   
   void printRTCost();
   
   void fillRT();
   
   uint8_t dijkstra(uint8_t key);
   
   error_t ping(uint16_t src, uint16_t dest, pack *message);
   
   task void BufferTask();
   
   void connect(socket_store_t fd, socket_addr_t * addr);
   
   socket_store_t getSocket(uint8_t destP);

	void sendData(socket_store_t mySocket);

   event void Boot.booted(){
      call AMControl.start();
	 
	  
      dbg(FLOODING_CHANNEL, "Booted\n");
   }

   event void AMControl.startDone(error_t err){
      if(err == SUCCESS){
         dbg(FLOODING_CHANNEL, "Radio On\n");
		  call timer.startPeriodic(5333 + (uint16_t) ((call Random.rand16())%200));
		  call timer2.startPeriodic(5333 + (uint16_t) ((call Random.rand16())%200));
      }else{
         //Retry until successful
         call AMControl.start();
      }
	  
   }

   event void AMControl.stopDone(error_t err){}
   
   event void AMSend.sendDone(message_t* msg, error_t error){
	if(&pkt == msg){
			//dbg("genDebug", "Packet Sent\n");
			busy = FALSE;
			//dbg("Project1F", "Broadcasted\n\n");
			post BufferTask();
		}
   }
   
   event void timer.fired(){

		pack discoveryPackage;
		uint8_t createMsg[PACKET_MAX_PAYLOAD_SIZE];
		//memcpy(&createMsg, "", sizeof(PACKET_MAX_PAYLOAD_SIZE));
		//memcpy(&outgoing, "", sizeof(uint8_t));
		makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, 255, 0, 0, (uint8_t *)createMsg, PACKET_MAX_PAYLOAD_SIZE);	
		
		
		BufferPushBack(&packBuffer, sendPackage, sendPackage.src, AM_BROADCAST_ADDR);
		
		post BufferTask();
	  
   }
   
   event void timer2.fired(){
		pack discoveryPackage;
		uint8_t createMsg[PACKET_MAX_PAYLOAD_SIZE];
		makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, ttl, 2, 0, (uint8_t *)createMsg, PACKET_MAX_PAYLOAD_SIZE);
		BufferPushBack(&packBuffer, sendPackage, sendPackage.src, AM_BROADCAST_ADDR);
		post BufferTask();
		
   }
   
   event void timer3.fired(){
   
   }

	event void closedtimer.fired(){
		//dbg(FLOODING_CHANNEL, "CLIENT CLOSED!\n");
		if(closedCount == 1){
			socket = call socketList.popfront();
			socket.state = CLOSED;
			call socketList.pushfront(socket);
			dbg(FLOODING_CHANNEL, "CLIENT CLOSED!\n");
			//call closedtimer.stop();
			size = call routingTable.size();
			if(size < 1){
				fillRT();
			}
			tcpPack->flag = 4;
			makePack(&sendPackage, TOS_NODE_ID, socket.dest.addr, 255, 4, 0, tcpPack, 20);
			size = call routingTable.size();
			for(i = 0; i < size; i++){
				lsPack = call routingTable.get(i);
				if(lsPack.src == socket.dest.addr){
					BufferPushBack(&packBuffer, sendPackage, TOS_NODE_ID, lsPack.nextHop);
					post BufferTask();
					sendData(socket);
					closedCount++;
					break;
				}
			}
		}
		closedCount++;
	}
   
   
   event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
      //dbg(FLOODING_CHANNEL, "Packet Received\n");
      if(len==sizeof(pack)){
		 
         pack* myMsg=(pack*) payload;
		 prot = (uint16_t) myMsg->protocol;
		 
		 ttl = (uint16_t) myMsg->TTL;
		 ttl = ttl - 1;
		 
		 if(myMsg->TTL == 0){
			return msg;
		 }
		 
		 
		if(TOS_NODE_ID == myMsg->dest){
				switch(prot){
					case 0: //ping
						makePack(&sendPackage, TOS_NODE_ID, myMsg->src, ttl, 1, 0, (uint8_t *) myMsg->payload, PACKET_MAX_PAYLOAD_SIZE);
						BufferPushBack(&packBuffer, sendPackage, sendPackage.src, AM_BROADCAST_ADDR);
						post BufferTask();
						break;
					case 1://ping reply
						size = call neighborlist.size();
						
						//see if neighborlist contains neighbor before adding to list
						
						if(size > 0){
							for(i = 0; i < size; i++){
								neighborCompare = call neighborlist.get(i);
								if(neighborCompare.src == myMsg->src){
									contains = TRUE;
								}
							}
						}
						
						// if the neighbor is not in the list, add it to the list
						
						if(contains == FALSE){
							neighbor.src = myMsg->src;
							neighbor.dest = myMsg->dest;
							call neighborlist.pushback(neighbor);
							break;
						}
						contains = FALSE;
						break;
					case 4: //tcp
						tcpPack = (TCP*)myMsg->payload;
						switch(tcpPack->flag){
							case 0: // SYN
								dbg(FLOODING_CHANNEL, "SYN ARRIVED!\n");
								socket = getSocket(tcpPack->destPort);
							
								if(socket.state == LISTEN){
									socket.state = SYN_RCVD;
									socket.dest.port = tcpPack->srcPort;
									socket.dest.addr = myMsg->src;
									call socketList.pushfront(socket);
									size = call routingTable.size();
									if(size < 1){
										fillRT();
									}
									tcpPack->flag = 2;
									
									for(i = 0; i < 11; i++){
									if(tcpPack->payload[i] == 32){
										break;
									}
									socket.username[i] = tcpPack->payload[i];
									printf("%c",tcpPack->payload[i]);
								    }
								    printf("\n");
									
									call usernameList.pushfront(socket);
									
									makePack(&sendPackage, TOS_NODE_ID, tcpPack->srcPort, 255, 4, 0, tcpPack, 20);
									//dbg(FLOODING_CHANNEL, "Heading from Server at: %d, to Client at: %d\n", TOS_NODE_ID, tcpPack->srcPort);
									size = call routingTable.size();
									for(i = 0; i < size; i++){
										lsPack = call routingTable.get(i);
										if(lsPack.src == myMsg->src){
											//dbg(FLOODING_CHANNEL, "TEST PACKET SENT FROM NODE %d\n", TOS_NODE_ID);
											//dbg(FLOODING_CHANNEL, "NEXT HOP: %d\n", lsPack.nextHop);
											BufferPushBack(&packBuffer, sendPackage, TOS_NODE_ID, lsPack.nextHop);
											post BufferTask();
											break;
										}
									}
									
							
								}
								break;
							case 2://SYN_ACK
								dbg(FLOODING_CHANNEL, "SYN_ACK ARRIVED!\n");
								socket = getSocket(tcpPack->destPort);
								
								if(socket.state == SYN_SENT){
									socket.state = ESTABLISHED;
									call socketList.pushfront(socket);
									dbg(FLOODING_CHANNEL, "CLIENT CONNECTION ESTABLISHED!\n");
									size = call routingTable.size();
									if(size < 1){
										fillRT();
									}
									tcpPack->flag = 1;
									makePack(&sendPackage, TOS_NODE_ID, socket.dest.addr, 255, 4, 0, tcpPack, 20);
									//dbg(FLOODING_CHANNEL, "Heading from Server at: %d, to Client at: %d\n", TOS_NODE_ID, socket.dest.addr);
									size = call routingTable.size();
									for(i = 0; i < size; i++){
										lsPack = call routingTable.get(i);
										if(lsPack.src == socket.dest.addr){
											//dbg(FLOODING_CHANNEL, "TEST PACKET SENT FROM NODE %d\n", TOS_NODE_ID);
											//dbg(FLOODING_CHANNEL, "NEXT HOP: %d\n", lsPack.nextHop);
											BufferPushBack(&packBuffer, sendPackage, TOS_NODE_ID, lsPack.nextHop);
											post BufferTask();
											//sendData(socket);
											break;
										}
									}
									
							
								}
								break;
							case 1: //ACK
								dbg(FLOODING_CHANNEL, "ACK ARRIVED!\n");
								socket = getSocket(tcpPack->destPort);
								
								if(socket.state == SYN_RCVD){
									socket.state = ESTABLISHED;
									call socketList.pushfront(socket);
									dbg(FLOODING_CHANNEL, "SERVER CONNECTION ESTABLISHED!\n");
									
								}
								break;
								
							case 5: // data send
								//if msg seq = 0, then it is from client
								
								if(socket.lastRcvd == 128){
									//receive buffer full
									break;
								}
								
								
								if(myMsg->seq == 0){ //CLIENT TO SERVER
									
										if(socket.nextExpected != tcpPack->seq){
											break;
										}
										
										dbg(FLOODING_CHANNEL, "SEQ NUM:%d\n", tcpPack->seq + 1);
										socket = getSocket(tcpPack->destPort);
										i = 0;
										i =  i + (tcpPack->seq * 11); // make a new variable to keep track of incrementing array value
										k = i;
										dbg(FLOODING_CHANNEL, "i : %d\n", i);
										
										for(j = i; j < i + 12; j++){
											socket.rcvdBuff[k] = tcpPack->payload[j]; // HIGHLIGHT
											k++;
										}
										
										socket.nextExpected = seqNum + 1;
										socket.lastRcvd = tcpPack->seq;
										call socketList.pushfront(socket);
										tcpPack->seq = seqNum;
										tcpPack->flag = TRANSPORT_DATA;
										seqNum++;
										makePack(&sendPackage, TOS_NODE_ID, tcpPack->destPort, 255, 4, 1, tcpPack, 20);
										size = call routingTable.size();
										for(i = 0; i < size; i++){
											lsPack = call routingTable.get(i);
											if(lsPack.src == tcpPack->destPort){
												//dbg(FLOODING_CHANNEL, "At DEST SENT FROM NODE %d to %d\n", TOS_NODE_ID, tcpPack->destPort);
												//dbg(FLOODING_CHANNEL, "NEXT HOP: %d\n", lsPack.nextHop);
												BufferPushBack(&packBuffer, sendPackage, TOS_NODE_ID, lsPack.nextHop);
												post BufferTask();
												break;
											}
										}
									
									
									
								}
								//if msg seq = 1, then it is reply from server
								else if(myMsg->seq == 1){
									if(tcpPack->seq == dataSend - 1){
										socket = getSocket(tcpPack->destPort);
										socket.state = FIN_WAIT1;
										tcpPack->flag = TRANSPORT_FIN;
										call socketList.pushfront(socket);
										
										  printf("\n");
										makePack(&sendPackage, TOS_NODE_ID, tcpPack->srcPort, 255, 4, 0, tcpPack, 20);
											size = call routingTable.size();
											for(i = 0; i < size; i++){
												lsPack = call routingTable.get(i);
												if(lsPack.src == tcpPack->srcPort){
													//dbg(FLOODING_CHANNEL, "At DEST SENT FROM NODE %d to %d\n", TOS_NODE_ID, tcpPack->srcPort);
													//dbg(FLOODING_CHANNEL, "NEXT HOP: %d\n", lsPack.nextHop);
													BufferPushBack(&packBuffer, sendPackage, TOS_NODE_ID, lsPack.nextHop);
													post BufferTask();
													break;
												}
											}
									}
									//dbg(FLOODING_CHANNEL, "ready to send next pack\n");
									else{
										seqNum++;
										socket.nextExpected = seqNum + 1;
										socket.lastRcvd = tcpPack->seq;
										sendData(socket);
										
									}
								}
								
								else if(myMsg->seq == 3){
								
								}
							
							
								break;
								
							case 3: //FIN ARRIVES AT SERVER
								dbg(FLOODING_CHANNEL, "FIN ARRIVED at NODE:%d!\n", TOS_NODE_ID);
								size = call socketList.size();
								dbg(FLOODING_CHANNEL, "size of socketlist:%d!\n",  size);
								socket = getSocket(tcpPack->destPort);
							
								if(socket.state == ESTABLISHED){
									
									socket.state = CLOSED_WAIT;
									socket.dest.port = tcpPack->srcPort;
									socket.dest.addr = myMsg->src;
									call socketList.pushfront(socket);
									size = call routingTable.size();
									if(size < 1){
										fillRT();
									}
									tcpPack->flag = 4;
									dbg(FLOODING_CHANNEL, "FIN PRINT\n");
									
									for(i = 0; i < 12; i++){
										printf("%c", socket.rcvdBuff[i]);
									}
									printf("\n");
									
									makePack(&sendPackage, TOS_NODE_ID, tcpPack->destPort, 255, 4, 0, tcpPack, 20);
									size = call routingTable.size();
									for(i = 0; i < size; i++){
										lsPack = call routingTable.get(i);
										if(lsPack.src == tcpPack->destPort){
											BufferPushBack(&packBuffer, sendPackage, TOS_NODE_ID, lsPack.nextHop);
											post BufferTask();
											//dbg(FLOODING_CHANNEL, "FIN_ACK PACK SENT!\n");
											break;
										}
									}
									
							
								}
								break;
							case 4: //FIN_ACK ARRIVES AT CLIENT
								//dbg(FLOODING_CHANNEL, "FIN_ACK ARRIVED!\n");
								socket = getSocket(tcpPack->destPort);
								
								if(socket.state == FIN_WAIT1){ //START TIMER TO WAIT TO CLOSE
									//dbg(FLOODING_CHANNEL, "FIN_ACK ARRIVED!\n");
									socket.state = FIN_WAIT2;
									call socketList.pushfront(socket);
									call closedtimer.startPeriodic(5333);
									dbg(FLOODING_CHANNEL, "FIN_ACK ARRIVED!\n");
									break;
									
									
								}
								else{ //RECEIVE ACK FROM TIMER THAT SAYS CLIENT IS CLOSED AND THAT SERVER SHOULD CLOSE
									socket.state = CLOSED;
									dbg(FLOODING_CHANNEL, "SERVER CLOSED!\n");
									break;
								}
								
						}
						//dbg(FLOODING_CHANNEL, "TCP PACKET ARRIVED AT DESTINATION!\n");
						break;
						
					
				
				}
				return msg;
		}
		
		if(TOS_NODE_ID == myMsg->src){
		
			//If the the packet is travelling backwards and it is not the destination, then it will be dropped
		
			return msg;
		}
		
		if(myMsg->dest == AM_BROADCAST_ADDR){
			switch(prot){
				case 0:
					makePack(&sendPackage, TOS_NODE_ID, myMsg->src, ttl, 1, 0, (uint8_t *) myMsg->payload, PACKET_MAX_PAYLOAD_SIZE);
					BufferPushBack(&packBuffer, sendPackage, sendPackage.src, AM_BROADCAST_ADDR);
					post BufferTask();
					break;
				case 1:
					size = call neighborlist.size();
						
					//see if neighborlist contains neighbor before adding to list
						
					if(size > 0){
						for(i = 0; i < size; i++){
							neighborCompare = call neighborlist.get(i);
							if(neighborCompare.src == myMsg->src){
								contains = TRUE;
							}
						}
					}
						
					// if the neighbor is not in the list, add it to the list
					
					if(contains == FALSE){
						neighbor.src = myMsg->src;
						neighbor.dest = myMsg->dest;
						call neighborlist.pushback(neighbor);
						break;
					}
					contains = FALSE;
					break;
				case 2:
					makePack(&sendPackage, myMsg->src, AM_BROADCAST_ADDR, ttl, 2, 0, (uint8_t *) myMsg->payload, PACKET_MAX_PAYLOAD_SIZE);
				
					if(lsinfo[sendPackage.src - 1] == 0){
						lsinfo[sendPackage.src - 1] = 255 - ttl;
						BufferPushBack(&packBuffer, sendPackage, sendPackage.src, AM_BROADCAST_ADDR);
						post BufferTask();
						break;
					}
					else if(lsinfo[sendPackage.src - 1] > 255-ttl){
						lsinfo[sendPackage.src - 1] = 255 - ttl;
						BufferPushBack(&packBuffer, sendPackage, sendPackage.src, AM_BROADCAST_ADDR);
						post BufferTask();
						break;
					}
					
					
					break;
		
			}
	
         //dbg(FLOODING_CHANNEL, "Package Payload: %s\n", myMsg->payload);
         return msg;
        }
		else if(prot == 4){ //ROUTE TCP PACKETS
		
			tcpPack = (TCP*)myMsg->payload;
			//dbg(FLOODING_CHANNEL, "Flag: %d\n", tcpPack->flag);
			
			/*
			printf("ROUTING\n");
			for(i = 0; i < 12; i++){
				printf("%c", tcpPack->payload[i]);
			}
			printf("\n");
			*/
		
			if(myMsg->seq == 1){
				makePack(&sendPackage, TOS_NODE_ID, myMsg->dest, 255, 4, 1, tcpPack, 20);
			}
			else{
				makePack(&sendPackage, TOS_NODE_ID, myMsg->dest, 255, 4, 0, tcpPack, 20);
			}
			//dbg(FLOODING_CHANNEL, "TCP PACKET recieved!\n");
			
			size = call routingTable.size();
			if(size < 1){
				fillRT();
			}
			
			size = call routingTable.size();
			for(i = 0; i < size; i++){
			lsPack = call routingTable.get(i);
				if(lsPack.src == myMsg->dest){
					//dbg(FLOODING_CHANNEL, "NOT DEST SENT FROM NODE %d to %d\n", TOS_NODE_ID, myMsg->dest);
					//dbg(FLOODING_CHANNEL, "NEXT HOP: %d\n", lsPack.nextHop);
					BufferPushBack(&packBuffer, sendPackage, TOS_NODE_ID, lsPack.nextHop);
					post BufferTask();
				}
			}
			
		
		}
      //dbg(FLOODING_CHANNEL, "Unknown Packet Type %d\n", len);
      return msg;
	  }
   }

	
   event void CommandHandler.ping(uint16_t destination, uint8_t *payload){
      dbg(FLOODING_CHANNEL, "PING EVENT \n");
	  dbg(FLOODING_CHANNEL, "ping dest: %d\n", destination);
      makePack(&sendPackage, TOS_NODE_ID, destination, 255, 0, 1, payload, PACKET_MAX_PAYLOAD_SIZE);
	  //makePack(&sendPackage, TOS_NODE_ID, destination, TTL, Protocol, Seq, payload, PACKET_MAX_PAYLOAD_SIZE);
	  
      //call Sender.send(sendPackage, AM_BROADCAST_ADDR);
   }
   

   event void CommandHandler.printNeighbors(){
		size = call neighborlist.size();
		
		
		
		if(size != 0 ){
			for(i = 0; i < size; i++){
			neighbor = call neighborlist.get(i);
			dbg(NEIGHBOR_CHANNEL, "Node %d Neighbor: %d\n", TOS_NODE_ID, neighbor.src);
			dbg(NEIGHBOR_CHANNEL, "Node %d list size: %d\n", TOS_NODE_ID, size);
			}
		}
		else{
			dbg(NEIGHBOR_CHANNEL, "No Neighbors Listed\n");
		}
   }

   event void CommandHandler.printRouteTable(){
		dbg(FLOODING_CHANNEL, "START ROUTING\n");
		
		
		printRTCost();
		
		//run dijkstra's algorithm for cost to immediate neighbors
		//should always be a number vs -1(infinity)
   
   }
   
   void lsFlood(){ // maybe pass node id here
		
		//dbg(FLOODING_CHANNEL, "Size %d \n", size);
		//dbg(FLOODING_CHANNEL, "Node %d \n", TOS_NODE_ID);
		

			
			/*
			makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, 255, 2, 0, &lsinfo, PACKET_MAX_PAYLOAD_SIZE);
			memcpy(sendPackage.payload, lsinfo, PACKET_MAX_PAYLOAD_SIZE);
			BufferPushBack(&packBuffer, sendPackage, sendPackage.src, AM_BROADCAST_ADDR);
			post BufferTask();
			*/
			//dbg(FLOODING_CHANNEL, "LINK STATE FLOOD SENT!\n");
	
			
	

   }
   
    void printRTCost(){
		fillRT();
		size = call routingTable.size();
		for(i = 0; i < size; i++){
			lsPack = call routingTable.get(i);
			dbg(FLOODING_CHANNEL, "dest: %d, NextHop: %d, Cost: %d\n", lsPack.src, lsPack.nextHop, lsPack.cost);
		}
	}
	
	void fillRT(){
		
		for(i = 0; i < 20; i++){
				lsPack.cost = lsinfo[i];
				lsPack.src = i + 1;
				
				if(lsPack.cost != 0){
					
					lsPack.nextHop = dijkstra(i);
				}
				else{
					lsPack.nextHop = 0;
				}
				
				call routingTable.pushback(lsPack);
			}
	}
	
	uint8_t dijkstra(uint8_t key){
		size = call neighborlist.size();
		//dbg(FLOODING_CHANNEL, "Size %d \n", size);
		neighbor = call neighborlist.get(0);
		neighborCompare = call neighborlist.get(1);
		
		if(neighbor.src < neighborCompare.src){
				j = neighbor.src;
				k = neighborCompare.src;
				while(j != key){
					cost1 = cost1 + lsinfo[j];
					j--;
				}
				while(k != key){
					cost2 = cost2 + lsinfo[k];
					k++;
				}
				if(cost1 >= cost2){
					cost1 = 0;
					cost2 = 0;
					return neighborCompare.src;
				}
				else{
					cost1 = 0;
					cost2 = 0;
					return neighbor.src;
				}
		}
		else{
				j = neighborCompare.src;
				k = neighbor.src;
				while(j != key){
					cost1 = cost1 + lsinfo[j];
					j--;
				}
				while(k != key){
					cost2 = cost2 + lsinfo[k];
					k++;
				}
				if(cost1 >= cost2){
					cost1 = 0;
					cost2 = 0;
					return neighbor.src;
				}
				else{
					cost1 = 0;
					cost2 = 0;
					return neighborCompare.src;
				}
		}
	}
	
	task void BufferTask(){
		if(packBuffer.size !=0 && !busy){
			sendInfo info;
			info = BufferPopFront(&packBuffer);
			ping(info.src,info.dest, &(info.packet));
		}
		
		if(packBuffer.size !=0 && !busy){
			post BufferTask();
		}
	}
	


   event void CommandHandler.printLinkState(){}

   event void CommandHandler.printDistanceVector(){}

   event void CommandHandler.setTestServer(uint8_t * port){
   
		socket_addr_t myAddr;
		
		myAddr.addr = TOS_NODE_ID;
		myAddr.port = atoi(port);
		dbg(FLOODING_CHANNEL, "TEST server\n");
		socket.dest.port = myAddr.port;
		socket.state = LISTEN;
		socket.nextExpected = 0;
		//dbg(FLOODING_CHANNEL, "TEST server2\n");
		dbg(FLOODING_CHANNEL, "SERVER AT NODE: %d\n", TOS_NODE_ID);
		call socketList.pushfront(socket);
   
   
   }

   event void CommandHandler.setTestClient(uint8_t * payload){ //init, bind, ->connect
	  
      socket_addr_t myAddr;
	  
      uint16_t dest;

      char * token = strtok(payload, ",");
      char buffer[5];
      uint16_t arguments[3];
	  
	  i = 0;
       dbg(FLOODING_CHANNEL, "TEST CLIENT\n");
      while(token){
        arguments[i] = atoi(token);
        token = strtok(NULL, ",");
        i++;
      }
      dest = arguments[0];
      destPort = arguments[1];
      dataSend = arguments[2];
	  
      myAddr.addr = TOS_NODE_ID;

      socket.dest.port = destPort;
      socket.dest.addr = dest;
	  call socketList.pushfront(socket);
      
      connect(socket, &myAddr);
   }

   event void CommandHandler.setAppServer(){}

   event void CommandHandler.setAppClient(){}
   
   
   error_t ping(uint16_t src, uint16_t dest, pack *message){
		if(!busy && isActive){
			pack* msg = (pack *)(call Packet.getPayload(&pkt, sizeof(pack) ));			
			*msg = *message;

			//TTL Check
			if(msg->TTL >0)msg->TTL--;
			else return FAIL;

			if(call AMSend.send(dest, &pkt, sizeof(pack)) == SUCCESS){
				busy = TRUE;
				return SUCCESS;
			}
			else{
				dbg("genDebug","The radio is busy, or something\n");
				return FAIL;
			}
		}else{
			return EBUSY;
		}
		dbg("genDebug", "FAILED!?");
		return FAIL;
	}
	
   void connect(socket_store_t fd, socket_addr_t * addr){
		
		pack packet;
		tcpPack = (TCP*)packet.payload;
		tcpPack->flag = 0;
		tcpPack->destPort = fd.dest.port;
		tcpPack->srcPort = addr->addr;
		tcpPack->seq = 0;
		dbg(FLOODING_CHANNEL, "TEST CONNECT\n");
		
	   for(i = 0; i < 11; i++){
		if(fd.username[i] == 32){
			break;
		}
	    tcpPack->payload[i] = fd.username[i];
	   }
	   printf("\n");
		
		makePack(&packet, TOS_NODE_ID, fd.dest.addr, 255, 4, 0, tcpPack, 20);
		socket = call socketList.popfront();
		socket.state = SYN_SENT;
		call socketList.pushfront(socket);
		fd.state = 3;
		fillRT();
		size = call routingTable.size();
		for(i = 0; i < size; i++){
			lsPack = call routingTable.get(i);
			//dbg(FLOODING_CHANNEL, "lsPack.src: %d\n", lsPack.src);
			//dbg(FLOODING_CHANNEL, "fd.dest.addr: %d\n", fd.dest.addr);
			if(lsPack.src == fd.dest.addr){
				dbg(FLOODING_CHANNEL, "TEST PACKET SENT FROM NODE %d\n", TOS_NODE_ID);
				//dbg(FLOODING_CHANNEL, "NEXT HOP: %d\n", lsPack.nextHop);
				BufferPushBack(&packBuffer, packet, TOS_NODE_ID, lsPack.nextHop);
				post BufferTask();
			}
		}
	
		return;
   }
   
   
   socket_store_t getSocket(uint8_t destP){
	    bool found;
		socket_store_t retSocket;
		size = call socketList.size();
		//dbg(FLOODING_CHANNEL, "Size: %d\n", size);
		for(i = 0; i < size; i++){
			retSocket = call socketList.get(i);
			call socketList.remove(i);
			//dbg(FLOODING_CHANNEL, "dest port: %d\n", retSocket.dest.port);
			//dbg(FLOODING_CHANNEL, "dest port: %d\n", destP);
			//dbg(FLOODING_CHANNEL, "state: %d\n", retSocket.state);
			if(retSocket.dest.port == destP && retSocket.state == LISTEN){
				found = TRUE;
				break;
			}
			else if(retSocket.dest.port == destP && retSocket.state == SYN_SENT){
				found = TRUE;
				break;
			}
			else if(retSocket.dest.port == destP && retSocket.state == SYN_RCVD){
				found = TRUE;
				break;
			}
			else if(retSocket.dest.port == destP && retSocket.state == ESTABLISHED){
				found = TRUE;
				break;
			}
			else if(retSocket.dest.port == destP && retSocket.state == FIN_WAIT1){
				found = TRUE;
				break;
			}
			else if(retSocket.dest.port == destP && retSocket.state == CLOSED_WAIT){
				found = TRUE;
				break;
			}
		}
		if(found){
			return retSocket;
		}
		else{
			//dbg(FLOODING_CHANNEL, "DIDNT WORK LINE 639, getsocket!\n"); 
		}
   }
   
   void sendData(socket_store_t mySocket){
				//set datasend to index right before \\r\\n happens
				// divide datasend by 12 with ceiling function
				//send that many packets

				pack packet;
				tcpPack = (TCP*)packet.payload;
				tcpPack->flag = TRANSPORT_DATA;
				tcpPack->destPort = socket.dest.port;
				tcpPack->srcPort = socket.dest.addr;
				tcpPack->seq = seqNum;
				tcpPack->window = dataSend;
				//dbg(FLOODING_CHANNEL, "DATA SEND CALLED!\n"); 
				j = 0;
				for(i = socket.lastSent; i < msgChars - socket.lastSent; i++){
					tcpPack->payload[j] = mySocket.sendBuff[i];
					j++;
				}
				printf("SEND DATA\n");
				
				socket.lastSent = i;
				
				for(i = 0; i < msgChars; i++){
					printf("%c",tcpPack->payload[i]);
				}
				printf("\n");
				
				
				if(counter == dataSend){
					tcpPack->flag = TRANSPORT_FIN;
				}
				//dbg(FLOODING_CHANNEL, "DEST port:%d\n", socket.dest.port);
				//dbg(FLOODING_CHANNEL, "DEST addr:%d\n", socket.dest.addr);
				
				//dbg(FLOODING_CHANNEL, "CLIENT DATA SEND\n");
				makePack(&packet, TOS_NODE_ID, socket.dest.addr, 255, 4, 0, tcpPack, 20);
				size = call routingTable.size();
				if(size < 1){
					fillRT();
				}
				for(i = 0; i < size; i++){
					lsPack = call routingTable.get(i);
					if(lsPack.src == socket.dest.addr){
						BufferPushBack(&packBuffer, packet, TOS_NODE_ID, lsPack.nextHop);
						post BufferTask();
					}
				}

		return;
   }
   
   event void CommandHandler.hello(uint8_t * payload){
	  //dbg(FLOODING_CHANNEL, "TEST Hello\n");
	  socket_addr_t myAddr;
	  char tempBuff[128];
	  uint16_t dest;
	  memcpy(tempBuff, payload, 128);
	  i = 0;
	  dbg(FLOODING_CHANNEL, "payload: %d\n", payload[0]);
	  while(endMsg != TRUE){
		if(tempBuff[i] == 32){
			dest = tempBuff[i+1] - 48;
			endMsg = TRUE;
		}
		i++;
	  }
	  endMsg = FALSE;

	  for(i = 0; i < 11; i++){
		if(payload[i] == 32){
			break;
		}
	    socket.username[i] = payload[i];
	  }
	  printf("\n");

	  myAddr.addr = TOS_NODE_ID;
	  socket.dest.port = TOS_NODE_ID;
      socket.dest.addr = dest;
	  dbg(FLOODING_CHANNEL, "dest: %d\n", socket.dest.addr);
	  call socketList.pushfront(socket);
      
      connect(socket, &myAddr);
	//memcpy payload to socket
	//call connect to connect to server
	
	
	//transport 11 chars at a time
	//increment by 11 when sent
	//call dataSend to send packet
	
   }
   
   event void CommandHandler.whisper(uint8_t * payload){
	  socket_addr_t myAddr;
	  char tempBuff[128];
	  bool atMsg = FALSE;
	  memcpy(socket.sendBuff, payload, 128);
	  i = 0;
	  j = 0;
	  dbg(FLOODING_CHANNEL, "WHISPER\n");
	  
	  while(endMsg != TRUE){
		if(atMsg == TRUE){
			socket.sendBuff[j] = payload[i];
			if(payload[i + 1] == 92){
				if(payload[i + 2] == 114){
					if(payload[i + 3] == 92){
						if(payload[i + 4] == 110){
							endMsg = TRUE;
							msgChars = i - (i - j) + 1;
							dataSend = (msgChars/12) + 1;
						}
					}
				}
			}
			j++;
			
		}
		
		if(atMsg == FALSE){
			socket.destUser[i] = payload[i];
		}
	
		if(payload[i] == 32 && atMsg == FALSE){
			atMsg = TRUE;
			dbg(FLOODING_CHANNEL, "SPACE AT: %d\n", i);
		}
		i++;
	  }
	  endMsg = FALSE;
	  socket.lastSent = 0;
	  
	  
	  for(i = 0; i < 12; i++){
		printf("%c",socket.destUser[i]);
	  }
	  printf("\n");
	  
	  sendData(socket);
   }

   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
      Package->src = src;
      Package->dest = dest;
      Package->TTL = TTL;
      Package->seq = seq;
      Package->protocol = protocol;
      memcpy(Package->payload, payload, length);
   }
}
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
   
   uses interface List<sendInfo> as neighborlist;
   
   uses interface List<linkState> as routingTable;
   
   uses interface List<uint8_t> as costList;

}


implementation{

	bool busy = FALSE;
	
	bool isActive = TRUE;
	
	bool contains = FALSE;
	
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
   uint8_t counter = 0;
   uint8_t counterLS = 0;

   // Prototypes
   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t* payload, uint8_t length);
   
   void lsFlood();
   
   void printRTCost();
   
   void fillRT();
   
   uint8_t dijkstra(uint8_t key);
   
   error_t ping(uint16_t src, uint16_t dest, pack *message);
   
   task void BufferTask();


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
      //dbg(FLOODING_CHANNEL, "Unknown Packet Type %d\n", len);
      return msg;
	  }
   }

	
   event void CommandHandler.ping(uint16_t destination, uint8_t *payload){
      dbg(FLOODING_CHANNEL, "PING EVENT \n");
      makePack(&sendPackage, TOS_NODE_ID, destination, 255, 0, 1, payload, PACKET_MAX_PAYLOAD_SIZE);
	  //makePack(&sendPackage, TOS_NODE_ID, destination, TTL, Protocol, Seq, payload, PACKET_MAX_PAYLOAD_SIZE);
	  
      call Sender.send(sendPackage, AM_BROADCAST_ADDR);
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
			dbg(FLOODING_CHANNEL, "src: %d, NextHop: %d, Cost: %d\n", lsPack.src, lsPack.nextHop, lsPack.cost);
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

   event void CommandHandler.setTestServer(){}

   event void CommandHandler.setTestClient(){}

   event void CommandHandler.setAppServer(){}

   event void CommandHandler.setAppClient(){}
   
   
   error_t ping(uint16_t src, uint16_t dest, pack *message){
		if(!busy && isActive){
			pack* msg = (pack *)(call Packet.getPayload(&pkt, sizeof(pack) ));			
			*msg = *message;

			//TTL Check
			if(msg->TTL >0)msg->TTL--;
			else return FAIL;

			if(call AMSend.send(dest, &pkt, sizeof(pack)) ==SUCCESS){
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
	
   void compNeighbors(){
   
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
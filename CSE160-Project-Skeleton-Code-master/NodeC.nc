/**
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */


#include <Timer.h>
#include "includes/CommandMsg.h"
#include "includes/packet.h"

configuration NodeC{
}
implementation {


    components MainC;
    components Node;
	components RandomC as Random;
	components new AMSenderC(6);
    components new AMReceiverC(AM_PACK) as GeneralReceive;
	components new TimerMilliC() as timer;

    Node -> MainC.Boot;

    Node.Receive -> GeneralReceive;
	
	Node.AMSend -> AMSenderC;
	Node.Packet -> AMSenderC;
	
	Node.Random -> Random;

    components ActiveMessageC;
    Node.AMControl -> ActiveMessageC;

    components new SimpleSendC(AM_PACK);
    Node.Sender -> SimpleSendC;

    components CommandHandlerC;
    Node.CommandHandler -> CommandHandlerC;
	
	
	Node.timer -> timer;
	
	components new ListC(sendInfo, 64) as neighborListC;
	Node.neighborlist -> neighborListC;
	
	components new TimerMilliC() as timer2;
	Node.timer2 -> timer2;
	
	components new TimerMilliC() as timer3;
	Node.timer3 -> timer3;
	
	components new ListC(linkState, 64) as routingTableC;
	Node.routingTable -> routingTableC;
	
	components new ListC(uint8_t, 64) as costListC;
	Node.costList -> costListC;
	
	
	
	
}

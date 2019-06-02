from TestSim import TestSim

def main():
    # Get simulation ready to run.
    s = TestSim();

    # Before we do anything, lets simulate the network off.
    s.runTime(1);

    # Load the the layout of the network.
    s.loadTopo("long_line.topo");

    # Add a noise model to all of the motes.
    s.loadNoise("no_noise.txt");

    # Turn on all of the sensors.
    s.bootAll();

    # Add the main channels. These channels are declared in includes/channels.h
    s.addChannel(s.NEIGHBOR_CHANNEL);
    s.addChannel(s.FLOODING_CHANNEL);

    # After sending a ping, simulate a little to prevent collision.
    
    #s.ping(1, 19, "Hello, World");
    s.runTime(3);
    #s.ping(1, 5, "Hi!");
    #s.runTime(200);
    #s.neighborDMP(7);
    #s.testServer(2, "4");
    s.runTime(3);
    #s.moteOff(4);
    s.hello(4, "username 5\\r\\n");
    s.runTime(3);
    #s.runTime(100);
    #s.routeDMP(2);
    s.runTime(5);
    #s.testServer(2, "4");
    s.runTime(20);
    #s.testClient(4, "2,4,20");
    s.runTime(20);
	

	
	
	


if __name__ == '__main__':
    main()

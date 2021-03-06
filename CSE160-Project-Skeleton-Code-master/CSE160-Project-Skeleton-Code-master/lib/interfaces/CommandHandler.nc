interface CommandHandler{
   // Events
   event void ping(uint16_t destination, uint8_t *payload);
   event void printNeighbors();
   event void printRouteTable();
   event void printLinkState();
   event void printDistanceVector();
   event void setTestServer(uint8_t * port);
   event void setTestClient(uint8_t * payload);
   event void setAppServer();
   event void setAppClient();
   event void hello(uint8_t * payload);
   event void whisper(uint8_t * payload);
}

#include <stdio.h>
#include <pcap.h>
#include <string.h>
 
int main(int argc, char *argv[]) {

    if (argc != 2){
        printf("Usage: %s <interface>\n", argv[0]);
        return 1;
    }

    pcap_t *handle;
    char errbuf[PCAP_ERRBUF_SIZE];
    struct pcap_pkthdr header;
    const u_char *packet;

    handle = pcap_open_live(argv[1], BUFSIZ, 1, 1, errbuf);
    if (handle == NULL) {
        fprintf(stderr, "Couldn't open device %s: %s\n", argv[1], errbuf);
        return 1;
    }

    char buf[1024];

    int packets = 0;

    while(1) {

        int packet_size = packets % 960 + 64;

        for (size_t i=0; i<packet_size; i++)
            buf[i] = packets;

        pcap_sendpacket(handle, buf, packet_size);

        packet = pcap_next(handle, &header);

        //Packet hexdump
        //printf("Packet with length [%d]\n", header.len);
        //for (size_t i=0; i<header.len; i++){
        //    printf("%02x ", packet[i]);
        //    if (i%8 == 7)
        //        printf("\n");
        //}
        //printf("\n\n");

        if(packet_size + 4 != header.len){
            printf("Packet length mismatch: %d %d\n", packet_size, header.len);
            //return 1;
        }

        if(memcmp(packet, buf, packet_size)){
            printf("Packet contents mismatch\n");
            return 1;
        }

        packets++;
        if(packets % 0x100 == 0)
            printf("Packets looped: %d\n", packets);

    }
} 

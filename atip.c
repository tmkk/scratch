

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/disk.h>
#include <AssertMacros.h>
#include <IOKit/IOTypes.h>
#include <IOKit/storage/IOCDMediaBSDClient.h>



static IOReturn
ReadCDTableOfContents ( int fd )
{


	IOReturn			error		= kIOReturnError;
	dk_cd_read_toc_t		cdTOC;
	CDTOC *				tocData		= NULL;
	uint16_t			size		= 0;
	
	// DKIOCCDREADTOC see IOCDMedia::readTOC() in IOCDMedia.h
	/*bzero ( ( void * ) &cdTOC, sizeof ( dk_cd_read_toc_t ) );
	
	tocData = ( CDTOC * ) calloc ( 1, sizeof ( CDTOC ) );
	require ( tocData != NULL, ErrorExit );
	
	cdTOC.format			= kCDTOCFormatTOC;
	cdTOC.formatAsTime		= 0;
	cdTOC.address.session		= 0;
	cdTOC.bufferLength		= sizeof ( CDTOC );
	cdTOC.buffer			= tocData;
	
	printf("Reading number of tracks\n");
	error = ioctl(fd, DKIOCCDREADTOC, &cdTOC);
	require_noerr ( error, ErrorExit );	

	
	size = OSSwapBigToHostInt16 ( tocData->length ) + sizeof ( tocData->length );
	free ( tocData );
	tocData = ( CDTOC * ) calloc ( 1, size );
	
	cdTOC.format = kCDTOCFormatTOC;
	cdTOC.formatAsTime = 0;
	cdTOC.address.session = 0;
	cdTOC.bufferLength = size;
	cdTOC.buffer = tocData;
	
	printf("Reading all tracks\n");
	error = ioctl(fd, DKIOCCDREADTOC, &cdTOC);
	require_noerr ( error, ErrorExit );
	
	SInt32 numTracks = CDTOCGetDescriptorCount(tocData);
	printf("Num tracks: %d\n", numTracks);
	printf("Session first: %d\n", tocData->sessionFirst);
	printf("Session last: %d\n", tocData->sessionLast);
	//printf("Session last: %d\n", tocData->descriptors[0].);
	
	int i;
	for (i = 0; i < numTracks; i++)
	{
		printf("Track % 3d:", i);
		printf(" tno: % 3d", tocData->descriptors[i].tno);
		printf(" point: % 4d", tocData->descriptors[i].point);
		CDMSF msf = tocData->descriptors[i].address;
		printf(" address: %02u:%02u:%02u", msf.minute, msf.second, msf.frame);
		msf = tocData->descriptors[i].p;
		printf(" p: %02u:%02u:%02u", msf.minute, msf.second, msf.frame);
		
		printf("\n");
	}*/
	
	
	// ATIP…
	
	CDATIP* atipData = (CDATIP*) calloc(1, sizeof (CDATIP));
	atipData->dataLength = sizeof (CDATIP);
	
	cdTOC.format = kCDTOCFormatATIP;
	cdTOC.formatAsTime = 0;
	cdTOC.address.track = 0;
	cdTOC.bufferLength = sizeof (CDATIP);
	cdTOC.buffer = atipData;
	
	printf("Reading ATIP\n");
	error = ioctl ( fd, DKIOCCDREADTOC, &cdTOC );
	require_noerr ( error, ErrorExit );
	
	printf("ATIP:\n");
	printf(" dataLength: %d\n", atipData->dataLength);
	printf(" discType: %d\n", atipData->discType);
	printf(" discSubtype: %d\n", atipData->discSubType);
	printf(" ATIP Lead-in: %d:%d:%d\n", atipData->startTimeOfLeadIn.minute,atipData->startTimeOfLeadIn.second,atipData->startTimeOfLeadIn.frame);
	
	
	return 0;
	
	ErrorExit:

	printf ( "--- DKIOCCDREADTOC \t\t%d\n", error );
	
	if ( tocData != NULL )
	{
	
		free ( tocData );
		
	}
	
	return error;
	
}



int
main ( int argc, const char * argv[] )
{
	
	int		fd 	= -1;
	IOReturn	result 	= 0;
	
	if ( argc != 2 )
	{
		return -1;
	}
	
	fd = open ( argv[1], O_RDONLY );
	if ( fd == -1 )
	{
		printf ( "open failed with errno = %d\n", errno );
		return -2;
	}
	
	result = ReadCDTableOfContents ( fd );
	
	close ( fd );
	
	return 0;
	
}
#import <Foundation/Foundation.h>
#import <CoreServices/CoreServices.h>
#import <AudioUnit/AudioUnit.h>
#import <AudioToolBox/AudioToolBox.h>

typedef struct
{
	AudioUnit *unit;
	NSMutableArray *buffers;
	AudioStreamBasicDescription *asbd;
	size_t tmpBufferSize;
	void *tmpBuffer;
} sharedData;

static int end;

static void signalHandler(int sig)
{
	fprintf(stderr,"stopping\n");
	end = 1;
}

static OSStatus inputProc(
				   void *inRefCon,
				   AudioUnitRenderActionFlags *ioActionFlags,
				   const AudioTimeStamp *inTimeStamp,
				   UInt32 inBusNumber,
				   UInt32 inNumberFrames,
				   AudioBufferList * ioData)
{
	OSStatus err = noErr;
	AudioBufferList list;
	sharedData *sharedData = inRefCon;
	list.mNumberBuffers = 1;
	list.mBuffers[0].mNumberChannels = sharedData->asbd->mChannelsPerFrame;
	list.mBuffers[0].mDataByteSize = sharedData->asbd->mBytesPerFrame*inNumberFrames;
	if(sharedData->tmpBufferSize < list.mBuffers[0].mDataByteSize) {
		sharedData->tmpBuffer = (unsigned char *)realloc(sharedData->tmpBuffer,list.mBuffers[0].mDataByteSize);
		sharedData->tmpBufferSize = list.mBuffers[0].mDataByteSize;
	}
	list.mBuffers[0].mData = sharedData->tmpBuffer;
	
    err = AudioUnitRender(*sharedData->unit,
						  ioActionFlags,
						  inTimeStamp,
						  inBusNumber,
						  inNumberFrames,
						  &list);
	
	if(err == noErr) {
		NSData *data = [[NSData alloc] initWithBytes:list.mBuffers[0].mData length:list.mBuffers[0].mDataByteSize];
		@synchronized(sharedData->buffers) {
			[sharedData->buffers addObject:data];
		}
		[data release];
	}
	
    return err;
}

int main(void)
{
	AudioUnit inputUnit;
	AudioStreamBasicDescription inFormat, outFormat;
	ComponentDescription desc;
	Component comp;
	AURenderCallbackStruct  inCallback;
	UInt32 enableIO;
	UInt32 size=0;
	OSStatus	err ;
	AudioDeviceID inputDevice;
	sharedData sharedData;
	ExtAudioFileRef file;
	FSRef dirFSRef;
	
	/* Open AUHAL for input */
	desc.componentType = kAudioUnitType_Output; 
	desc.componentSubType = kAudioUnitSubType_HALOutput;
	desc.componentManufacturer = kAudioUnitManufacturer_Apple;
	desc.componentFlags = 0;
	desc.componentFlagsMask = 0;
	comp = FindNextComponent(NULL, &desc);
	if (comp == NULL) {
		fprintf(stderr, "can't find HAL output unit\n");
		return -1;
	}
	
	err = OpenAComponent(comp, &inputUnit);
	if (err)  {
		fprintf(stderr, "can't open HAL output unit\n");
		return -1;
	}
	
	/* Configure AUHAL */
	err = AudioUnitInitialize(inputUnit);
	if(err != noErr) {
		fprintf(stderr, "AudioUnitInitialize failed.\n");
		CloseComponent(inputUnit);
		return -1;
	}
	
	enableIO = 1;
	AudioUnitSetProperty(inputUnit,
						 kAudioOutputUnitProperty_EnableIO,
						 kAudioUnitScope_Input,
						 1,
						 &enableIO,
						 sizeof(enableIO));
	
	enableIO = 0;
	AudioUnitSetProperty(inputUnit,
						 kAudioOutputUnitProperty_EnableIO,
						 kAudioUnitScope_Output,
						 0,
						 &enableIO,
						 sizeof(enableIO));
	
	/* Get default input device */
	size = sizeof(AudioDeviceID);
    err = AudioHardwareGetProperty(kAudioHardwarePropertyDefaultInputDevice,
								   &size,
								   &inputDevice);
	if (err)  {
		fprintf(stderr, "can't get default input device\n");
		CloseComponent(inputUnit);
		return -1;
	}
	
	size = 100;
	char buf[100];
	err = AudioDeviceGetProperty(inputDevice, 0, false, kAudioDevicePropertyDeviceName, &size, buf);
	fprintf(stderr,"Device: %s\n",buf);
	
	err = AudioUnitSetProperty(inputUnit,
							   kAudioOutputUnitProperty_CurrentDevice,
							   kAudioUnitScope_Global,
							   0,
							   &inputDevice,
							   sizeof(inputDevice));
	if (err)  {
		fprintf(stderr, "can't set default input device\n");
		CloseComponent(inputUnit);
		return -1;
	}
	
	/* Setup input/output format */
	size = sizeof(AudioStreamBasicDescription);
	err = AudioUnitGetProperty(inputUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 1, &inFormat, &size);
	if(err != noErr) {
		fprintf(stderr, "AudioUnitGetProperty(input format) failed.\n");
		CloseComponent(inputUnit);
		return -1;
	}
	err = AudioUnitSetProperty(inputUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &inFormat, sizeof(AudioStreamBasicDescription));
	if(err != noErr) {
		fprintf(stderr, "AudioUnitSetProperty(input format) failed.\n");
		CloseComponent(inputUnit);
		return -1;
	}
	
	/* Setup callback */
	memset(&sharedData,0,sizeof(sharedData));
	sharedData.unit = &inputUnit;
	sharedData.buffers = [[NSMutableArray alloc] init];
	sharedData.asbd = &inFormat;
	memset(&inCallback, 0, sizeof(AURenderCallbackStruct));
	inCallback.inputProc = inputProc;
	inCallback.inputProcRefCon = &sharedData;
	err = AudioUnitSetProperty (inputUnit, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 0, &inCallback, sizeof(AURenderCallbackStruct));
	if(err != noErr) {
		fprintf(stderr, "AudioUnitSetProperty(input) failed.\n");
		CloseComponent(inputUnit);
		return -1;
	}
	
	/* Setup output codec */
	memset(&outFormat,0,sizeof(AudioStreamBasicDescription));
	outFormat.mFormatID = kAudioFormatAppleLossless;
	outFormat.mBitsPerChannel = 16;
	outFormat.mFormatFlags = kAppleLosslessFormatFlag_16BitSourceData;
	outFormat.mSampleRate = inFormat.mSampleRate;
	outFormat.mChannelsPerFrame = inFormat.mChannelsPerFrame;
	
	FSPathMakeRef((UInt8*)realpath(".",NULL) ,&dirFSRef,NULL);
	remove("recording.m4a");
	if(ExtAudioFileCreateNew(&dirFSRef, CFSTR("recording.m4a"), kAudioFileM4AType, &outFormat, NULL, &file) != noErr)
	{
		fprintf(stderr, "ExtAudioFileCreateNew failed.\n");
		CloseComponent(inputUnit);
		return -1;
	}
	
	if(ExtAudioFileSetProperty(file, kExtAudioFileProperty_ClientDataFormat, sizeof(AudioStreamBasicDescription), &inFormat) != noErr) {
		fprintf(stderr, "ExtAudioFileSetProperty failed.\n");
		CloseComponent(inputUnit);
		ExtAudioFileDispose(file);
		return -1;
	}
	
	/* register signal handler */
	signal(SIGINT, signalHandler);
	signal(SIGHUP, signalHandler);
	
	/* start recording */
	AudioOutputUnitStart(inputUnit);
	
	while(!end)
	{
		NSArray *buffers = nil;
		@synchronized(sharedData.buffers) {
			if([sharedData.buffers count]) {
				buffers = [[NSArray alloc] initWithArray:sharedData.buffers];
				[sharedData.buffers removeAllObjects];
			}
		}
		if(buffers) {
			int i;
			AudioBufferList list;
			for(i=0;i<[buffers count];i++) {
				list.mNumberBuffers = 1;
				list.mBuffers[0].mNumberChannels = inFormat.mChannelsPerFrame;
				list.mBuffers[0].mDataByteSize = [[buffers objectAtIndex:i] length];
				list.mBuffers[0].mData = (void *)[[buffers objectAtIndex:i] bytes];
				if((err = ExtAudioFileWrite(file, list.mBuffers[0].mDataByteSize/inFormat.mBytesPerFrame, &list)) != noErr) {
					fprintf(stderr, "ExtAudioFileWrite failed.\n");
					goto last;
				}
			}
			
			[buffers release];
		}
		else {
			usleep(10000);
		}
	}
	
  last:
	AudioOutputUnitStop(inputUnit);
	CloseComponent(inputUnit);
	ExtAudioFileDispose(file);
	
	return 0;
}

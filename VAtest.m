#import <VideoDecodeAcceleration/VDADecoder.h>
#import <Cocoa/Cocoa.h>

enum {
	kVDADecodeInfo_FrameDropped = 1UL << 1,
};

// tracks a frame in and output queue in display order
typedef struct myDisplayFrame {
    int64_t                 frameDisplayTime;
    CVPixelBufferRef        frame;
    struct myDisplayFrame   *nextFrame;
} myDisplayFrame, *myDisplayFramePtr;

// some user data
typedef struct MyUserData 
{
    myDisplayFramePtr displayQueue; // display-order queue - next display frame is always at the queue head
    int32_t           queueDepth; // we will try to keep the queue depth around 10 frames
    pthread_mutex_t   queueMutex; // mutex protecting queue manipulation
} MyUserData, *MyUserDataPtr;

// example helper function that wraps a time into a dictionary
static CFDictionaryRef MakeDictionaryWithDisplayTime(int64_t inFrameDisplayTime)
{
    CFStringRef key = CFSTR("MyFrameDisplayTimeKey");
    CFNumberRef value = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt64Type, &inFrameDisplayTime);

    return CFDictionaryCreate(kCFAllocatorDefault,
                              (const void **)&key,
                              (const void **)&value,
                              1,
                              &kCFTypeDictionaryKeyCallBacks,
                              &kCFTypeDictionaryValueCallBacks);
}

// example helper function to extract a time from our dictionary
static int64_t GetFrameDisplayTimeFromDictionary(CFDictionaryRef inFrameInfoDictionary)
{
    CFNumberRef timeNumber = NULL;
    int64_t outValue = 0;

    if (NULL == inFrameInfoDictionary) return 0;

    timeNumber = CFDictionaryGetValue(inFrameInfoDictionary, CFSTR("MyFrameDisplayTimeKey"));
    if (timeNumber) CFNumberGetValue(timeNumber, kCFNumberSInt64Type, &outValue);

    return outValue;
}

void myDecoderOutputCallback(void               *decompressionOutputRefCon,
                             CFDictionaryRef    frameInfo,
                             OSStatus           status, 
                             uint32_t           infoFlags,
                             CVImageBufferRef   imageBuffer)
{
    MyUserDataPtr myUserData = (MyUserDataPtr)decompressionOutputRefCon;

    myDisplayFramePtr newFrame = NULL;
    myDisplayFramePtr queueWalker = myUserData->displayQueue;

    if (NULL == imageBuffer) {
        printf("myDecoderOutputCallback - NULL image buffer!\n");
        if (kVDADecodeInfo_FrameDropped & infoFlags) {
            printf("myDecoderOutputCallback - frame dropped!\n");
        }
        return;
    }

    if ('2vuy' != CVPixelBufferGetPixelFormatType(imageBuffer)) {
        printf("myDecoderOutputCallback - image buffer format not '2vuy'!\n");
        return;
    }

    // allocate a new frame and populate it with some information
    // this pointer to a myDisplayFrame type keeps track of the newest decompressed frame
    // and is then inserted into a linked list of  frame pointers depending on the display time
    // parsed out of the bitstream and stored in the frameInfo dictionary by the client
    newFrame = calloc(sizeof(myDisplayFrame), 1);
    newFrame->frame = CVBufferRetain(imageBuffer);
    newFrame->frameDisplayTime = GetFrameDisplayTimeFromDictionary(frameInfo);

    // since the frames we get may be in decode order rather than presentation order
    // our hypothetical callback places them in a queue of frames which will
    // hold them in display order for display on another thread
    pthread_mutex_lock(&myUserData->queueMutex);

    if (!queueWalker || (newFrame->frameDisplayTime < queueWalker->frameDisplayTime)) {
        // we have an empty queue, or this frame earlier than the current queue head
        newFrame->nextFrame = queueWalker;
        myUserData->displayQueue = newFrame;
    } else {
        // walk the queue and insert this frame where it belongs in display order
        Boolean         frameInserted = false;
        myDisplayFramePtr nextFrame = NULL;

        while (!frameInserted) {
            nextFrame = queueWalker->nextFrame;
            if (!nextFrame || (newFrame->frameDisplayTime < nextFrame->frameDisplayTime)) {
                // if the next frame is the tail of the queue, or our new frame is ealier
                newFrame->nextFrame = nextFrame;
                queueWalker->nextFrame = newFrame;
                frameInserted = true;
            }
            queueWalker = nextFrame;
        }
    }

    myUserData->queueDepth++;

    pthread_mutex_unlock(&myUserData->queueMutex);
}

OSStatus CreateDecoder(SInt32 inHeight, SInt32 inWidth,
                       OSType inSourceFormat, CFDataRef inAVCCData,
                       VDADecoder *decoderOut)
{
    OSStatus status;

    CFMutableDictionaryRef decoderConfiguration = NULL;
    CFMutableDictionaryRef destinationImageBufferAttributes = NULL;
    CFDictionaryRef emptyDictionary; 

    CFNumberRef height = NULL;
    CFNumberRef width= NULL;
    CFNumberRef sourceFormat = NULL;
    CFNumberRef pixelFormat = NULL; 

    // source must be H.264
    if (inSourceFormat != 'avc1') {
        fprintf(stderr, "Source format is not H.264!\n");
        return paramErr;
    }

    // the avcC data chunk from the bitstream must be present
    if (inAVCCData == NULL) {
        fprintf(stderr, "avc1 decoder configuration data cannot be NULL!\n");
        return paramErr;
    }

    // create a CFDictionary describing the source material for decoder configuration
    decoderConfiguration = CFDictionaryCreateMutable(kCFAllocatorDefault,
                                                     4,
                                                     &kCFTypeDictionaryKeyCallBacks,
                                                     &kCFTypeDictionaryValueCallBacks);

    height = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &inHeight);
    width = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &inWidth);
    sourceFormat = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &inSourceFormat);

    CFDictionarySetValue(decoderConfiguration, kVDADecoderConfiguration_Height, height);
    CFDictionarySetValue(decoderConfiguration, kVDADecoderConfiguration_Width, width);
    CFDictionarySetValue(decoderConfiguration, kVDADecoderConfiguration_SourceFormat, sourceFormat);
    CFDictionarySetValue(decoderConfiguration, kVDADecoderConfiguration_avcCData, inAVCCData);

    // create a CFDictionary describing the wanted destination image buffer
    destinationImageBufferAttributes = CFDictionaryCreateMutable(kCFAllocatorDefault,
                                                                 2,
                                                                 &kCFTypeDictionaryKeyCallBacks,
                                                                 &kCFTypeDictionaryValueCallBacks);

    OSType cvPixelFormatType = kCVPixelFormatType_422YpCbCr8;
    pixelFormat = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &cvPixelFormatType);
    emptyDictionary = CFDictionaryCreate(kCFAllocatorDefault, // our empty IOSurface properties dictionary
                                         NULL,
                                         NULL,
                                         0,
                                         &kCFTypeDictionaryKeyCallBacks,
                                         &kCFTypeDictionaryValueCallBacks);

    CFDictionarySetValue(destinationImageBufferAttributes, kCVPixelBufferPixelFormatTypeKey, pixelFormat);
    CFDictionarySetValue(destinationImageBufferAttributes,
                         kCVPixelBufferIOSurfacePropertiesKey,
                         emptyDictionary);

    // create the hardware decoder object
    status = VDADecoderCreate(decoderConfiguration,
                              destinationImageBufferAttributes, 
                              (VDADecoderOutputCallback*)myDecoderOutputCallback,
                              NULL,
                              decoderOut);

	if (kVDADecoderNoErr != status) {
		perror("VDADecoderCreate");
        fprintf(stderr, "VDADecoderCreate failed. err: %d\n", status);
    }

    if (decoderConfiguration) CFRelease(decoderConfiguration);
    if (destinationImageBufferAttributes) CFRelease(destinationImageBufferAttributes);
    if (emptyDictionary) CFRelease(emptyDictionary);

    return status;
}

int main(void)
{
	VDADecoder *decoder;
	NSData *data = [[NSData alloc] initWithContentsOfFile:@"/Users/tmkk/src/MyProg/raw.264"];
	CreateDecoder(1920,1080,'avc1',(CFDataRef)data,decoder);
	return 0;
}
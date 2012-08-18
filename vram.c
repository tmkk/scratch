#include <IOKit/graphics/IOGraphicsLib.h>
#include <CoreFoundation/CoreFoundation.h>
#include <ApplicationServices/ApplicationServices.h>

CFDictionaryRef videoDeviceProperties(void)
{

    kern_return_t krc;  
    mach_port_t masterPort;
    krc = IOMasterPort(bootstrap_port, &masterPort);
    if (krc == KERN_SUCCESS) 
    {
        CFMutableDictionaryRef pattern = IOServiceMatching(kIOAcceleratorClassName);
        //CFShow(pattern);

        io_iterator_t deviceIterator;
        krc = IOServiceGetMatchingServices(masterPort, pattern, &deviceIterator);
        if (krc == KERN_SUCCESS) 
        {
            io_object_t object;
            while ((object = IOIteratorNext(deviceIterator))) 
            {
                CFMutableDictionaryRef properties = NULL;
                krc = IORegistryEntryCreateCFProperties(object, &properties, kCFAllocatorDefault, (IOOptionBits)0);
                if (krc == KERN_SUCCESS) 
                {
                    CFMutableDictionaryRef perf_properties = (CFMutableDictionaryRef) CFDictionaryGetValue( properties, CFSTR("PerformanceStatistics") );
                    //CFShow(perf_properties);
					if(perf_properties) return perf_properties;
                }
                if (properties) CFRelease(properties);
                IOObjectRelease(object);
            }           
            IOObjectRelease(deviceIterator);
        }
    }
    return 0; // when we come here, this is a fail 
}

int main(void)
{
	int32_t vram = 0;
	CGDisplayCount        dspCount = 0;
	CGDirectDisplayID    *displays = NULL;
	CGGetActiveDisplayList(0, NULL, &dspCount);
	displays = calloc((size_t)dspCount, sizeof(CGDirectDisplayID));
	CGGetActiveDisplayList(dspCount, displays, &dspCount);
	int i;
	for(i=0;i<dspCount;i++) {
		io_service_t port = CGDisplayIOServicePort(displays[i]);
		CFTypeRef classCode = IORegistryEntryCreateCFProperty(port, CFSTR (kIOFBMemorySizeKey), kCFAllocatorDefault, kNilOptions);
		if (CFGetTypeID(classCode) == CFNumberGetTypeID()) {
			int32_t tmp;
 			CFNumberGetValue(classCode, kCFNumberSInt32Type, &tmp);
			vram += tmp;
 		}
	}

	CFDictionaryRef dic =  videoDeviceProperties();
	CFNumberRef vramFreeBytes = CFDictionaryGetValue(dic, CFSTR("vramFreeBytes"));
	CFNumberRef textureCount = CFDictionaryGetValue(dic, CFSTR("textureCount"));
	int64_t free;
	int32_t texture;
 	if(vramFreeBytes) CFNumberGetValue(vramFreeBytes, kCFNumberSInt64Type, &free);
	if(textureCount) CFNumberGetValue(textureCount, kCFNumberSInt32Type, &texture);
	fprintf(stderr,"VRAM: %d MiB total (in %d screens), %lld MiB free\n%d textures in memory\n",vram/1024/1024,dspCount,free/1024/1024,texture);
	return 0;
}


#include <AudioToolbox/AudioToolbox.h>
#include <CoreServices/CoreServices.h>
#include <dlfcn.h>
#include <stdio.h>

int main(void)
{
	ComponentDescription cd;
	cd.componentType = kAudioEncoderComponentType;
	cd.componentSubType = 'aach';
	cd.componentManufacturer = kAudioUnitManufacturer_Apple;
	cd.componentFlags = 0;
	cd.componentFlagsMask = 0;
	ComponentResult (*ComponentRoutine) (ComponentParameters * cp, Handle componentStorage);
	void *handle = dlopen("/System/Library/Components/AudioCodecs.component/Contents/MacOS/AudioCodecs",RTLD_LAZY|RTLD_LOCAL);
	if(handle) {
		ComponentRoutine = dlsym(handle,"ACMP4AACHighEfficiencyEncoderEntry");
		if(ComponentRoutine) {
			RegisterComponent(&cd,ComponentRoutine,0,NULL,NULL,NULL);
		}
	}
	
	unsigned int ver = CallComponentVersion((ComponentInstance)FindNextComponent(NULL, &cd));
	fprintf(stderr,"AAC HE: %d.%d.%d\n",ver>>16,(ver>>8)&0xff,ver&0xff);
	cd.componentSubType = 'aac ';
	ver = CallComponentVersion((ComponentInstance)FindNextComponent(NULL, &cd));
	fprintf(stderr,"AAC LC: %d.%d.%d\n",ver>>16,(ver>>8)&0xff,ver&0xff);
	
	return 0;
}
#include <stdio.h>
#include <OpenGL/OpenGL.h>

int main(void)
{
	int i;
	CGLRendererInfoObj rend;
	GLint nrend,value;
	CGLQueryRendererInfo(0xffffffff,&rend,&nrend);
	for(i=0;i<nrend;i++) {
		CGLDescribeRenderer(rend,i,kCGLRPRendererID,&value);
		printf("0x%08x\n",value);
	}
	return 0;
}


#include <math.h>
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char *argv[])
{
	float input = atof(argv[1]);
	float ideal = powf(input,4.0f/3.0f);
	
	printf("ideal dequantized value: %f\n",ideal);
	printf("dequantized value if quantized as %.1f: %f (error %f)\n",floorf(input),powf(floorf(input),4.0f/3.0f),fabsf(ideal-powf(floorf(input),4.0f/3.0f)));
	printf("dequantized value if quantized as %.1f: %f (error %f)\n",ceilf(input),powf(ceilf(input),4.0f/3.0f),fabsf(ideal-powf(ceilf(input),4.0f/3.0f)));
	
	float mid = powf(0.5f*(powf(floorf(input),4.0f/3.0f) + powf(floorf(input)+1.0f,4.0f/3.0f)),0.75f);
	float adj = floorf(input)+1.0f - mid;
	printf("recommended quantized value: %.0f (mid = %f, adj = %f)\n",floor(input+adj),mid,adj);
	
	return 0;
}
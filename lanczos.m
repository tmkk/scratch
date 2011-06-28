#import <Cocoa/Cocoa.h>
#import <math.h>
#define PI 3.1415926535897932385
#define PI_THIRD 1.04719755119659774616
#define PI_POW 9.86960440108935861906

int beforeX,beforeY,afterX,afterY;

static inline float lanczos(int n, float delta)
{
	return n*sin(delta*PI)*sin(delta*PI/n)/(PI_POW*delta*delta);
}

static inline float lanczos3_approx(float delta)
{
	delta = fabs(delta);
	float delta2 = delta * delta;
	if(delta <= 1.0f) {
		return 1.0f + delta2*(-2.36338f+1.36338*delta);
	}
	else if(delta < 2.0f) {
		return 2.54648f - delta * 5.09296f + delta2*(3.1831-0.63662*delta);
	}
	return 0;
}

static inline void lanczos_round(int x, int y, int starty, int endy, float y0, float *coeffs_x, float *coeffs_y, float ratio, unsigned char *before, unsigned char *after, int spp, int width, int height, int bpr, int widthAfter,int lanczos_n)
{
	float pixel[4];
	pixel[0] = pixel[1] = pixel[2] = pixel[3] = 0.0f;
	int startx = (int)((x-lanczos_n+0.5f)/ratio-0.5f);
	int endx = (int)((x+lanczos_n+0.5f)/ratio-0.5f);
	if(startx<0) startx = 0;
	if(endx>=width) endx = width-1;
	int i,j,k;

	float coeff_sum = 0;
	for(i=starty;i<=endy;i++) {
		float coeffy = coeffs_y[i-starty];
		for(j=startx;j<=endx;j++) {
			float coeff = coeffs_x[j-startx]*coeffy;
			for(k=0;k<spp;k++) {
				pixel[k] += before[bpr*i+j*spp+k]*coeff;
			}
			coeff_sum += coeff;
		}
	}
	for(i=0;i<spp;i++) {
		pixel[i] /= coeff_sum;
		if(pixel[i] > 255) pixel[i] = 255;
		after[spp*(widthAfter*y+x)+i] = round(pixel[i]);
	}
}

static inline float bicubic(float delta)
{
	delta = fabs(delta);
	float delta2 = delta*delta;
	if(delta <=1.0f) {
		return 1.0f+delta2*(-2.0f+delta);
	}
	else if(delta < 2.0f) {
		return 4.0f-8.0f*delta+delta2*(5.0f-delta);
	}
	return 0.0f;
}

static inline void bicubic_round(int x, int y, float ratio, unsigned char *before, unsigned char *after, int spp, int width, int height, int bpr, int widthAfter)
{
	float pixel[4];
	pixel[0] = pixel[1] = pixel[2] = pixel[3] = 0.0f;
	int startx = (int)((x-2+0.5f)/ratio-0.5f);
	int endx = (int)((x+2+0.5f)/ratio-0.5f);
	int starty = (int)((y-2+0.5f)/ratio-0.5f);
	int endy = (int)((y+2+0.5f)/ratio-0.5f);
	if(startx<0) startx = 0;
	if(starty<0) starty = 0;
	if(endx>=width) endx = width-1;
	if(endy>=height) endy = height-1;
	float x0 = (x+0.5f)/ratio-0.5f;
	float y0 = (y+0.5f)/ratio-0.5f;
	int i,j,k;

	float *coeffs_x = malloc(sizeof(float)*(endx-startx+1));
	for(j=startx;j<=endx;j++) {
		float dx = (j-x0)*ratio;
		coeffs_x[j-startx] = bicubic(dx);
	}
	//float *coeffs_y = malloc(sizeof(float)*(endy-starty+1));

	float coeff_sum = 0;
	for(i=starty;i<=endy;i++) {
		float dy = (i-y0)*ratio;
		float coeffy = bicubic(dy);
		for(j=startx;j<=endx;j++) {
			float coeff = coeffs_x[j-startx]*coeffy;
			for(k=0;k<spp;k++) {
				pixel[k] += before[bpr*i+j*spp+k]*coeff;
			}
			coeff_sum += coeff;
		}
	}
	for(i=0;i<spp;i++) {
		pixel[i] /= coeff_sum;
		if(pixel[i] > 255) pixel[i] = 255;
		after[spp*(widthAfter*y+x)+i] = round(pixel[i]);
	}
	free(coeffs_x);
}

static inline float spline36(float delta)
{
	delta = fabs(delta);
	float delta2 = delta*delta;
	if(delta <=1.0f) {
		return 1.0f-3.0f*delta/209.0f+delta2*(-454.0f/209.0f+13.0f*delta/11.0f);
	}
	else if(delta <= 2.0f) {
		return 540.0f/209.0f-1038.0f*delta/209.0f+delta2*(612.0f/209.0f-6.0f*delta/11.0f);
	}
	else if(delta < 3.0f) {
		return -384.0f/209.0f+434.0f*delta/209.0f+delta2*(-159.0f/209.0f+delta/11.0f);
	}
	return 0.0f;
}

static inline void spline36_round(int x, int y, float ratio, unsigned char *before, unsigned char *after, int spp, int width, int height, int bpr, int widthAfter)
{
	float pixel[4];
	pixel[0] = pixel[1] = pixel[2] = pixel[3] = 0.0f;
	int startx = (int)((x-3+0.5f)/ratio-0.5f);
	int endx = (int)((x+3+0.5f)/ratio-0.5f);
	int starty = (int)((y-3+0.5f)/ratio-0.5f);
	int endy = (int)((y+3+0.5f)/ratio-0.5f);
	if(startx<0) startx = 0;
	if(starty<0) starty = 0;
	if(endx>=width) endx = width-1;
	if(endy>=height) endy = height-1;
	float x0 = (x+0.5f)/ratio-0.5f;
	float y0 = (y+0.5f)/ratio-0.5f;
	int i,j,k;

	float *coeffs_x = malloc(sizeof(float)*(endx-startx+1));
	for(j=startx;j<=endx;j++) {
		float dx = (j-x0)*ratio;
		coeffs_x[j-startx] = spline36(dx);
	}
	//float *coeffs_y = malloc(sizeof(float)*(endy-starty+1));

	float coeff_sum = 0;
	for(i=starty;i<=endy;i++) {
		float dy = (i-y0)*ratio;
		float coeffy = spline36(dy);
		for(j=startx;j<=endx;j++) {
			float coeff = coeffs_x[j-startx]*coeffy;
			for(k=0;k<spp;k++) {
				pixel[k] += before[bpr*i+j*spp+k]*coeff;
			}
			coeff_sum += coeff;
		}
	}
	for(i=0;i<spp;i++) {
		pixel[i] /= coeff_sum;
		if(pixel[i] > 255) pixel[i] = 255;
		after[spp*(widthAfter*y+x)+i] = round(pixel[i]);
	}
	free(coeffs_x);
}

void setPixelAtX(int x, int y, double ratio, unsigned char *before, unsigned char *after, int spp)
{
	int i,j;
	double *coeff,coeff_sum=0;
	double pixel[4];
	int startx = floor((x-2)/ratio+1) - 1;
	int endx = ceil((x+4)/ratio-1) - 1;
	if(startx < 0) startx = 0;
	if(endx > beforeX-1) endx = beforeX-1;
	pixel[0] = pixel[1] = pixel[2] = pixel[3] = 0;
	coeff = (double *)malloc(sizeof(double)*(endx-startx+1));
	
	for(i=startx;i<=endx;i++) {
		double scaled = (i+1)*ratio-1;
		coeff[i-startx] = (scaled-x) == 0 ? 1 : 3*sin(PI*(scaled-x))*sin(PI_THIRD*(scaled-x))/(PI_POW*(scaled-x)*(scaled-x));
		coeff_sum += coeff[i-startx];
	}
	coeff_sum = 1/coeff_sum;
	for(i=startx;i<=endx;i++) {
		for(j=0;j<spp;j++) {
			pixel[j] += before[i*spp+j] * coeff[i-startx]*coeff_sum;
			//if(x == 162 && y==86) printf("%f\n",pixel[j]);
		}
	}
	for(i=0;i<spp;i++) {
		if(pixel[i] > 255) after[x*spp+i] = 255;
		else if(pixel[i] < 0) after[x*spp+i] = 0;
		else after[x*spp+i] = (unsigned char)round(pixel[i]);
	}
	//for(i=0;i<spp;i++) after[x*spp+i] = before[(int)round(spp*((x+1)/ratio-1))+i];
	/*if(x == 162 && y==86) {
		printf("%f,%d,%d,%d,%d,%d,%d\n",coeff_sum,before[(int)round(spp*((x+1)/ratio-1))],before[(int)round(spp*((x+1)/ratio-1))+1],before[(int)round(spp*((x+1)/ratio-1))+2],after[x*spp],after[x*spp+1],after[x*spp+2]);
		for(i=startx;i<=endx;i++) printf("%f,%d,%d,%d\n",coeff[i-startx],before[i*spp],before[i*spp+1],before[i*spp+2]);
	}*/
	free(coeff);
}

void setPixelAtY(int x, int y, double ratio, unsigned char *before, unsigned char *after, int spp)
{
	int i,j;
	double *coeff,coeff_sum=0;
	double pixel[4];
	int starty = floor((y-2)/ratio+1) - 1;
	int endy = ceil((y+4)/ratio-1) - 1;
	if(starty < 0) starty = 0;
	if(endy > beforeY-1) endy = beforeY-1;
	coeff = (double *)malloc(sizeof(double)*(endy-starty+1));
	pixel[0] = pixel[1] = pixel[2] = pixel[3] = 0;
	
	for(i=starty;i<=endy;i++) {
		double scaled = (i+1)*ratio-1;
		coeff[i-starty] = (scaled-y) == 0 ? 1 : 3*sin(PI*(scaled-y))*sin(PI_THIRD*(scaled-y))/(PI_POW*(scaled-y)*(scaled-y));
		coeff_sum += coeff[i-starty];
	}
	coeff_sum = 1/coeff_sum;
	for(i=starty;i<=endy;i++) {
		for(j=0;j<spp;j++) pixel[j] += before[(i*afterX+x)*spp+j] * coeff[i-starty]*coeff_sum;
	}
	for(i=0;i<spp;i++) {
		if(pixel[i] > 255) after[(y*afterX+x)*spp+i] = 255;
		else if(pixel[i] < 0) after[(y*afterX+x)*spp+i] = 0;
		else after[(y*afterX+x)*spp+i] = (unsigned char)round(pixel[i]);
	}
	free(coeff);
	
	//for(i=0;i<spp;i++) after[(y*afterX+x)*spp+i] = before[((int)round((y+1)/ratio-1)*afterX+x)*spp+i];
}

int main(int argc, char *argv[])
{
	NSApplicationLoad();
	int i,j,k;
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSImage *img = [[NSImage alloc] initWithContentsOfFile:[NSString stringWithUTF8String:argv[1]]];
	double scale = atof(argv[2]);
	if(0) {
		int beforeX,beforeY,afterX,afterY;
		[img setCacheMode:NSImageCacheNever];
		NSImageRep *rep = [img bestRepresentationForDevice:nil];
		
		beforeX = [rep pixelsWide];
		beforeY = [rep pixelsHigh];
		afterX = beforeX*scale;
		afterY = beforeY*scale;
		
		NSRect targetImageFrame = NSMakeRect(0,0,afterX,afterY);
		NSImage *image = [[NSImage alloc] initWithSize:targetImageFrame.size];
		[image setCacheMode:NSImageCacheNever];
		[image lockFocus];
		[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
		[rep drawInRect: targetImageFrame];
		[image unlockFocus];
		NSData *data = [image TIFFRepresentation];
    	NSBitmapImageRep *bitmapImageRep = [NSBitmapImageRep imageRepWithData:data];
		data = [bitmapImageRep representationUsingType: NSPNGFileType properties: nil];
		[data writeToFile: @"test_cocoa.png" atomically: NO];
		//return 0;
	}
	NSBitmapImageRep *rep = [NSBitmapImageRep imageRepWithData:[img TIFFRepresentation]];
	//NSBitmapImageRep *rep = [NSBitmapImageRep imageRepWithData:[NSData dataWithContentsOfFile:[NSString stringWithUTF8String:argv[1]]]];
	
	
	int spp = [rep samplesPerPixel];
	int bpp = [rep bitsPerPixel]/8;
	beforeX = [rep pixelsWide];
	beforeY = [rep pixelsHigh];
	afterX = beforeX*scale;
	afterY = beforeY*scale;
	printf("%ld,%ld,%ld,%ld,%d,%d,%d,%d\n",[rep bitsPerPixel],[rep samplesPerPixel],[rep bytesPerPlane],[rep bytesPerRow],beforeX,beforeY,afterX,afterY);
	
	unsigned char *after_tmp = (unsigned char*)malloc(afterX*beforeY*bpp);
	unsigned char *after = (unsigned char*)malloc(afterX*afterY*bpp);
	
	/*for(i=0;i<beforeY;i++) {
		for(j=0;j<afterX;j++) {
			setPixelAtX(j,i,scale,[rep bitmapData]+i*[rep bytesPerRow],after_tmp+i*afterX*bpp,[rep samplesPerPixel]);
		}
	}
	for(i=0;i<afterY;i++) {
		for(j=0;j<afterX;j++) {
			setPixelAtY(j,i,scale,after_tmp,after,[rep samplesPerPixel]);
		}
	}
	printf("%d,%d\n",i,afterY);*/
#if 1
	int lanczos_n = 3;
	float **coeffs_x = malloc(sizeof(float*)*afterX);
	for(j=0;j<afterX;j++) {
		int startx = (int)((j-lanczos_n+0.5f)/scale-0.5f);
		int endx = (int)((j+lanczos_n+0.5f)/scale-0.5f);
		if(startx<0) startx = 0;
		if(endx>=beforeX) endx = beforeX-1;
		float x0 = (j+0.5f)/scale-0.5f;
		coeffs_x[j] = malloc(sizeof(float)*(endx-startx+1));
		for(k=startx;k<=endx;k++) {
			float dx = (k-x0)*scale;
			//*(coeffs_x[j]+k-startx) = lanczos(lanczos_n,dx);
			*(coeffs_x[j]+k-startx) = lanczos3_approx(dx);
		}
		
	}

	for(i=0;i<afterY;i++) {
		int starty = (int)((i-lanczos_n+0.5f)/scale-0.5f);
		int endy = (int)((i+lanczos_n+0.5f)/scale-0.5f);
		if(starty<0) starty = 0;
		if(endy>=beforeY) endy = beforeY-1;
		float y0 = (i+0.5f)/scale-0.5f;
		float *coeffs_y = malloc(sizeof(float)*(endy-starty+1));
		for(k=starty;k<=endy;k++) {
			float dy = (k-y0)*scale;
			//coeffs_y[k-starty] = lanczos(lanczos_n,dy);
			coeffs_y[k-starty] = lanczos3_approx(dy);
		}
		for(j=0;j<afterX;j++) {
			lanczos_round(j,i,starty,endy,y0,coeffs_x[j],coeffs_y,scale,[rep bitmapData],after,[rep samplesPerPixel],beforeX,beforeY,[rep bytesPerRow],afterX,lanczos_n);
			//lanczos_round(j,i,scale,[rep bitmapData],after,[rep samplesPerPixel],beforeX,beforeY,[rep bytesPerRow],afterX,lanczos_n);
			//bicubic_round(j,i,scale,[rep bitmapData],after,[rep samplesPerPixel],beforeX,beforeY,[rep bytesPerRow],afterX);
		}
		//fprintf(stderr,"%d/%d\n",i,afterY);
	}
#else
	for(i=0;i<afterY;i++) {
		for(j=0;j<afterX;j++) {
			//bicubic_round(j,i,scale,[rep bitmapData],after,[rep samplesPerPixel],beforeX,beforeY,[rep bytesPerRow],afterX);
			spline36_round(j,i,scale,[rep bitmapData],after,[rep samplesPerPixel],beforeX,beforeY,[rep bytesPerRow],afterX);
		}
		//fprintf(stderr,"%d/%d\n",i,afterY);
	}
#endif
	unsigned char *planes[1];
	planes[0] = after;
	NSBitmapImageRep *imgRep = [[NSBitmapImageRep alloc]
			initWithBitmapDataPlanes: planes
			pixelsWide: afterX
			pixelsHigh: afterY
			bitsPerSample: 8
			samplesPerPixel: [rep samplesPerPixel]
			hasAlpha: NO
			isPlanar: NO
			colorSpaceName: [rep samplesPerPixel] == 1 ? NSDeviceWhiteColorSpace : NSDeviceRGBColorSpace
			bytesPerRow: afterX*[rep samplesPerPixel]
			bitsPerPixel: [rep bitsPerPixel]];
	
	NSData *data = [imgRep representationUsingType: NSPNGFileType properties: nil];
	[data writeToFile: @"test.png" atomically: NO];
	[imgRep release];
#if 0
	NSRect targetImageFrame = NSMakeRect(0,0,afterX,afterY);
	NSImage *targetImage = [[NSImage alloc] initWithSize:targetImageFrame.size];
	[targetImage lockFocus];
	[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
	[rep drawInRect: targetImageFrame];
	[targetImage unlockFocus];
	NSBitmapImageRep *newRep = [NSBitmapImageRep imageRepWithData:[targetImage TIFFRepresentation]];
	NSData *data = [newRep representationUsingType: NSPNGFileType properties: nil];
	[data writeToFile: @"test2.png" atomically: NO];
	
	double alpha = 0.3;
	double step = (1-alpha)*3.0/afterY;
	unsigned char *after = (unsigned char*)malloc(afterX*afterY*(bpp+1));
	unsigned char *src = [newRep bitmapData];
	for(i=0;i<afterY;i++) {
		for(j=0;j<afterX;j++) {
			for(k=0;k<spp;k++) {
				/*int tmp = src[spp*(afterX*(afterY-i-1)+j)+k]*(1-alpha)+255*alpha;
				if(tmp>255) tmp = 255;*/
				after[(spp+1)*(afterX*i+j)+k] = src[spp*(afterX*(afterY-i-1)+j)+k];
			}
			after[(spp+1)*(afterX*i+j)+k] = 0;
		}
		alpha += step;
	}
	
	unsigned char *planes[1];
	planes[0] = after;
	NSBitmapImageRep *imgRep = [[NSBitmapImageRep alloc]
			initWithBitmapDataPlanes: planes
			pixelsWide: afterX
			pixelsHigh: afterY
			bitsPerSample: 8
			samplesPerPixel: 4
			hasAlpha: YES
			isPlanar: NO
			colorSpaceName: @"NSCalibratedRGBColorSpace"
			bytesPerRow: afterX*4
			bitsPerPixel: 32];
	
	data = [imgRep representationUsingType: NSPNGFileType properties: nil];
	//data = [imgRep TIFFRepresentation];
	[data writeToFile: @"test3.png" atomically: NO];
	[imgRep release];
#endif
	[img release];
	[pool release];
	return 0;
}


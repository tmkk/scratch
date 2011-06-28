#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

int main(int argc,char *argv[])
{
    NSApplicationLoad();
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    int i;
    const float dpi = 150;
    NSString *target = [NSString stringWithUTF8String:argv[1]];
    PDFDocument *doc = [[PDFDocument alloc] initWithData:[NSData dataWithContentsOfFile:target]];
    for(i=0;i<[doc pageCount];i++) {
        NSAutoreleasePool *pool2 = [[NSAutoreleasePool alloc] init];
        NSImage *img = [[NSImage alloc] initWithData:[[doc pageAtIndex:i] dataRepresentation]];
        [img setScalesWhenResized:YES];
        NSSize origSize = [img size];
        NSSize newSize;
        //printf("%f,%f,%d,%d\n",origSize.width,origSize.height,[[img bestRepresentationForDevice:nil] pixelsWide],[[img bestRepresentationForDevice:nil] pixelsHigh]);
        newSize.width = origSize.width * dpi / 72.0;
        newSize.height = origSize.height * dpi / 72.0;
        [img setSize:newSize];
        NSBitmapImageRep *rep = [NSBitmapImageRep imageRepWithData:[img TIFFRepresentation]];
        [img release];
        [rep setSize:origSize];
        NSData *jpg = [rep representationUsingType:NSJPEGFileType properties:nil];
        [jpg writeToFile:[NSString stringWithFormat:@"%@_%d.jpg",[target stringByDeletingPathExtension],i] atomically:YES];
        [pool2 release];
    }
    [doc release];
    [pool release];
    return 0;
}
#import <Foundation/Foundation.h>

int main(void)
{
    char drive[100];
    int offset;
    int confidence;
    int state = 0;
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
    {
        NSMutableData *dat = [[NSMutableData alloc] init];
        NSData *dat1 = [NSData dataWithContentsOfURL:[NSURL URLWithString:@"http://www.accuraterip.com/driveoffsets.htm"]];
      [dat appendData:dat1];
        NSString *str = [[NSString alloc] initWithData:dat encoding:NSWindowsCP1252StringEncoding];
        NSLog(@"%d,%d",[dat length],[str length]);
        [dat release];
        
        NSString* parsedString;
        NSRange range, subrange;
        int length;
        
        length = [str length];
        range = NSMakeRange(0, length);
        while(range.length > 0) {
            subrange = [str lineRangeForRange:NSMakeRange(range.location, 0)];
            parsedString = [str substringWithRange:subrange];
            
            const char *s = [parsedString UTF8String];
            //printf("%s\n",s);
            if(state == 0 && !strncmp(s,"<td bgcolor=\"#F",15)) {
                if(s[50] != ',') {
                    char tmp[100];
                    int i=50;
                    while(s[i] != '<') {
                        tmp[i-50] = s[i];
                        i++;
                    }
                    tmp[i-50] = 0;
                    i=0;
                    if(!strncasecmp(tmp,"AOPEN",5)
								|| !strncasecmp(tmp,"ASUS", 4)
								|| !strncasecmp(tmp,"ATAPI", 5)
                                || !strncasecmp(tmp,"BENQ", 4)
                                || !strncasecmp(tmp,"CREATIVE", 8)
								|| !strncasecmp(tmp,"GENERIC", 7)
								|| !strncasecmp(tmp,"HITACHI", 7)
								|| !strncasecmp(tmp,"HP", 2)
								|| !strncasecmp(tmp,"IMATION", 7)
                                || !strncasecmp(tmp,"IOMEGA", 6)
                                || !strncasecmp(tmp,"LG", 2)
                                || !strncasecmp(tmp,"LITE-ON", 7)
                                || !strncasecmp(tmp,"MAD DOG", 7)
                                || !strncasecmp(tmp,"MEMOREX", 7)
                                || !strncasecmp(tmp,"MITSUMI", 7)
                                || !strncasecmp(tmp,"NEC", 3)
                                || !strncasecmp(tmp,"OPTIARC", 7)
                                || !strncasecmp(tmp,"PANASONIC", 9)
                                || !strncasecmp(tmp,"PHILIPS", 7)
								|| !strncasecmp(tmp,"PIONEER", 7)
								|| !strncasecmp(tmp,"PLDS", 5)
								|| !strncasecmp(tmp,"PLEXTOR", 7)
								|| !strncasecmp(tmp,"QSI", 3)
                                || !strncasecmp(tmp,"RICOH", 5)
								|| !strncasecmp(tmp,"SAMSUNG", 7)
								|| !strncasecmp(tmp,"SLIMTYPE", 8)
                                || !strncasecmp(tmp,"SONY", 4)
                                || !strncasecmp(tmp,"TDK", 3)
                                || !strncasecmp(tmp,"TEAC", 4)
                                || !strncasecmp(tmp,"TOSHIBA", 7)
                                || !strncasecmp(tmp,"TSSTcorp", 8)
                                || !strncasecmp(tmp,"YAMAHA", 6)) {
                        if(strlen(tmp) > 1) {
                            while(tmp[i] != '-' || tmp[i+1] != ' ') i++;
                            i++;
                            while(tmp[i] == ' ') i++;
                            if(tmp[i] != 0) {
                                strcpy(drive,tmp+i);
                                state = 1;
                            }
                        }
                    }
                }
            }
            
            else if(state == 1) {
                if(!strncasecmp(s+65,"[Purged]",8)) {
                    state = 0;
                }
                else {
                    offset = atoi(s+65);
                    state = 2;
                }
            }
            else if(state == 2) {
                confidence = atoi(s+65);
                //printf("%s,%d,%d\n",drive,offset,confidence);
                if([dic objectForKey:[NSString stringWithUTF8String:drive]]) {
                    if([[dic objectForKey:[NSString stringWithUTF8String:drive]] intValue] != offset)
                        NSLog(@"conflict:%s",drive);
                }
                else [dic setObject:[NSNumber numberWithInt:offset] forKey:[NSString stringWithUTF8String:drive]];
                state = 0;
            }
            
            range.location = NSMaxRange(subrange);
            range.length -= subrange.length;
        }
        [str release];
    }
    
    //[dic setObject:[NSNumber numberWithInt:102] forKey:@"DVD-R   UJ-857E"];
    [dic setObject:[NSNumber numberWithInt:103] forKey:@"CD-RW  CW-8123"];
    [dic writeToFile:@"offset.plist" atomically:YES];
    [dic release];
    
    [pool release];
    return 0;
}
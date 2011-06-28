#import <Cocoa/Cocoa.h>

@interface XLDMusicBrainzReleaseList : NSObject
{
	NSMutableArray *releases;
}
- (id)initWithDiscID:(NSString *)discid;
- (NSArray *)releaseList;
@end

@implementation XLDMusicBrainzReleaseList

- (id)initWithDiscID:(NSString *)discid
{
	self = [super init];
	if(!self) return nil;
	
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://musicbrainz.org/ws/2/discid/%@?inc=artist-credits",discid]];
	NSData *data = [NSData dataWithContentsOfURL:url];
	if(!data || [data length] == 0) {
		[super dealloc];
		return nil;
	}
	NSXMLDocument *xml = [[NSXMLDocument alloc] initWithData:data options:NSXMLDocumentTidyXML error:nil];
	if(!xml) {
		[super dealloc];
		return nil;
	}
	releases = [[NSMutableArray alloc] init];
	NSArray *arr = [xml nodesForXPath:@"/metadata/disc/release-list/release" error:nil];
	int i;
	for(i=0;i<[arr count];i++) {
		NSMutableDictionary *dic = [NSMutableDictionary dictionary];
		id rel = [arr objectAtIndex:i];
		NSArray *objs = [rel nodesForXPath:@"./@id" error:nil];
		if([objs count]) [dic setObject:[[objs objectAtIndex:0] stringValue] forKey:@"RleaseID"];
		objs = [rel nodesForXPath:@"./title" error:nil];
		if([objs count]) [dic setObject:[[objs objectAtIndex:0] stringValue] forKey:@"Title"];
		objs = [rel nodesForXPath:@"./artist-credit/name-credit/artist/name" error:nil];
		if([objs count]) [dic setObject:[[objs objectAtIndex:0] stringValue] forKey:@"Artist"];
		[releases addObject:dic];
	}
	NSLog(@"%@",[releases description]);
	return self;
}

- (void)dealloc
{
	[releases release];
	[super dealloc];
}

- (NSArray *)releaseList
{
	return releases;
}

@end

@interface XLDMusicBrainzRelease : NSObject
{
	NSMutableDictionary *release;
}
- (id)initWithReleaseID:(NSString *)releaseid andDiscID:(NSString *)discid;
- (NSDictionary *)release;
@end

@implementation XLDMusicBrainzRelease

- (id)initWithReleaseID:(NSString *)releaseid andDiscID:(NSString *)discid
{
	self = [super init];
	if(!self) return nil;
	
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://musicbrainz.org/ws/2/release/%@?inc=artist-credits+recordings+discids",releaseid]];
	NSData *data = [NSData dataWithContentsOfURL:url];
	if(!data || [data length] == 0) {
		[super dealloc];
		return nil;
	}
	NSXMLDocument *xml = [[NSXMLDocument alloc] initWithData:data options:NSXMLDocumentTidyXML error:nil];
	if(!xml) {
		[super dealloc];
		return nil;
	}
	
	release = [[NSMutableDictionary alloc] init];
	NSArray *arr = [xml nodesForXPath:@"/metadata/release" error:nil];
	if(![arr count]) {
		[release release];
		[super dealloc];
		return nil;
	}
	
	id rel = [arr objectAtIndex:0];
	NSArray *objs = [rel nodesForXPath:@"./title" error:nil];
	if([objs count]) [release setObject:[[objs objectAtIndex:0] stringValue] forKey:@"Title"];
	objs = [rel nodesForXPath:@"./artist-credit/name-credit/artist/name" error:nil];
	if([objs count]) [release setObject:[[objs objectAtIndex:0] stringValue] forKey:@"Artist"];
	objs = [rel nodesForXPath:@"./date" error:nil];
	if([objs count]) [release setObject:[[objs objectAtIndex:0] stringValue] forKey:@"Date"];
	objs = [rel nodesForXPath:@"./asin" error:nil];
	if([objs count]) [release setObject:[[objs objectAtIndex:0] stringValue] forKey:@"ASIN"];
	objs = [rel nodesForXPath:@"./barcode" error:nil];
	if([objs count]) [release setObject:[[objs objectAtIndex:0] stringValue] forKey:@"Barcode"];
	
	NSArray *discs = [rel nodesForXPath:@"./medium-list/medium" error:nil];
	int i,j;
	for(i=0;i<[discs count];i++) {
		id disc = [discs objectAtIndex:i];
		objs = [disc nodesForXPath:@"./disc-list/disc/@id" error:nil];
		if(![objs count]) continue;
		if(![[[objs objectAtIndex:0] stringValue] isEqualToString:discid]) continue;
		objs = [disc nodesForXPath:@"./title" error:nil];
		if([objs count]) [release setObject:[[objs objectAtIndex:0] stringValue] forKey:@"Title"];
		
		NSArray *tracks = [disc nodesForXPath:@"./track-list/track" error:nil];
		NSMutableDictionary *trackList = [NSMutableDictionary dictionary];
		for(j=0;j<[tracks count];j++) {
			id tr = [tracks objectAtIndex:j];
			NSMutableDictionary *track = [NSMutableDictionary dictionary];
			objs = [tr nodesForXPath:@"./recording/title" error:nil];
			if([objs count]) [track setObject:[[objs objectAtIndex:0] stringValue] forKey:@"Title"];
			objs = [tr nodesForXPath:@"./recording/artist-credit/name-credit/artist/name" error:nil];
			if([objs count]) [track setObject:[[objs objectAtIndex:0] stringValue] forKey:@"Artist"];
			else {
				NSString *aartist = [release objectForKey:@"Artist"];
				if(aartist) [track setObject:aartist forKey:@"Artist"];
			}
			int trackNum = 0;
			objs = [tr nodesForXPath:@"./position" error:nil];
			if([objs count]) trackNum = [[[objs objectAtIndex:0] stringValue] intValue];
			if(trackNum) [trackList setObject:track forKey:[NSNumber numberWithInt:trackNum]];
		}
		[release setObject:trackList forKey:@"Tracks"];
	}
	NSLog(@"%@",[release description]);
	return self;
}

- (void)dealloc
{
	[release release];
	[super dealloc];
}

- (NSDictionary *)release
{
	return release;
}

@end

int main(void)
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	XLDMusicBrainzReleaseList *list = [[XLDMusicBrainzReleaseList alloc] initWithDiscID:@"sMlXlssB4sS9HAJHib.dmuH3Eyk-"];
	XLDMusicBrainzRelease *release = [[XLDMusicBrainzRelease alloc] initWithReleaseID:@"fd9e3922-2656-4a5b-a181-b68942353993" andDiscID:@"sMlXlssB4sS9HAJHib.dmuH3Eyk-"];
	[pool release];
	return 0;
}

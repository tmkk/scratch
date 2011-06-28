#import <Cocoa/Cocoa.h>


@interface XLDDiscogsCoverArtGetter : NSObject
{
	NSString *coverArtURLStr;
}
@end

@implementation XLDDiscogsCoverArtGetter

- (void)dealloc
{
	if(coverArtURLStr) {
		[coverArtURLStr release];
		coverArtURLStr = nil;
	}
	[super dealloc];
}

- (NSURL *)coverArtURLForRelease:(NSDictionary *)release
{
	if(coverArtURLStr) {
		[coverArtURLStr release];
		coverArtURLStr = nil;
	}
	NSURL *url = [NSURL URLWithString:[[NSString stringWithFormat:@"%@?f=xml&api_key=93d8eac4f6",[release objectForKey:@"uri"]] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
	NSData *data = [NSData dataWithContentsOfURL:url];
	NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data];
	[parser setDelegate:self];
	[parser parse];
	[parser release];
	if(!coverArtURLStr) return nil;
	return [NSURL URLWithString:[coverArtURLStr stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
	NSLog(@"parseErrorOccurred");
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributeDict
{
	if([elementName isEqualToString:@"image"]) {
		if(!coverArtURLStr || [[attributeDict objectForKey:@"type"] isEqualToString:@"primary"]) {
			if(coverArtURLStr) [coverArtURLStr release];
			coverArtURLStr = [[NSString alloc] initWithString:[attributeDict objectForKey:@"uri"]];
			NSLog(@"%@",coverArtURLStr);
		}
	}
}

@end

enum
{
	XLDDiscogsSearcherParserStateNone = 0,
	XLDDiscogsSearcherParserStateParsingReleases,
	XLDDiscogsSearcherParserStateReadingRelease,
};

@interface XLDDiscogsSearcher : NSObject
{
	NSMutableArray *results;
	NSURL *url;
	int state;
	NSMutableDictionary *currentRelease;
	NSString *currentKey;
	NSMutableString *currentStr;
}

- (id)initWithKeyword:(NSString *)key;
- (NSArray *)results;

@end

@implementation XLDDiscogsSearcher

- (id)initWithKeyword:(NSString *)key
{
	[super init];
	results = [[NSMutableArray alloc] init];
	url = [[NSURL alloc] initWithString:[NSString stringWithFormat:@"http://www.discogs.com/search?type=all&q=%@&f=xml&api_key=93d8eac4f6",[[key precomposedStringWithCanonicalMapping] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
	return self;
}

- (void)dealloc
{
	[url release];
	[results release];
	[super dealloc];
}

- (void)doSearch
{
	if([results count]) return;
	NSData *data = [NSData dataWithContentsOfURL:url];
	NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data];
	[parser setDelegate:self];
	[parser parse];
	[parser release];
}

- (NSArray *)results
{
	return results;
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
	if(currentKey && currentStr && currentRelease) {
		[currentStr appendString:string];
	}
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
	NSLog(@"parseErrorOccurred");
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributeDict
{
	if(state == XLDDiscogsSearcherParserStateNone) {
		if([elementName isEqualToString:@"searchresults"]) state = XLDDiscogsSearcherParserStateParsingReleases;
	}
	else if(state == XLDDiscogsSearcherParserStateParsingReleases) {
		if([elementName isEqualToString:@"result"]) {
			if([[attributeDict objectForKey:@"type"] isEqualToString:@"release"]) {
				state = XLDDiscogsSearcherParserStateReadingRelease;
				currentRelease = [[NSMutableDictionary alloc] init];
			}
		}
	}
	else if(state == XLDDiscogsSearcherParserStateReadingRelease) {
		currentKey = [elementName retain];
		currentStr = [[NSMutableString alloc] init];
	}
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
	if(state == XLDDiscogsSearcherParserStateParsingReleases) {
		if([elementName isEqualToString:@"searchresults"]) {
			state = XLDDiscogsSearcherParserStateNone;
		}
	}
	else if(state == XLDDiscogsSearcherParserStateReadingRelease) {
		if([elementName isEqualToString:@"result"]) {
			[results addObject:currentRelease];
			[currentRelease release];
			currentRelease = nil;
			state = XLDDiscogsSearcherParserStateParsingReleases;
		}
		else if(currentRelease && currentKey && currentStr) {
			[currentRelease setObject:currentStr forKey:currentKey];
			[currentStr release];
			[currentKey release];
			currentStr = nil;
			currentKey = nil;
		}
	}
}

@end

int main(int argc, char **argv)
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	XLDDiscogsSearcher *client = [[XLDDiscogsSearcher alloc] initWithKeyword:[NSString stringWithUTF8String:argv[1]]];
	[client doSearch];
	
	int i;
	for(i=0;i<[[client results] count];i++) {
		NSDictionary *result = [[client results] objectAtIndex:i];
		fprintf(stdout,"%s\n",[[result objectForKey:@"summary"] UTF8String]);
		fprintf(stdout,"%s\n",[[result objectForKey:@"title"] UTF8String]);
		fprintf(stdout,"%s\n\n",[[result objectForKey:@"uri"] UTF8String]);
	}
	if([[client results] count]) {
		XLDDiscogsCoverArtGetter *getter = [[XLDDiscogsCoverArtGetter alloc] init];
		[getter coverArtURLForRelease:[[client results] objectAtIndex:0]];
	}
	
	[pool release];
	return 0;
}

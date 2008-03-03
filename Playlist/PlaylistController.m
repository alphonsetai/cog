//
//	PlaylistController.m
//	Cog
//
//	Created by Vincent Spader on 3/18/05.
//	Copyright 2005 Vincent Spader All rights reserved.
//

#import "PlaylistLoader.h"
#import "PlaylistController.h"
#import "PlaylistEntry.h"
#import "Shuffle.h"
#import "SpotlightWindowController.h"
#import "RepeatTransformers.h"
#import "StatusImageTransformer.h"

#import "CogAudio/AudioPlayer.h"

@implementation PlaylistController

@synthesize currentEntry;
@synthesize totalTime;

+ (void)initialize {
	NSValueTransformer *repeatNoneTransformer = [[[RepeatModeTransformer alloc] initWithMode:RepeatNone] autorelease];
    [NSValueTransformer setValueTransformer:repeatNoneTransformer
                                    forName:@"RepeatNoneTransformer"];

	NSValueTransformer *repeatOneTransformer = [[[RepeatModeTransformer alloc] initWithMode:RepeatOne] autorelease];
    [NSValueTransformer setValueTransformer:repeatOneTransformer
                                    forName:@"RepeatOneTransformer"];

	NSValueTransformer *repeatAlbumTransformer = [[[RepeatModeTransformer alloc] initWithMode:RepeatAlbum] autorelease];
    [NSValueTransformer setValueTransformer:repeatAlbumTransformer
                                    forName:@"RepeatAlbumTransformer"];

	NSValueTransformer *repeatAllTransformer = [[[RepeatModeTransformer alloc] initWithMode:RepeatAll] autorelease];
    [NSValueTransformer setValueTransformer:repeatAllTransformer
                                    forName:@"RepeatAllTransformer"];

	NSValueTransformer *repeatModeImageTransformer = [[[RepeatModeImageTransformer alloc] init] autorelease];
    [NSValueTransformer setValueTransformer:repeatModeImageTransformer
                                    forName:@"RepeatModeImageTransformer"];

	NSValueTransformer *statusImageTransformer = [[[StatusImageTransformer alloc] init] autorelease];
    [NSValueTransformer setValueTransformer:statusImageTransformer
                                    forName:@"StatusImageTransformer"];
}

- (id)initWithCoder:(NSCoder *)decoder
{
	self = [super initWithCoder:decoder];
	
	if (self)
	{
		shuffleList = [[NSMutableArray alloc] init];
		queueList = [[NSMutableArray alloc] init];
	}
	
	return self;
}

- (void)dealloc
{
	[shuffleList release];
	[queueList release];
	
	[super dealloc];
}

- (void)awakeFromNib
{
	[super awakeFromNib];

	[self addObserver:self forKeyPath:@"arrangedObjects" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:@"arrangedObjects"])	
	{
		[self updatePlaylistIndexes];
		[self updateTotalTime];
	}
}

- (void)updatePlaylistIndexes
{
	int i;
	NSArray *arranged = [self arrangedObjects];
	for (i = 0; i < [arranged count]; i++)
	{
		PlaylistEntry *pe = [arranged objectAtIndex:i];
		if (pe.index != i) //Make sure we don't get into some kind of crazy observing loop...
			pe.index = i;
	}
}

- (void)updateTotalTime
{
	double tt = 0;
	ldiv_t hoursAndMinutes;
	
	for (PlaylistEntry *pe in [self arrangedObjects]) {
        if (!isnan([pe.length doubleValue]))
            tt += [pe.length doubleValue];
	}
	
	int sec = (int)(tt);
	hoursAndMinutes = ldiv(sec/60, 60);
	
	[self setTotalTime:[NSString stringWithFormat:@"%ld hours %ld minutes %d seconds", hoursAndMinutes.quot, hoursAndMinutes.rem, sec%60]];
}

- (void)tableView:(NSTableView *)tableView
		didClickTableColumn:(NSTableColumn *)tableColumn
{
	if (shuffle == YES)
		[self resetShuffleList];
}

- (NSString *)tableView:(NSTableView *)tv toolTipForCell:(NSCell *)cell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)tc row:(int)row mouseLocation:(NSPoint)mouseLocation
{
	NSLog(@"GETTING STATUS FOR ROW: %i: %@!", row, [[[self arrangedObjects] objectAtIndex:row] statusMessage]);
	return [[[self arrangedObjects] objectAtIndex:row] statusMessage];
}

-(void)moveObjectsInArrangedObjectsFromIndexes:(NSIndexSet*)indexSet
										toIndex:(unsigned int)insertIndex
{
	[super moveObjectsInArrangedObjectsFromIndexes:indexSet toIndex:insertIndex];

	NSUInteger lowerIndex = insertIndex;
	NSUInteger index = insertIndex;
	
	while (NSNotFound != lowerIndex) {
		lowerIndex = [indexSet indexLessThanIndex:lowerIndex];
		
		if (lowerIndex != NSNotFound)
			index = lowerIndex;
	}
}

- (BOOL)tableView:(NSTableView *)aTableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard
{
	[super tableView:aTableView writeRowsWithIndexes:rowIndexes toPasteboard:pboard];

	NSMutableArray *filenames = [NSMutableArray array];
	NSInteger row;
	for (row = [rowIndexes firstIndex];
		 row <= [rowIndexes lastIndex];
		 row = [rowIndexes indexGreaterThanIndex:row])
	{
		PlaylistEntry *song = [[self arrangedObjects] objectAtIndex:row];
		[filenames addObject:[[song path] stringByExpandingTildeInPath]];
	}

	[pboard addTypes:[NSArray arrayWithObject:NSFilenamesPboardType] owner:self];
    [pboard setPropertyList:filenames forType:NSFilenamesPboardType];
	
	return YES;
}

- (BOOL)tableView:(NSTableView*)tv
	   acceptDrop:(id <NSDraggingInfo>)info
			  row:(int)row
	dropOperation:(NSTableViewDropOperation)op
{
	//Check if DNDArrayController handles it.
	if ([super tableView:tv acceptDrop:info row:row dropOperation:op])
		return YES;

	if (row < 0)
		row = 0;
		
	// Determine the type of object that was dropped
	NSArray *supportedtypes = [NSArray arrayWithObjects:CogUrlsPboardType, NSFilenamesPboardType, iTunesDropType, nil];
	NSPasteboard *pboard = [info draggingPasteboard];
	NSString *bestType = [pboard availableTypeFromArray:supportedtypes];
	
	// Get files from an file drawer drop
	if ([bestType isEqualToString:CogUrlsPboardType]) {
		NSArray *urls = [NSUnarchiver unarchiveObjectWithData:[[info draggingPasteboard] dataForType:CogUrlsPboardType]];
		NSLog(@"URLS: %@", urls);
		[playlistLoader insertURLs: urls atIndex:row sort:YES];
	}
	
	// Get files from a normal file drop (such as from Finder)
	if ([bestType isEqualToString:NSFilenamesPboardType]) {
		NSMutableArray *urls = [[NSMutableArray alloc] init];

		for (NSString *file in [[info draggingPasteboard] propertyListForType:NSFilenamesPboardType])
		{
			[urls addObject:[NSURL fileURLWithPath:file]];
		}
		
		[playlistLoader insertURLs:urls atIndex:row sort:YES];

		[urls release];
	}
	
	// Get files from an iTunes drop
	if ([bestType isEqualToString:iTunesDropType]) {
		NSDictionary *iTunesDict = [pboard propertyListForType:iTunesDropType];
		NSDictionary *tracks = [iTunesDict valueForKey:@"Tracks"];

		// Convert the iTunes URLs to URLs....MWAHAHAH!
		NSMutableArray *urls = [[NSMutableArray alloc] init];

		for (NSDictionary *trackInfo in [tracks allValues]) {
			[urls addObject:[NSURL URLWithString:[trackInfo valueForKey:@"Location"]]];
		}
		
		[playlistLoader insertURLs:urls atIndex:row sort:YES];
		[urls release];
	}
	
	if (shuffle == YES)
		[self resetShuffleList];
	
	return YES;
}

- (NSUndoManager *)undoManager
{
	return [entriesController undoManager];
}

- (void)insertObjects:(NSArray *)objects atArrangedObjectIndexes:(NSIndexSet *)indexes
{
	[super insertObjects:objects atArrangedObjectIndexes:indexes];
	
	if (shuffle == YES)
		[self resetShuffleList];
}

- (void)removeObjectsAtArrangedObjectIndexes:(NSIndexSet *)indexes
{
	NSLog(@"Removing indexes: %@", indexes);
	NSLog(@"Current index: %i", currentEntry.index);

	if (currentEntry.index >= 0 && [indexes containsIndex:currentEntry.index])
	{
		currentEntry.index = -currentEntry.index - 1;
		NSLog(@"Current removed: %i", currentEntry.index);
	}
	
	if (currentEntry.index < 0) //Need to update the negative index
	{
		int i = -currentEntry.index - 1;
		NSLog(@"I is %i", i);
		int j;
		for (j = i - 1; j >= 0; j--)
		{
			if ([indexes containsIndex:j]) {
				NSLog(@"Removing 1");
				i--;
			}
		}
		currentEntry.index = -i - 1;

	}
	
	[super removeObjectsAtArrangedObjectIndexes:indexes];
	
	if (shuffle == YES)
		[self resetShuffleList];
}

- (void)setSortDescriptors:(NSArray *)sortDescriptors
{
	NSLog(@"Current: %@, setting: %@", [self sortDescriptors], sortDescriptors);

	//Cheap hack so the index column isn't sorted
	if (([sortDescriptors count] != 0) && [[[sortDescriptors objectAtIndex:0] key] caseInsensitiveCompare:@"index"] == NSOrderedSame)
	{
		//Remove the sort descriptors
		[super setSortDescriptors:nil];
		[self rearrangeObjects];
		
		return;
	}

	[super setSortDescriptors:sortDescriptors];
	[self rearrangeObjects];
}
		
- (IBAction)sortByPath
{
	NSSortDescriptor *s = [[NSSortDescriptor alloc] initWithKey:@"url" ascending:YES selector:@selector(compare:)];
	
	[self setSortDescriptors:[NSArray arrayWithObject:s]];

	[s release];	

	if (shuffle == YES)
		[self resetShuffleList];
}

- (IBAction)randomizeList
{
	[self setSortDescriptors:nil];

	[self setContent:[Shuffle shuffleList:[self content]]];
	if (shuffle == YES)
		[self resetShuffleList];
}

- (IBAction)takeShuffleFromObject:(id)sender
{
	if( [sender respondsToSelector: @selector(boolValue)] )
		[self setShuffle: [sender boolValue]];
	else
		[self setShuffle: [sender state]];
}

- (IBAction)toggleRepeat:(id)sender
{
	if (repeat == RepeatNone) {
		[self setRepeat: RepeatOne];
	}
	else if (repeat == RepeatOne) {
		[self setRepeat: RepeatAlbum];
	}
	else if (repeat == RepeatAlbum) {
		[self setRepeat: RepeatAll];
	}
	else if (repeat == RepeatAll) {
		[self setRepeat: RepeatNone];
	}
}

- (PlaylistEntry *)entryAtIndex:(int)i
{
	if (i < 0)
	{
		if (repeat != RepeatNone)
			i += [[self arrangedObjects] count];
		else
			return nil;
	}
	else if (i >= [[self arrangedObjects] count])
	{
		if (repeat != RepeatNone)
			i -= [[self arrangedObjects] count];
		else
			return nil;
	}
	
	return [[self arrangedObjects] objectAtIndex:i];
}

- (PlaylistEntry *)shuffledEntryAtIndex:(int)i
{
	while (i < 0)
	{
		if (repeat == RepeatAll)
		{
			[self addShuffledListToFront];
			//change i appropriately
			i += [[self arrangedObjects] count];
		}
		else
		{
			return nil;
		}
	}
	while (i >= [shuffleList count])
	{
		if (repeat == RepeatAll)
		{
			[self addShuffledListToBack];
		}
		else
		{
			return nil;
		}
	}
	
	return [shuffleList objectAtIndex:i];
}

- (PlaylistEntry *)getNextEntry:(PlaylistEntry *)pe
{
	if (repeat == RepeatOne) {
		return pe;
	}
	
	if ([queueList count] > 0)
	{
		
		pe = [queueList objectAtIndex:0];
		[queueList removeObjectAtIndex:0];
		pe.queued = NO;
		[pe setQueuePosition:-1];
		
		int i;
		for (i = 0; i < [queueList count]; i++)
		{
			PlaylistEntry *queueItem = [queueList objectAtIndex:i];
			[queueItem setQueuePosition: i];
		}
		
		return pe;
	}
	
	if (shuffle == YES)
	{
		return [self shuffledEntryAtIndex:(pe.shuffleIndex + 1)];
	}
	else
	{
		int i;
		if (pe.index < 0) //Was a current entry, now removed.
		{
			i = -pe.index - 1;
		}
		else
		{
			i = pe.index + 1;
		}
		
		if (repeat == RepeatAlbum)
		{
			PlaylistEntry *next = [self entryAtIndex:i];
			
			if ((i > [[self arrangedObjects] count]-1) || ([[next album] caseInsensitiveCompare:[pe album]]) || ([next album] == nil))
			{
				NSArray *filtered = [self filterPlaylistOnAlbum:[pe album]];
				if ([pe album] == nil)
					i--;
				else
					i = [(NSNumber *)[[filtered objectAtIndex:0] index] intValue];
			}
			
		}

		return [self entryAtIndex:i];
	}
}

- (NSArray *)filterPlaylistOnAlbum:(NSString *)album
{
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"album like %@",
							  album];		
	return [[self arrangedObjects] filteredArrayUsingPredicate:predicate];
}

- (PlaylistEntry *)getPrevEntry:(PlaylistEntry *)pe
{
	if (repeat == RepeatOne) {
		return pe;
	}
	
	if (shuffle == YES)
	{
		return [self shuffledEntryAtIndex:(pe.shuffleIndex - 1)];
	}
	else
	{
		int i;
		if (pe.index < 0) //Was a current entry, now removed.
		{
			i = -pe.index - 2;
		}
		else
		{
			i = pe.index - 1;
		}
		
		return [self entryAtIndex:i];
	}
}

- (BOOL)next
{
	PlaylistEntry *pe;
	
	pe = [self getNextEntry:[self currentEntry]];
	
	if (pe == nil)
		return NO;
	
	[self setCurrentEntry:pe];
	
	return YES;
}

- (BOOL)prev
{
	PlaylistEntry *pe;
	
	pe = [self getPrevEntry:[self currentEntry]];
	if (pe == nil)
		return NO;
	
	[self setCurrentEntry:pe];
	
	return YES;
}

- (void)addShuffledListToFront
{
	NSArray *newList = [Shuffle shuffleList:[self arrangedObjects]];
	NSIndexSet *indexSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [newList count])];
	
	[shuffleList insertObjects:newList atIndexes:indexSet];
	
	int i;
	for (i = 0; i < [shuffleList count]; i++)
	{
		[[shuffleList objectAtIndex:i] setShuffleIndex:i];
	}
}

- (void)addShuffledListToBack
{
	NSArray *newList = [Shuffle shuffleList:[self arrangedObjects]];
	NSIndexSet *indexSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange([shuffleList count], [newList count])];

	[shuffleList insertObjects:newList atIndexes:indexSet];

	int i;
	for (i = ([shuffleList count] - [newList count]); i < [shuffleList count]; i++)
	{
		[[shuffleList objectAtIndex:i] setShuffleIndex:i];
	}
}

- (void)resetShuffleList
{
	[shuffleList removeAllObjects];

	[self addShuffledListToFront];

	if (currentEntry && currentEntry.index >= 0)
	{
		[shuffleList insertObject:currentEntry atIndex:0];
		[currentEntry setShuffleIndex:0];
		
		//Need to rejigger so the current entry is at the start now...
		int i;
		BOOL found = NO;
		for (i = 1; i < [shuffleList count] && !found; i++)
		{
			if ([shuffleList objectAtIndex:i] == currentEntry)
			{
				found = YES;
				[shuffleList removeObjectAtIndex:i];
			}
			else {
				[[shuffleList objectAtIndex:i] setShuffleIndex: i];
			}
		}
	}
}

- (void)setCurrentEntry:(PlaylistEntry *)pe
{
	currentEntry.current = NO;
	currentEntry.stopAfter = NO;
	
	pe.current = YES;
	
	//[tableView scrollRowToVisible:pe.index];
	
	[pe retain];
	[currentEntry release];
	
	currentEntry = pe;
}	

- (void)setShuffle:(BOOL)s
{
	shuffle = s;
	if (shuffle == YES)
		[self resetShuffleList];
}
- (BOOL)shuffle
{
	return shuffle;
}
- (void)setRepeat:(RepeatMode)r
{
	NSLog(@"Repeat is now: %i", r);
	repeat = r;
}
- (RepeatMode)repeat
{
	return repeat;
}

- (IBAction)clear:(id)sender
{
	[self setFilterPredicate:nil];
	
	[self removeObjectsAtArrangedObjectIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [[self arrangedObjects] count])]];
}

- (IBAction)clearFilterPredicate:(id)sender
{
	[self setFilterPredicate:nil];
}

- (void)setFilterPredicate:(NSPredicate *)filterPredicate
{
	[super setFilterPredicate:filterPredicate];
}

- (IBAction)showEntryInFinder:(id)sender
{
	NSWorkspace* ws = [NSWorkspace sharedWorkspace];
	if ([self selectionIndex] < 0)
		return;
	
	NSURL *url = [[[self selectedObjects] objectAtIndex:0] URL];
	if ([url isFileURL])
		[ws selectFile:[url path] inFileViewerRootedAtPath:[url path]];
}

- (IBAction)searchByArtist:(id)sender;
{
    PlaylistEntry *entry = [[self arrangedObjects] objectAtIndex:[self selectionIndex]];
    [spotlightWindowController searchForArtist:[entry artist]];
}
- (IBAction)searchByAlbum:(id)sender;
{
    PlaylistEntry *entry = [[self arrangedObjects] objectAtIndex:[self selectionIndex]];
    [spotlightWindowController searchForAlbum:[entry album]];
}

- (NSMutableArray *)queueList
{
	return queueList;
}

- (IBAction)emptyQueueList:(id)sender
{
	for (PlaylistEntry *queueItem in queueList)
	{
		queueItem.queued = NO;
		[queueItem setQueuePosition:-1];
	}

	[queueList removeAllObjects];
}


- (IBAction)addToQueue:(id)sender
{
	for (PlaylistEntry *queueItem in [self selectedObjects])
	{
		queueItem.queued = YES;
		[queueItem setQueuePosition: [queueList count]];
		
		[queueList addObject:queueItem];
	}
	
	for (PlaylistEntry *ap in queueList)
		NSLog(@"hehe now: %d", ap.queuePosition);
}

- (IBAction)removeFromQueue:(id)sender
{
		
	for (PlaylistEntry *queueItem in [self selectedObjects])
	{
		queueItem.queued = NO;
		[queueItem setQueuePosition:-1];
		[queueList removeObject:queueItem];
	}

	int i = 0;
	for (PlaylistEntry *cur in queueList)
	{
		[cur setQueuePosition:i++];
	}
}

- (IBAction)stopAfterCurrent:(id)sender
{
	currentEntry.stopAfter = !currentEntry.stopAfter;
}

-(BOOL)validateMenuItem:(NSMenuItem*)menuItem
{
	SEL action = [menuItem action];
	
	if (action == @selector(removeFromQueue:))
	{
		for (PlaylistEntry *q in [self selectedObjects])
			if (q.queuePosition >= 0)
				return YES;

		return NO;
	}

	if (action == @selector(emptyQueueList:) && ([queueList count] < 1))
		return NO;
	
	if (action == @selector(stopAfterCurrent:) && currentEntry.stopAfter)
		return NO;
	
	// if nothing is selected, gray out these
	if ([[self selectedObjects] count] < 1)
	{
		
		if (action == @selector(remove:))
			return NO;
	
		if (action == @selector(addToQueue:))
			return NO;

		if (action == @selector(searchByArtist:))
			return NO;

		if (action == @selector(searchByAlbum:))
			return NO;
	}
	
	return YES;
}


@end

//
//  InputNode.m
//  Cog
//
//  Created by Vincent Spader on 8/2/05.
//  Copyright 2005 Vincent Spader. All rights reserved.
//

#import "InputNode.h"
#import "BufferChain.h"
#import "Plugin.h"
#import "CoreAudioUtils.h"

@implementation InputNode

- (BOOL)openWithSource:(id<CogSource>)source
{
	decoder = [AudioDecoder audioDecoderForSource:source];
	[decoder retain];

	if (decoder == nil)
		return NO;

	[self registerObservers];

	if (![decoder open:source])
	{
		NSLog(@"Couldn't open decoder...");
		return NO;
	}
	
	NSDictionary *properties = [decoder properties];
	int bitsPerSample = [[properties objectForKey:@"bitsPerSample"] intValue];
	int channels = [[properties objectForKey:@"channels"] intValue];
	
	bytesPerFrame = (bitsPerSample/8) * channels;
	
	shouldContinue = YES;
	shouldSeek = NO;

	return YES;
}

- (BOOL)openWithDecoder:(id<CogDecoder>) d
{
	NSLog(@"Opening with old decoder: %@", d);
	decoder = d;
	[decoder retain];

	NSDictionary *properties = [decoder properties];
	int bitsPerSample = [[properties objectForKey:@"bitsPerSample"] intValue];
	int channels = [[properties objectForKey:@"channels"] intValue];
	
	bytesPerFrame = (bitsPerSample/8) * channels;
	
	[self registerObservers];

	shouldContinue = YES;
	shouldSeek = NO;
	
	NSLog(@"DONES: %@", decoder);
	return YES;
}


- (void)registerObservers
{
	NSLog(@"REGISTERING OBSERVERS");
	[decoder addObserver:self
			  forKeyPath:@"properties" 
				 options:(NSKeyValueObservingOptionNew)
				 context:NULL];

	[decoder addObserver:self
			  forKeyPath:@"metadata" 
				 options:(NSKeyValueObservingOptionNew)
				 context:NULL];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
					  ofObject:(id)object 
                        change:(NSDictionary *)change
                       context:(void *)context
{
	NSLog(@"SOMETHING CHANGED!");
	if ([keyPath isEqual:@"properties"]) {
		//Setup converter!
		//Inform something of properties change
		//Disable support until it is properly implimented.
		//[controller inputFormatDidChange: propertiesToASBD([decoder properties])];
	}
	else if ([keyPath isEqual:@"metadata"]) {
		//Inform something of metadata change
	}
}

- (void)process
{
	int amountInBuffer = 0;
	void *inputBuffer = malloc(CHUNK_SIZE);
	
	BOOL shouldClose = YES;
	
	while ([self shouldContinue] == YES && [self endOfStream] == NO)
	{
		if (shouldSeek == YES)
		{
			NSLog(@"SEEKING!");
			[decoder seek:seekFrame];
			shouldSeek = NO;
			NSLog(@"Seeked! Resetting Buffer");
			
			[self resetBuffer];
			
			NSLog(@"Reset buffer!");
			initialBufferFilled = NO;
		}

		if (amountInBuffer < CHUNK_SIZE) {
			int framesToRead = (CHUNK_SIZE - amountInBuffer)/bytesPerFrame;
			int framesRead = [decoder readAudio:((char *)inputBuffer) + amountInBuffer frames:framesToRead];
			amountInBuffer += (framesRead * bytesPerFrame);

			if (framesRead <= 0)
			{
				if (initialBufferFilled == NO) {
					[controller initialBufferFilled:self];
				}
				
				NSLog(@"End of stream? %@", [self properties]);
				endOfStream = YES;
				shouldClose = [controller endOfInputReached]; //Lets us know if we should keep going or not (occassionally, for track changes within a file)
				NSLog(@"closing? is %i", shouldClose);
				break; 
			}
		
			[self writeData:inputBuffer amount:amountInBuffer];
			amountInBuffer = 0;
		}
	}
	if (shouldClose)
		[decoder close];
	
	free(inputBuffer);
}

- (void)seek:(long)frame
{
	seekFrame = frame;
	shouldSeek = YES;
	NSLog(@"Should seek!");
	[semaphore signal];
}

- (BOOL)setTrack:(NSURL *)track
{
	if ([decoder respondsToSelector:@selector(setTrack:)] && [decoder setTrack:track]) {
		NSLog(@"SET TRACK!");
		
		return YES;
	}
	
	return NO;
}

- (void)dealloc
{
	NSLog(@"Input Node dealloc");

	[decoder removeObserver:self forKeyPath:@"properties"];
	[decoder removeObserver:self forKeyPath:@"metadata"];

	[decoder release];
	
	[super dealloc];
}

- (NSDictionary *) properties
{
	return [decoder properties];
}

- (id<CogDecoder>) decoder
{
	return decoder;
}

@end

/* AppController */

#import <Cocoa/Cocoa.h>

#import "NDHotKeyEvent.h"

@class PlaybackController;
@class PlaylistController;
@class PlaylistView;
@class FileTreeController;
@class FileOutlineView;
@class AppleRemote;
@class PlaylistLoader;


@interface AppController : NSObject
{
	IBOutlet PlaybackController *playbackController;

    IBOutlet PlaylistController *playlistController;
	IBOutlet PlaylistLoader *playlistLoader;
	
	IBOutlet NSPanel *mainWindow;
	
	IBOutlet NSButton *playButton;
	IBOutlet NSButton *prevButton;
	IBOutlet NSButton *nextButton;
	IBOutlet NSButton *infoButton;
	IBOutlet NSButton *fileButton;
	IBOutlet NSButton *shuffleButton;
	IBOutlet NSButton *repeatButton;
	
	IBOutlet NSDrawer *infoDrawer;
	IBOutlet NSDrawer *fileDrawer;

	IBOutlet FileTreeController *fileTreeController;
	IBOutlet FileOutlineView *fileOutlineView;
	
	IBOutlet PlaylistView *playlistView;
	
	IBOutlet NSMenuItem *showIndexColumn;
	IBOutlet NSMenuItem *showTitleColumn;
	IBOutlet NSMenuItem *showArtistColumn;
	IBOutlet NSMenuItem *showAlbumColumn;
	IBOutlet NSMenuItem *showGenreColumn;
	IBOutlet NSMenuItem *showLengthColumn;
	IBOutlet NSMenuItem *showTrackColumn;
	IBOutlet NSMenuItem *showYearColumn;
	
	NDHotKeyEvent *playHotKey;
	NDHotKeyEvent *prevHotKey;
	NDHotKeyEvent *nextHotKey;
	
	AppleRemote *remote;
	BOOL remoteButtonHeld; /* true as long as the user holds the left,right,plus or minus on the remote control */
}

- (IBAction)openURL:(id)sender;

- (IBAction)openFiles:(id)sender;
- (IBAction)delEntries:(id)sender;
- (IBAction)savePlaylist:(id)sender;

- (IBAction)donate:(id)sender;

- (IBAction)toggleInfoDrawer:(id)sender;
- (IBAction)toggleFileDrawer:(id)sender;
- (void)drawerDidOpen:(NSNotification *)notification;
- (void)drawerDidClose:(NSNotification *)notification;

	//Fun stuff
- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag;
- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename;
- (void)application:(NSApplication *)theApplication openFiles:(NSArray *)filenames;

- (void)registerHotKeys;
OSStatus handleHotKey(EventHandlerCallRef nextHandler,EventRef theEvent,void *userData);

@end

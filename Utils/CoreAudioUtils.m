/*
 *  $Id$
 *
 *  Copyright (C) 2006 Stephen F. Booth <me@sbooth.org>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include "CoreAudioUtils.h"

#include <AudioToolbox/AudioFile.h>

// CoreAudio utility function
static NSArray *sAudioExtensions		= nil;

// Return an array of valid audio file extensions recognized by Core Audio
NSArray *
getCoreAudioExtensions()
{
	OSStatus			err;
	UInt32				size;
	
	@synchronized(sAudioExtensions) {
		if(nil == sAudioExtensions) {
			size	= sizeof(sAudioExtensions);
			err		= AudioFileGetGlobalInfo(kAudioFileGlobalInfo_AllExtensions, 0, NULL, &size, &sAudioExtensions);
			if(noErr != err) {
				return nil;
			}
			
			[sAudioExtensions retain];
		}
	}
	
	return sAudioExtensions;
}


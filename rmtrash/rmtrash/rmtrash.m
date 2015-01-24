//
//  rmtrash.m
//  rmtrash
//
//  Copyright (c) 2015 Sebastian Keller <sebikeller@myfucking.email>.
//  Copyright (c) 2003-2005 nightproductions.net.
//
//  modified from http://www.nightproductions.net/downloads/rmtrash_source.tar.gz
//

#import <Foundation/Foundation.h>
#import <unistd.h>

#ifndef __has_feature
#define __has_feature(x) 0
#endif

#if __has_feature(objc_arc)

#define NSAutorelease(__v) (__v)
#define NSRelease(__v)
#define NSReleaseReturn(__v) (__v)
#define NSRetain(__v)
#define NSRetainReturn(__v) (__v)

#define NSAutoreleasePoolInit
#define NSAutoreleasePoolDrain
#define NSAutoreleasePoolReleaseExit
#define NSAutoreleasePoolReleaseFinal

#else

#define NSAutorelease(__v) [(__v) autorelease]
#define NSRelease(__v) [(__v) release]
#define NSReleaseReturn(__v) NSRelease(__v)
#define NSRetain(__v) [(__v) retain]
#define NSRetainReturn(__v) NSRetain(__v)

#ifdef __OBJC_2

#define NSAutoreleasePoolInit @autoreasepool {
#define NSAutoreleasePoolDrain
#define NSAutoreleasePoolReleaseExit
#define NSAutoreleasePoolReleaseFinal }

#else

#define NSAutoreleasePoolInit NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
#define NSAutoreleasePoolDrain [pool drain];
#define NSAutoreleasePoolReleaseExit [pool release];
#define NSAutoreleasePoolReleaseFinal [pool release];

#endif

#endif

#define manager [NSFileManager defaultManager]

NSString *trashFileName(NSString *fileName) {
	NSString *ext = [[fileName lastPathComponent] pathExtension];
	NSDateFormatter *df = nil;
	BOOL dfIsNewStyle = NO;
	
	if ([NSDateFormatter instancesRespondToSelector:@selector(stringFromDate:)]) {
		// Woohoo!! We can use the new 10.4 behavior
		df = NSAutorelease([[NSDateFormatter alloc] init]);
		if ([df respondsToSelector:@selector(setFormatterBehavior:)]) {
			[df setFormatterBehavior:NSDateFormatterBehavior10_4];
		}
		[df setDateFormat:@"HH-mm-ss"];
		
		dfIsNewStyle = YES;
	} else {
		// Fallback to old NSDateFormatter behavior
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
		df = NSAutorelease([[NSDateFormatter alloc] initWithDateFormat:@"%H-%M-%S" allowNaturalLanguage:YES]);
#pragma GCC diagnostic pop
	}
	
	NSString *copyName;
	BOOL first = YES;
	do {
		if (!first) {
			if (dfIsNewStyle) {
				[df setDateFormat:@"HH-mm-ss-SSS"];
			} else {
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
				df = NSAutorelease([[NSDateFormatter alloc] initWithDateFormat:@"%H-%M-%S-%F" allowNaturalLanguage:YES]);
#pragma GCC diagnostic pop
			}
		}

		NSString *dateString = @"";
		NSDate *date = [NSDate date];
		if (dfIsNewStyle) {
			dateString = [df stringFromDate:date];
		} else {
			dateString = [df stringForObjectValue:date];
		}
		
		if ([ext length] > 0) {
			NSString *tempName = [fileName substringWithRange:NSMakeRange(0, ([fileName length] - ([ext length] + 1)))];
			copyName = [NSString stringWithFormat:@"%@ %@.%@", tempName, dateString, ext];
		} else {
			copyName = [NSString stringWithFormat:@"%@ %@", fileName, dateString];
		}
		
		first = NO;
	} while ([manager fileExistsAtPath:copyName]);
	
	return copyName;
}

void move_to_trash(NSString *userString, NSString *aFile) {
	NSString *fileString = aFile, *trashPath = nil;
	unichar firstChar = [fileString characterAtIndex:0];
	
	if (firstChar == '~') { // TODO: Why not always expand??
		fileString = [aFile stringByExpandingTildeInPath];
	}
	
	if (![manager fileExistsAtPath:fileString]) {
		printf("%s: File or directory does not exist.\n", [fileString UTF8String]);
		return;
	}
	
	trashPath = [[NSString stringWithFormat:@"~%@/.Trash/%@", userString, [fileString lastPathComponent]] stringByExpandingTildeInPath];
	
	if (![manager fileExistsAtPath:[[NSString stringWithFormat:@"~%@/.Trash", userString] stringByExpandingTildeInPath]]) {
		printf("%s: Unknown user!\n",[userString UTF8String]);
		return;
	}
	if ([manager fileExistsAtPath:trashPath]) {
		trashPath = trashFileName(trashPath);
	}
	
	BOOL moveResult = YES;
	if ([manager respondsToSelector:@selector(moveItemAtURL:toURL:error:)]) {
		moveResult = [manager moveItemAtURL:[NSURL fileURLWithPath:fileString] toURL:[NSURL fileURLWithPath:trashPath] error:nil];
	} else {
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
		// Fallback to now deprecated method
		moveResult = [manager movePath:fileString toPath:trashPath handler:nil];
#pragma GCC diagnostic pop
	}
	
	if (!moveResult) {
		printf("Could not move \"%s\" to the trash!\n\t(Perhaps you don't have sufficient privileges?)\n\n", [fileString UTF8String]);
		if ([manager fileExistsAtPath:trashPath]) {
			
			if ([manager respondsToSelector:@selector(removeItemAtURL:error:)]) {
				[manager removeItemAtURL:[NSURL fileURLWithPath:trashPath] error:nil];
			} else {
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
				// Fallback to now deprecated method
				[manager removeFileAtPath:trashPath handler:nil];
#pragma GCC diagnostic pop
			}
		}
		return;
	}
}

int main(int argc, char *argv[]) {
	NSAutoreleasePoolInit
	NSString *file, *userStr = @"";
	int c, i;
	
	if (argc == 1) {
		printf("USAGE: %s [-h] [-v] [-u USERNAME] FILENAME\n\n", argv[0]);
		NSAutoreleasePoolReleaseExit
		return 1;
	}
	
	while ((c = getopt(argc, argv, "u:hv")) != EOF) {
		switch (c) {
			case 'u':
				userStr = [NSString stringWithUTF8String:optarg];
				break;
			case 'h':
				printf("rmtrash options:\n\n");
				printf("\t-u USERNAME\tmove the file to some other user's trash.\n");
				printf("\t\t\t(note that you need sufficient privileges to do this.)\n");
				printf("\t-h\t\tthis screen\n");
				printf("\t-v\t\tprint out version info\n\n");
				NSAutoreleasePoolReleaseExit
				return 0;
				break;
			case 'v':
				printf("rmtrash version 0.3.4\n\tCopyright 2003 Night Productions\n\tCopyright 2015 Sebastian Keller\n\n");
				NSAutoreleasePoolReleaseExit
				return 0;
				break;
			default:
				printf("USAGE: %s [-h] [-v] [-u USERNAME] FILENAME\n\n",argv[0]);
				NSAutoreleasePoolReleaseExit
				return 0;
				break;
		}
	}
	
	for (i = optind; i < argc; i++) {
		file = [NSString stringWithUTF8String:argv[i]];
		move_to_trash(userStr, file);
		file = nil;
	}
	
	NSAutoreleasePoolReleaseFinal
	return 0;
}

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

#define MY_PRINT(_fmt, ...) printf("%s: " _fmt, getprogname(), ##__VA_ARGS__)
#define EXIT_USAGE_FAILURE do {\
printf("USAGE: %s [-h] [-v] [-u USERNAME] FILENAME\n", argv[0]); \
NSAutoreleasePoolReleaseExit \
return 1;\
}while(0);

#define manager [NSFileManager defaultManager]
#define ERROR_MESSAGE_KEY @"message"

NSString *getTrashFilePath(NSString* userString, NSString *fileName, NSError **error) {
	BOOL wantsErrorInfo = !!error;
	
	fileName = [[NSString stringWithFormat:@"~%@/.Trash/%@", (userString?:@""), [fileName lastPathComponent]] stringByExpandingTildeInPath];
	
	if (![manager fileExistsAtPath:[[NSString stringWithFormat:@"~%@/.Trash", (userString?:@"")] stringByExpandingTildeInPath]]) {
		if (wantsErrorInfo) {
			*error = [NSError errorWithDomain:@"" code:1 userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"%@: Unknown user!",(userString?:@"")] forKey:ERROR_MESSAGE_KEY]];
		}
		return nil;
	}
	
	if (![manager fileExistsAtPath:fileName]) {
		
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
		
		BOOL first = YES;
		NSString *copyName;
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
		fileName = copyName;
	}
	return fileName;
}

BOOL moveFileToUserTrash(NSString *userString, NSString *filePath, BOOL showErrors) {
	NSString *trashFilePath = nil;
	filePath = [filePath stringByExpandingTildeInPath];
	
	if (![manager fileExistsAtPath:filePath]) {
		if(showErrors){
			MY_PRINT("%s: File or directory does not exist.\n", [filePath UTF8String]);
		}
		return NO;
	}
	
	//new trash method always puts item into current users trash, so dont use it when user set.
	//but supports put back via cmd+Z in Finder
	BOOL useNewTrashMethod = !userString && [manager respondsToSelector:@selector(trashItemAtURL:resultingItemURL:error:)];
	
	if (!useNewTrashMethod) {
		NSError* error = nil;
		trashFilePath = getTrashFilePath(userString, filePath, &error);
		if (error) {
			if(showErrors){
				MY_PRINT("%s", [[[error userInfo] objectForKey:ERROR_MESSAGE_KEY] UTF8String]);
			}
			return NO;
		}
	}
	
	BOOL moveResult = YES;
	
	if (useNewTrashMethod) {
		NSURL* movedURL = nil;
		moveResult = [manager trashItemAtURL:[NSURL fileURLWithPath:filePath] resultingItemURL:&movedURL error:nil];
		trashFilePath = [movedURL path];
	} else if ([manager respondsToSelector:@selector(moveItemAtURL:toURL:error:)]) {
		moveResult = [manager moveItemAtURL:[NSURL fileURLWithPath:filePath] toURL:[NSURL fileURLWithPath:trashFilePath] error:nil];
	} else {
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
		// Fallback to now deprecated method
		moveResult = [manager movePath:filePath toPath:trashFilePath handler:nil];
#pragma GCC diagnostic pop
	}
	
	if (!moveResult) {
		if(showErrors){
			MY_PRINT("Could not move \"%s\" to the trash!\n\t(Perhaps you don't have sufficient privileges?)\n", [filePath UTF8String]);
		}
		
		//if file was moved to trash but operation failed, try to remove it
		if ([manager fileExistsAtPath:trashFilePath]) {
			
			if ([manager respondsToSelector:@selector(removeItemAtURL:error:)]) {
				[manager removeItemAtURL:[NSURL fileURLWithPath:trashFilePath] error:nil];
			} else {
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
				// Fallback to now deprecated method
				[manager removeFileAtPath:trashFilePath handler:nil];
#pragma GCC diagnostic pop
			}
		}
		return NO;
	}
	return YES;
}

int main(int argc, char *argv[]) {
	NSAutoreleasePoolInit
	NSString *file, *userStr = nil;
	int c, i, rval = 0;
	BOOL showErrors = YES, hasMovedFile = NO, dotDirWarningPrinted = NO;
	
	if (argc == 1) {
		EXIT_USAGE_FAILURE;
	}
	
	while ((c = getopt(argc, argv, "u:hvdfiPRr")) != EOF) {
		switch (c) {
			case 'u':
				userStr = [NSString stringWithUTF8String:optarg];
				break;
			case 'h':
				puts("rmtrash options:\n");
				puts("\t-u USERNAME\tmove the file to some other user's trash.");
				puts("\t\t\t(note that you need sufficient privileges to do this.)");
				puts("\t-f\t\tsuppress output and ignore errors");
				puts("\t-h\t\tthis screen");
				puts("\t-v\t\tprint out version info");
				NSAutoreleasePoolReleaseExit
				return rval;
				break;
			case 'v':
				puts("rmtrash version 0.3.5\n\tCopyright 2003\t\tNight Productions\n\tCopyright 2015-2016\tSebastian Keller");
				NSAutoreleasePoolReleaseExit
				return rval;
				break;
			case 'f':
				showErrors = NO;
				break;
			case 'd':
			case 'i':
			case 'P':
			case 'R':
			case 'r':
				//ignore rm options, except -W, since -W option of rm wants to undelete
				break;
			default:
				EXIT_USAGE_FAILURE;
				break;
		}
	}
	
	for (i = optind; i < argc; i++) {
		file = [NSString stringWithUTF8String:argv[i]];
		if([file isEqualToString:@"."] || [file isEqualToString:@".."]){
			if(!dotDirWarningPrinted){
				dotDirWarningPrinted = YES;
				MY_PRINT("\".\" and \"..\" may not be removed\n");
				rval = 1;
			}
		} else {
			hasMovedFile = moveFileToUserTrash(userStr, file, showErrors);
			if(showErrors && !hasMovedFile){
				rval = 1;
			}
		}
		file = nil;
	}
	
	NSAutoreleasePoolReleaseFinal
	return rval;
}

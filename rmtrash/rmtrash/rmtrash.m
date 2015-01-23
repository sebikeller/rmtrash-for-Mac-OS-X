//
//  main.m
//  rmtrash
//
//  Created by Sebastian Keller on 22.01.15.
//  Copyright (c) 2015 sebikeller.
//  Copyright (c) 2003-2005 nightproductions.net.
//
//  modified from http://www.nightproductions.net/downloads/rmtrash_source.tar.gz
//

#import <Foundation/Foundation.h>
#import <unistd.h>

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

#define NSAutoreleasePoolInit NSAutoreleasePool *pool=[[NSAutoreleasePool alloc]init];
#define NSAutoreleasePoolDrain [pool drain];
#define NSAutoreleasePoolReleaseExit [pool release];
#define NSAutoreleasePoolReleaseFinal [pool release];

#endif

#endif

#ifndef __MAC_10_5
#define __MAC_10_5 1050
#endif

#ifndef __MAC_10_4
#define __MAC_10_4 1040
#endif

#if __MAC_OS_X_VERSION_MAX_ALLOWED >= __MAC_10_5
#define movePath_toPath(__manager, __path, __toPath) [__manager moveItemAtURL:[NSURL fileURLWithPath:__path] toURL:[NSURL fileURLWithPath:__toPath] error:nil]
#define removeFileAtPath(__manager, __path) [__manager removeItemAtURL:[NSURL fileURLWithPath:__path] error:nil]
#else
#define movePath_toPath(__manager, __path, __toPath) [__manager movePath:__path toPath:__toPath handler:nil]
#define removeFileAtPath(__manager, __path) [__manager removeFileAtPath:__path handler:nil]
#endif

#define manager [NSFileManager defaultManager]

NSString *trashFileName(NSString *fileName)
{
	NSString *ext=[[fileName lastPathComponent] pathExtension];
	NSDateFormatter *df = nil;
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= __MAC_10_4
	df = NSAutorelease([[NSDateFormatter alloc] init]);
	//for 10.4 set new behaviour
	[df setFormatterBehavior:NSDateFormatterBehavior10_4];
	[df setDateFormat:@"HH-mm-ss"];
#else
	df = NSAutorelease([[NSDateFormatter alloc] initWithDateFormat:@"%H-%M-%S" allowNaturalLanguage:YES]);
#endif
	NSString *copyName;
	BOOL first = YES;
	do {
		if (!first) {
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= __MAC_10_4
			[df setDateFormat:@"HH-mm-ss-SSS"];
#else
			df = NSAutorelease([[NSDateFormatter alloc] initWithDateFormat:@"%H-%M-%S-%F" allowNaturalLanguage:YES]);
#endif
		}
		NSString *dateString = [df stringFromDate:[NSDate date]];
		if ([ext length] > 0) {
			NSString *tempName=[fileName substringWithRange:NSMakeRange(0,([fileName length] - ([ext length] + 1)))];
			copyName=[[NSString alloc]initWithFormat:@"%@ %@.%@",tempName,dateString,ext];
		} else {
			copyName=[[NSString alloc]initWithFormat:@"%@ %@",fileName,dateString];
		}
		first = NO;
	} while ([manager fileExistsAtPath:copyName]);
	
	return NSAutorelease(copyName);
}

void move_to_trash(NSString *userString, NSString *thefile)
{
	NSString *fileString=thefile;
	unichar firstChar=[fileString characterAtIndex:0];
	NSString *trashPath=nil;
	
	if (firstChar == '~') {
		fileString=[thefile stringByExpandingTildeInPath];
	}
	
	if (![manager fileExistsAtPath:fileString]) {
		printf("%s: File or directory does not exist.\n",[fileString UTF8String]);
		return;
	}
	
	trashPath=[[NSString stringWithFormat:@"~%@/.Trash/%@",userString,[fileString lastPathComponent]]stringByExpandingTildeInPath];
	
	if (![manager fileExistsAtPath:[[NSString stringWithFormat:@"~%@/.Trash",userString]stringByExpandingTildeInPath]]) {
		printf("%s: Unknown user!\n",[userString UTF8String]);
		return;
	}
	if ([manager fileExistsAtPath:trashPath]) {
		trashPath = trashFileName(trashPath);
	}
	if (!movePath_toPath(manager, fileString, trashPath)) {
		printf("Could not move \"%s\" to the trash!\n\t(Perhaps you don't have sufficient privileges?)\n\n",[fileString UTF8String]);
		if ([manager fileExistsAtPath:trashPath]) {
			removeFileAtPath(manager, trashPath);
		}
		return;
	}
}

int main(int argc, char *argv[])
{
	NSAutoreleasePoolInit
	NSString *file, *userStr=@"";
	int c,i;
	
	if (argc == 1) {
		printf("USAGE: %s [-h] [-v] [-u USERNAME] FILENAME\n\n",argv[0]);
		NSAutoreleasePoolReleaseExit
		return 1;
	}
	
	while ((c=getopt(argc, argv, "u:hv")) != EOF) {
		switch (c) {
			case 'u':
				userStr=[NSString stringWithUTF8String:optarg];
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
				printf("rmtrash version 0.3.3\n\tCopyright 2003 Night Productions\n\n");
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
	
	for (i= optind; i < argc; i++) {
		file=[NSString stringWithUTF8String:argv[i]];
		move_to_trash(userStr, file);
		file=nil;
	}
	
	NSAutoreleasePoolReleaseFinal
	return 0;
}

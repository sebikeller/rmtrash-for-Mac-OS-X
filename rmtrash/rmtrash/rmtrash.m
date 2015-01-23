#import <Foundation/Foundation.h>
#import <unistd.h>

#define manager [NSFileManager defaultManager]

NSString *copyNumber(NSString *fileName,int copyNum)
{
    NSString *ext=[[fileName lastPathComponent] pathExtension];
    NSString *returnString;
    if ([ext length] > 0) {
	NSString *tempName;
	if (copyNum > 1) {
	    tempName=[fileName substringWithRange:NSMakeRange(0,([fileName length] - ([ext length] + 2)))];
	} else {
	    tempName=[fileName substringWithRange:NSMakeRange(0,([fileName length] - ([ext length] + 1)))];
	}
	returnString=[[NSString alloc]initWithFormat:@"%@%i.%@",tempName,copyNum,ext];
    } else {
	NSString *tempName=fileName;
	if (copyNum > 1) {
	    tempName=[fileName substringWithRange:NSMakeRange(0,([fileName length] - 1))];
	}
	returnString=[[NSString alloc]initWithFormat:@"%@%i",tempName,copyNum];
    }
    
    if ([manager fileExistsAtPath:returnString]) {
	NSString *tempString=[NSString stringWithString:copyNumber(returnString,(copyNum + 1))];
	[returnString release];
	returnString=[[NSString alloc]initWithString:tempString];
    }
    
    return [returnString autorelease];
}

NSString *trashFileName(NSString *fileName)
{
    NSString *ext=[[fileName lastPathComponent] pathExtension];
    NSString *copyName;
    if ([ext length] > 0) {
	NSString *tempName=[fileName substringWithRange:NSMakeRange(0,([fileName length] - ([ext length] + 1)))];
	copyName=[[NSString alloc]initWithFormat:@"%@ Copy.%@",tempName,ext];
    } else {
	copyName=[[NSString alloc]initWithFormat:@"%@ Copy",fileName];
    }
    
    if ([manager fileExistsAtPath:copyName]) {
	NSString *tempString=[NSString stringWithString:copyNumber(copyName,1)];
	[copyName release];
	copyName=[[NSString alloc]initWithString:tempString];
    }
    return [copyName autorelease];
}

void move_to_trash(BOOL user, NSString *userString, NSString *thefile)
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
		//file exists in trash with this name...
		NSString *copyString=[NSString stringWithString:trashFileName(trashPath)];
		if (![manager movePath:fileString toPath:copyString handler:nil]) {
			printf("Could not move \"%s\" to the trash!\n\t(Perhaps you don't have sufficient privileges?)\n\n",[fileString UTF8String]);
			if ([manager fileExistsAtPath:copyString]) {
				[manager removeFileAtPath:copyString handler:nil];
			}
			return;
		}
	} else if (![manager movePath:fileString toPath:trashPath handler:nil]) {
		printf("Could not move \"%s\" to the trash!\n\t(Perhaps you don't have sufficient privileges?)\n\n",[fileString UTF8String]);
		if ([manager fileExistsAtPath:trashPath]) {
			[manager removeFileAtPath:trashPath handler:nil];
		}
		return;
	}
}

int main(int argc, char *argv[])
{
    NSAutoreleasePool *pool=[[NSAutoreleasePool alloc]init];
    NSString *file, *userStr=@"";
    BOOL user=NO;
    int c,i;

    if (argc == 1) {
	printf("USAGE: %s [-h] [-v] [-u USERNAME] FILENAME\n\n",argv[0]);
	[pool release];
	return 1;
    }
	
    while ((c=getopt(argc, argv, "uhv")) != EOF) {
	switch (c) {
	    case 'u':
		user=YES;
		break;
	    case 'h':
		printf("rmtrash options:\n\n");
		printf("\t-u USERNAME\tmove the file to some other user's trash.\n");
		printf("\t\t\t(note that you need sufficient privileges to do this.)\n");
		printf("\t-h\t\tthis screen\n");
		printf("\t-v\t\tprint out version info\n\n");
		[pool release];
		return 0;
		break;
	    case 'v':
		printf("rmtrash version 0.3.3\n\tCopyright 2003 Night Productions\n\n");
		[pool release];
		return 0;
		break;
	    default:
		printf("USAGE: %s [-h] [-v] [-u USERNAME] FILENAME\n\n",argv[0]);
		return 0;
		break;
	}
    }
	
    if (user)
	userStr=[NSString stringWithUTF8String:argv[2]];

    for (i= optind; i < argc; i++) {
	if (user && (i == 2)) {
	    //skip it
	} else {
	    file=[NSString stringWithUTF8String:argv[i]];
	    move_to_trash(user, userStr, file);
	    file=nil;
	}
    }
	
    [pool release];
    return 0;
}

//
//  MGStreams.m
//  ServerSide
//
//  Created by Maria Grynychyn on 12/19/14.
//  Copyright (c) 2014 Maria Grynychyn. All rights reserved.
//

#import "MGStreams.h"
#import <AppKit/AppKit.h>
static NSString * kFileSystemKey = @"NSURLIsDirectoryKey";
static uint8_t documents=225;
static uint8_t quit=255;

@interface MGStreams()<NSStreamDelegate>
@property (nonatomic, strong, readwrite) NSInputStream * fileInputStream;
@property (strong,nonatomic) NSMutableArray *items;
@property (nonatomic, assign, readwrite) NSUInteger streamOpenCount;
@property BOOL spaceAvailable;
@property long fileSize;

@end

@implementation MGStreams

- (id)initWithStreams:(NSInputStream *)inputStream outputStream:(NSOutputStream *)outputStream
// See comment in header.
{
    assert( (inputStream != nil) &&  (outputStream != nil) );
   
    self = [super init];
    
    if (self != nil) {
        
        self.inputStream=inputStream;
        self.outputStream=outputStream;
        
    }
    self.spaceAvailable=YES;

   [self openStreams];
    return self;
}



- (void)openStreams
{
    assert(self.inputStream != nil);            // streams must exist but aren't open
    assert(self.outputStream != nil);
   
    [self.inputStream  scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.inputStream setDelegate:self];
    [self.inputStream  open];
    
    [self.outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.outputStream setDelegate:self];
    [self.outputStream open];
}

- (void)closeStreams
{
    assert( (self.inputStream != nil) == (self.outputStream != nil) );      // should either have both or neither
    if (self.inputStream != nil) {
//        [self.server closeOneConnection:self];
        
        [self.inputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [self.inputStream close];
        self.inputStream = nil;
        
        [self.outputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [self.outputStream close];
        self.outputStream = nil;
    }    
}

- (void)closeFileInputStream
{
    [self.fileInputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.fileInputStream close];
    
    self.fileInputStream = nil;
}

- (void)sendArray:(NSArray *)array
{
    unichar buffer[8192];
   
    NSInteger bytesWritten=0;
    NSURL *myURL;
    id num;
    NSNumber *size;
    NSString *longString=[NSString string];
   
    NSString *colon=@":";
    NSEnumerator *en=[array objectEnumerator];
    while(myURL=[en nextObject]){
        
        [myURL getResourceValue:&num forKey:@"NSURLIsDirectoryKey" error:nil];
        longString = [[longString stringByAppendingString:[myURL lastPathComponent]] stringByAppendingString:colon];
        longString = [[longString stringByAppendingString:[(NSNumber*)num stringValue] ] stringByAppendingString:colon];
        if(![num boolValue]){
            [myURL getResourceValue:&size forKey:@"NSURLFileSizeKey" error:nil];
            longString = [[longString stringByAppendingString:[size stringValue] ] stringByAppendingString:colon];
        }
        if(longString.length >4000)
            break;
    }
   
    NSNumber *stringLength=[NSNumber numberWithLong:longString.length];
    NSString *shortString=[[stringLength stringValue] stringByAppendingString:colon];
    longString=[shortString stringByAppendingString:longString];
    
    
    
    [longString getCharacters:buffer];
    if([_outputStream hasSpaceAvailable])
          bytesWritten=[_outputStream write:(uint8_t *)buffer maxLength: ([longString length]*sizeof(unichar))];

     
}

-(void) sendFile:(NSURL *)file{
    
    
    
    NSNumber *size;
    
    self.fileInputStream = [NSInputStream inputStreamWithURL:file];
    //   [self.fileInputStream setDelegate:self];
    [self.fileInputStream scheduleInRunLoop:[NSRunLoop currentRunLoop]
                                    forMode:NSDefaultRunLoopMode];
    
    [file getResourceValue:&size forKey:@"NSURLFileSizeKey" error:nil];
    self.fileSize=[size longValue];
    
    [self.fileInputStream open];
    
    dispatch_async( dispatch_get_main_queue(), ^ {
        static  uint8_t     buffer[4096];
        NSInteger bytesRead, bytesWritten=0;
                while([self.fileInputStream hasBytesAvailable])
                {

             
             bytesRead = [self.fileInputStream read:buffer maxLength:sizeof(buffer)];
        
             if(bytesRead>0){
            
                 bytesWritten = [self.outputStream write:buffer maxLength:bytesRead];
                
                 self.fileSize-=bytesWritten;
            
                 if(bytesWritten<bytesRead){
                     bytesWritten = [self.outputStream write:buffer+sizeof(buffer)-(bytesRead-bytesWritten) maxLength:bytesRead-bytesWritten];
                     
                
                     self.fileSize-=bytesWritten;
                 }
            }
         
        
    }
        
        if(self.fileSize==0){
            
            [self.delegate logWithFormat:[self.clientName stringByAppendingString:@" downloaded file: %@. "] name: file.lastPathComponent];
            [self closeFileInputStream];
            
        }
     });
    
    
}

#pragma mark - NSStreamDelegate

- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode
{
    
    //    static  uint8_t     buffer[1024];
#pragma unused(stream)
    
    switch(eventCode) {
            
        case NSStreamEventOpenCompleted: {
            self.streamOpenCount += 1;
            assert(self.streamOpenCount <= 2);
            
            if (self.streamOpenCount == 2)
                [self.delegate logWithFormat:@"%@ connected to server." name: self.clientName];
            
        } break;
            
        case NSStreamEventHasSpaceAvailable: {
           
             assert(stream == self.outputStream);
            
        
            
        } break;
            
        case NSStreamEventHasBytesAvailable: {
            assert(stream == self.inputStream);
            uint8_t     b[32];
            
            NSInteger   bytesRead;
            
            bytesRead = [self.inputStream read:b maxLength:sizeof(b)];
            
           
            if(bytesRead<=2){
                
                if(b[0]==quit){
                    [self.delegate terminate];
                   // exit (0);
                    [NSApp terminate:self];
                }
                
                if( b[0]==documents){
                    self.items=[self filesList];
                    
                    [self sendArray:_items];
                }
                else
                    if(b[0]<self.items.count && b[0]>=0){
                       
                        if([self isFile:(NSURL *)self.items[b[0]]] ){
                            
                            [self sendFile:(NSURL *)self.items[b[0]]];
                            
                        }
                        
                        else{
                            
                            [self sendArray:self.items];
                        }
                    }
            }
            //Error occurred; Restart;
            else {
                
                [self.delegate terminate];
                [self.delegate startBrowser];
               
            }
            
            
        }   break;
            
       
            // fall through
        case NSStreamEventErrorOccurred:
            [self closeStreams];
           
            // fall through
        case NSStreamEventEndEncountered: {
            
           
        } break;
        
        default:
            assert(NO);
    }
}

- (BOOL) isFile:(NSURL *)url{
    
    id num;
    [url getResourceValue:&num
                   forKey:kFileSystemKey
                    error:nil];
    
    if([(NSNumber*)num boolValue]==0)
        return YES;
    
    NSError *error;
    NSArray *keys=[NSArray arrayWithObject:kFileSystemKey ];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray* files = [fileManager contentsOfDirectoryAtURL:url
                                includingPropertiesForKeys:keys
                                                   options:NSDirectoryEnumerationSkipsHiddenFiles   error:&error];
    // if directory is empty - no reason to open it
/*    if(files.count==0)
        return NO;*/
    
    if(files.count>documents){
        NSRange range={0,documents };
   
          self.items=[NSMutableArray arrayWithArray:[files subarrayWithRange:range ]];
     }
    else
        self.items=[NSMutableArray arrayWithArray:files];
    
    return NO;
}

- (NSMutableArray* )filesList
{
    NSError *error;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if(self.baseUrl!=nil){
        
        NSArray *keys=[NSArray arrayWithObject:kFileSystemKey ];
    //    return myURL;
    
        NSArray* files = [fileManager contentsOfDirectoryAtURL:self.baseUrl
                                includingPropertiesForKeys:keys
                                                   options:NSDirectoryEnumerationSkipsHiddenFiles   error:&error];
        if(files.count<=documents)
        
        return [NSMutableArray arrayWithArray:files];
    // #of files in a directorty is >225, discard some so we do not crash
        else{
            NSRange range={0,documents };
        
            return [NSMutableArray arrayWithArray:[files subarrayWithRange:range ]];
        }
    }
    
    return nil;
}

@end

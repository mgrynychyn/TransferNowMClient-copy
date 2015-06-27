//
//  MGStreams.h
//  ServerSide
//
//  Created by Maria Grynychyn on 12/19/14.
//  Copyright (c) 2014 Maria Grynychyn. All rights reserved.
//

#import <Foundation/Foundation.h>
@protocol MGStreamsDelegate;

@interface MGStreams : NSObject
@property (nonatomic, strong, readwrite) NSInputStream *        inputStream;
@property (nonatomic, strong, readwrite) NSOutputStream *       outputStream;
@property (nonatomic, weak,   readwrite) id<MGStreamsDelegate>    delegate;
@property NSString * computerName;
@property NSString * clientName;
@property NSURL *baseUrl;

- (id)initWithStreams:(NSInputStream *)inputStream outputStream:(NSOutputStream *)outputStream;
- (void)openStreams;
- (void)closeStreams;

//- (void)sendArray:(NSArray *)array;
//- (void)sendFile:(NSURL *)file;
@end

@protocol MGStreamsDelegate
//- (void)logWithFormat:(NSString *)format, ...;
-(void)logWithFormat:(NSString *)format name:(NSString *)name;
- (void) terminate;
- (void) startBrowser;
@end
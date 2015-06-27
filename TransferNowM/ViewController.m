//
//  ViewController.m
//  TransferNowM
//
//  Created by Maria Grynychyn on 6/16/15.
//  Copyright (c) 2015 Maria Grynychyn. All rights reserved.
//

#import "ViewController.h"
#import "MGStreams.h"

static NSString * kBonjourType = @"_bft._tcp.";
static NSString * kDomain = @"local.";

@interface ViewController() <NSTableViewDataSource, NSTableViewDelegate, NSNetServiceDelegate, NSNetServiceBrowserDelegate,MGStreamsDelegate>
@property (weak) IBOutlet NSTableView *tableView;

@property (strong,nonatomic) NSMutableArray *messages;
@property MGStreams *connection;
@property (nonatomic, strong, readwrite) NSNetService * netService;
@property (nonatomic, strong, readwrite) NSMutableSet * runLoopModesMutable;
@property (nonatomic, strong, readwrite) NSNetServiceBrowser *  browser;
@property NSString *clientName;
@property BOOL status;
@property NSOpenPanel *directoryPanel;
@property NSURL *baseUrl;

@end

@implementation ViewController{
    
    NSDateFormatter *formatter;
    NSString *computerName;
    BOOL resolved;
}

#pragma mark * ApplicationDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    [self terminate];
    
    NSLog(@"WILL TERMINATE");
    
}

- (void)viewDidLoad {
    
    [super viewDidLoad];
    [self initializeMenu];
    
    self.messages = [NSMutableArray arrayWithCapacity:30];
    formatter=[self formatter];
    [_tableView setDelegate:self];
    [_tableView setDataSource:self];
    
    self.clientName=@"Client";
    
    
    BOOL isStale;
    NSData *bookmark=[[NSUserDefaults standardUserDefaults] objectForKey:@"BaseDirectory"];
    if(bookmark!=nil){
        self.baseUrl=[NSURL URLByResolvingBookmarkData:bookmark options:NSURLBookmarkResolutionWithSecurityScope relativeToURL:nil bookmarkDataIsStale:&isStale error:nil];
        
        if([self.baseUrl startAccessingSecurityScopedResource]){
            [self startBrowser];
        }
        
    }
    else{
        
        [self logWithFormat:@"%@" name:@"Select a directory to transfer files from using Menu->File->Open..."];
        NSLog(@"Select directory");
    }
    //   [self startBrowser];
}



- (void)startBrowser
// See comment in header.
{
    
    self.browser = [[NSNetServiceBrowser alloc] init];
    NSLog(@"Browser started");
    
    [self.browser setDelegate:self];
    [self.browser searchForServicesOfType:kBonjourType inDomain:kDomain];
    
    if(!self.status && (self.baseUrl!=nil)){
        [self logWithFormat:@"%@" name:@"Server started."];
        [self logWithFormat:@"Selected directory: %@." name:[self.baseUrl.description stringByReplacingOccurrencesOfString:@"file:" withString:@""]];
        NSLog(@"Selected directory is %@", [self.baseUrl.description stringByReplacingOccurrencesOfString:@"file:" withString:@""]);
    }
    
    self.status=YES;
    
    
}

#pragma mark * "NetServiceBrowser" delegate

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didRemoveService:(NSNetService *)service moreComing:(BOOL)moreComing
{
    assert(browser == self.browser);
    NSLog(@"Removed service");
    
    assert(service != nil);
    //    if ((self.netService!=nil) && [service isEqual:self.netService]){
    //        self.netService=nil;
    if ( ! moreComing ){
        [self.connection closeStreams];
        
    }
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didFindService:(NSNetService *)service moreComing:(BOOL)moreComing
{
    //   if(self.netService!=nil)
    //        return;
    assert(service!=nil);
    
    self.netService=service;
    
    NSLog(@"Did find a service");
    
    if ( ! moreComing )
    {
        resolved=NO;
        [self.netService setDelegate:self];
        [self.netService resolveWithTimeout:5.0];
        //      [self connectToService:self.netService];
        
    }
}

//NSNeteServiceDelegate
- (void)netServiceDidResolveAddress:(NSNetService *)netService
{
    if(!resolved){
        if(netService.name!=nil)
            self.clientName=netService.name;
        [self connectToService:self.netService];
        resolved=YES;
    }
    
}

- (void)netService:(NSNetService *)netService didNotResolve:(NSDictionary *)errorDict{
    
    NSLog (@"Did not resolve the address %@",errorDict.allKeys);
    NSLog (@"Did not resolve the address %@",errorDict.allValues);
    
    
}

- (void)connectToService:(NSNetService *)service
{
    BOOL                success;
    NSInputStream *     inStream;
    NSOutputStream *    outStream;
    
    assert(service != nil);
    
    
    success = [service getInputStream:&inStream outputStream:&outStream];
    
    
    if (  success ) {
        
        
        self.connection=[[MGStreams alloc] initWithStreams:inStream outputStream:outStream];
        [self.connection setDelegate:self];
        [self.connection setBaseUrl:self.baseUrl];
        [self.connection setComputerName:computerName];
        [self.connection setClientName:self.clientName];
        [self.connection openStreams];
        NSLog(@"Connected with stream status input: %lu output: %lu",(unsigned long)inStream.streamStatus,(unsigned long)outStream.streamStatus);
        
        
    }
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    
    return [self.messages count];
    
}

- (NSView *)tableView:(NSTableView *)tableView
   viewForTableColumn:(NSTableColumn *)tableColumn
                  row:(NSInteger)row {
    
    // Retrieve to get the @"MyView" from the pool or,
    // if no version is available in the pool, load the Interface Builder version
    NSTableCellView *result = [tableView makeViewWithIdentifier:@"MyCell" owner:self];
    
    result.textField.stringValue =[self.messages objectAtIndex:row];
    // Return the result
    return result;
}


#pragma mark - FileServer delegate


- (void)logWithFormat:(NSString *)format name:(NSString *)name{
    NSString * newMessage=[[self formatter] stringFromDate:[NSDate date]];
    newMessage=[newMessage stringByAppendingFormat:format,name];
    [self.messages addObject:newMessage];
    [self.tableView reloadData];
}


- (NSDateFormatter *) formatter{
    if(formatter!=nil)
        return formatter;
    formatter=[[NSDateFormatter alloc] init];
    [formatter setLocale:[NSLocale currentLocale]];
    
    [formatter setDateFormat:@"MM-dd-yyyy HH:mm:ss "];
    return formatter;
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];
    // Update the view, if already loaded.
}

-(void) terminate{
    
    if(self.netService!=nil)
        [self.netService stop];
    
    if(self.browser!=nil)
        [self.browser stop];
    
    [self.baseUrl stopAccessingSecurityScopedResource];
    
}

// Directory selection related

- (void) initializeMenu{
    
    NSMenu *menu=[NSApp mainMenu];
    NSMenuItem *file=[menu itemAtIndex:1];
    NSLog(@"Number of items %ld",(long)menu.numberOfItems);
    if([file hasSubmenu] ){
        
        NSMenu *fileMenu=file.submenu;
        NSMenuItem *open=[fileMenu itemAtIndex:1];
        [open setTarget:self];
        [open setAction:@selector(selectDirectory)];
        [[fileMenu itemAtIndex:1] setEnabled:YES];
        NSLog(@"Number of items in file submenu %ld",(long)fileMenu.numberOfItems);
        
    }
    
    NSOpenPanel* panel = [NSOpenPanel openPanel];
    panel.canChooseDirectories=YES;
    panel.canChooseFiles=NO;
    
    panel.prompt=@"Choose";
    self.directoryPanel=panel;
    
}
- (void) selectDirectory {
    
    if(self.directoryPanel!=nil)
        [self.directoryPanel beginWithCompletionHandler:^(NSInteger result){
            
            if (result == NSFileHandlingPanelOKButton) {
                NSURL*  theUrl = [[self.directoryPanel URLs] objectAtIndex:0];
                NSData *bookmark=[theUrl bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope includingResourceValuesForKeys:[NSArray arrayWithObject:NSURLIsDirectoryKey] relativeToURL:nil error:nil];
                theUrl=[NSURL URLByResolvingBookmarkData:bookmark options:NSURLBookmarkResolutionWithSecurityScope relativeToURL:nil bookmarkDataIsStale:NO error:nil];
                if(self.baseUrl!=nil)
                    [self.baseUrl stopAccessingSecurityScopedResource];
                if([theUrl startAccessingSecurityScopedResource]){
                    self.baseUrl=theUrl;
                    if(self.connection!=nil)
                        self.connection.baseUrl=theUrl;
                    [self logWithFormat:@"Selected directory: %@" name:[theUrl.description stringByReplacingOccurrencesOfString:@"file:" withString:@""]];
                    [[NSUserDefaults standardUserDefaults] setObject:bookmark forKey:@"BaseDirectory"];
                    if(!self.status)
                        [self startBrowser];
                    NSLog(@"Directory %@",theUrl.description);
                    
                }
                else
                    NSLog(@"Resource was not released");
                // Open  the document.
            }
            
            if (result == NSFileHandlingPanelCancelButton) {
                
                NSLog(@"Cancel clicked");
                
                // Open  the document.
            }
            
            
            
        }];
}


@end

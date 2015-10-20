//
//  ViewController.m
//  TransferNowM
//
//  Created by Maria Grynychyn on 6/16/15.
//  Copyright (c) 2015 Maria Grynychyn. All rights reserved.
//

#import "ViewController.h"
#include <sys/socket.h>
#import "MGStreams.h"
#import <dns_sd.h>


static NSString * kBonjourType = @"_bft._tcp.";
static NSString * kDomain = @"local.";
static NSString * kSrvName ;

static NSNetService *service;
static DNSServiceRef browseRef;
static DNSServiceRef resolveRef;

@interface ViewController() <NSTableViewDataSource, NSTableViewDelegate, NSNetServiceDelegate, NSNetServiceBrowserDelegate, MGStreamsDelegate>

@property (weak) IBOutlet NSTableView *tableView;
static void serviceFound(DNSServiceRef sdRef, DNSServiceFlags flags, uint32_t interfaceIndex, DNSServiceErrorType errorCode, const char *serviceName, const char *regtype, const char *replyDomain, void *context);


static void serviceResolved( DNSServiceRef sdRef, DNSServiceFlags flags, uint32_t interfaceIndex, DNSServiceErrorType errorCode, const char *fullname, const char *hosttarget, uint16_t port,  uint16_t txtLen, const unsigned char *txtRecord, void *context );

@property (strong,nonatomic) NSMutableArray *messages;
@property MGStreams *connection;
@property (nonatomic, strong, readwrite) NSNetService * netService;

@property (nonatomic, strong, readwrite) NSMutableSet * runLoopModesMutable;
@property (nonatomic, strong, readonly ) NSMutableSet * listeningSockets;

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
    
    
}

- (void)viewDidLoad {
    
    [super viewDidLoad];
    [self initializeMenu];
    
    self.messages = [NSMutableArray arrayWithCapacity:30];
    formatter=[self formatter];
    [_tableView setDelegate:self];
    [_tableView setDataSource:self];
    
    self.clientName=@"Client";
    self.runLoopModesMutable = [[NSMutableSet alloc] initWithObjects:NSDefaultRunLoopMode, nil];
   
    
    BOOL isStale;
    NSData *bookmark=[[NSUserDefaults standardUserDefaults] objectForKey:@"BaseDirectory"];
    if(bookmark!=nil){
        self.baseUrl=[NSURL URLByResolvingBookmarkData:bookmark options:NSURLBookmarkResolutionWithSecurityScope relativeToURL:nil bookmarkDataIsStale:&isStale error:nil];
        
        if([self.baseUrl startAccessingSecurityScopedResource]){
            if(!self.status && (self.baseUrl!=nil)){
                [self logWithFormat:@"%@" name:@"Server started."];
                [self logWithFormat:@"Selected directory: %@." name:[self.baseUrl.description stringByReplacingOccurrencesOfString:@"file:" withString:@""]];
                
            }
            
            self.status=YES;
            
            [self startBrowser];
            
        }
        
    }
    else{
        [self logWithFormat:@"%@" name:@"Select a directory for transfering files using Menu->TransferNowM->Select Directory"];
            }
    
    // Added
    
//    self->_listeningSockets = [[NSMutableSet alloc] init];
}

/*

- (void)startBrowser
// See comment in header.
{

    self.browser = [[NSNetServiceBrowser alloc] init];
    self.browser.includesPeerToPeer=YES;
    [self.browser setDelegate:self];
    [self.browser searchForServicesOfType:kBonjourType inDomain:kDomain];

    if(!self.status && (self.baseUrl!=nil)){
        [self logWithFormat:@"%@" name:@"Server started."];
        [self logWithFormat:@"Selected directory: %@." name:[self.baseUrl.description stringByReplacingOccurrencesOfString:@"file:" withString:@""]];
        
    }
    
    self.status=YES;
    
    
}

*/

- (void) startNetBrowser{
    NSLog(@"NetBrowser started");
    self.browser = [[NSNetServiceBrowser alloc] init];
    self.browser.includesPeerToPeer=YES;
    [self.browser setDelegate:self];
    [self.browser searchForServicesOfType:kBonjourType inDomain:kDomain];
    
}


- (void) anotherThread:(NSString *)refName{
    NSLog (@"Listening socket callback!");
    if([refName isEqual:@"Browse"])
        DNSServiceProcessResult(browseRef);
    else
        DNSServiceProcessResult(resolveRef);
}

-(void) startBrowser{
    char type[100];
    char domain[100];
    [kBonjourType getCString:type maxLength:sizeof(type) encoding:1];
    [kDomain getCString:domain maxLength:sizeof(domain) encoding:1];
     DNSServiceErrorType  errType=DNSServiceBrowse(&browseRef,kDNSServiceFlagsIncludeP2P,kDNSServiceInterfaceIndexAny,type,domain,serviceFound,(__bridge void *)(self));
    if(errType==kDNSServiceErr_NoError){
        
       NSThread *t = [[ NSThread alloc] initWithTarget:self selector:@selector(anotherThread:) object:@"Browse"];
        [t start];
       
    }
    
}


static void serviceFound(DNSServiceRef sdRef, DNSServiceFlags flags, uint32_t interfaceIndex, DNSServiceErrorType errorCode, const char *serviceName, const char *regtype, const char *replyDomain, void *context) {
    if(errorCode==kDNSServiceErr_NoError){
        NSLog(@"Service found - name %s, type %s domain %s", serviceName, regtype, replyDomain);
        kSrvName=[NSString stringWithCString:serviceName encoding:1];
    }
    else
        NSLog(@"Error %d", errorCode);

   DNSServiceErrorType  type=DNSServiceResolve(&resolveRef,kDNSServiceFlagsForceMulticast,interfaceIndex,serviceName,regtype,replyDomain,serviceResolved,context);
    if(type==kDNSServiceErr_NoError){
  
        DNSServiceProcessResult(resolveRef);
    }
   
}

static void serviceResolved( DNSServiceRef sdRef, DNSServiceFlags flags, uint32_t interfaceIndex, DNSServiceErrorType errorCode, const char *fullname, const char *hosttarget, uint16_t port, uint16_t txtLen, const unsigned char *txtRecord, void *context ){
    
    
    if(errorCode==kDNSServiceErr_NoError){
        
       
        dispatch_async(  dispatch_get_main_queue(), ^{ [(__bridge ViewController *)context startNetBrowser];});
    
        
    }
    

}



#pragma mark * "NetServiceBrowser" delegate

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didRemoveService:(NSNetService *)service moreComing:(BOOL)moreComing
{
    assert(browser == self.browser);
    
    assert(service != nil);
    //    if ((self.netService!=nil) && [service isEqual:self.netService]){
    //        self.netService=nil;
    if ( ! moreComing ){
        [self.connection closeStreams];
        [self logWithFormat:@"%@" name:@"Disconnected."];
    }
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didFindService:(NSNetService *)service moreComing:(BOOL)moreComing
{
    //   if(self.netService!=nil)
    //        return;
    assert(service!=nil);
    NSLog(@"Did find service %@",service);
    self.netService=service;
    
    if ( ! moreComing )
    {
        resolved=NO;
        [self.netService setDelegate:self];
       
        [self.netService resolveWithTimeout:5.0];
       
 //       [self connectToService:self.netService];
        
    }
    
}

//NSNetServiceDelegate
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
    
    if(self.netService!=nil){
        
   
        [self.netService stop];
  
    }
    
    
    if(self.browser!=nil)
        [self.browser stop];
    
    [self.baseUrl stopAccessingSecurityScopedResource];
    
   
}

// Directory selection related

- (void) initializeMenu{
    
    NSMenu *menu=[NSApp mainMenu];
    //Addition
    NSMenuItem *about, *quit;
    NSMenu *theMenu;
    NSArray *ar=[menu itemArray];
    if([(NSMenuItem *)ar[0] hasSubmenu])
        theMenu=((NSMenuItem *)ar[0]).submenu ;
    
    ar=[theMenu itemArray];
    for(NSMenuItem *item in ar){
        
        if([item.title containsString:@"About"])
            about=item;
        
        if([item.title containsString:@"Quit"])
            quit=item;
            
    }
    [menu removeItemAtIndex:0];
    NSMenuItem *one=[[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
    theMenu =[[NSMenu alloc] init];
    
    NSMenu * myMenu=[[NSMenu alloc] initWithTitle:@"TransferNowM"];
    
    if(about!=nil)
        [theMenu addItem:about];
    
    [theMenu addItemWithTitle:@"Select directory" action: @selector(selectDirectory) keyEquivalent:@""];
    if(quit!=nil)
        [theMenu addItem:quit];
    [[theMenu itemAtIndex:1] setTarget:self];
    [one setSubmenu:theMenu];
    [myMenu addItem:one];
    [NSApp setMainMenu:myMenu];
   //The end
/*
    NSMenuItem *file=[menu itemAtIndex:1];
   
    if([file hasSubmenu] ){
        
        NSMenu *fileMenu=file.submenu;
        NSMenuItem *open=[fileMenu itemAtIndex:1];
        [open setTarget:self];
        [open setAction:@selector(selectDirectory)];
        [[fileMenu itemAtIndex:1] setEnabled:YES];
       
        
    }
*/
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
                    
                    [[NSUserDefaults standardUserDefaults] setObject:bookmark forKey:@"BaseDirectory"];
          //          [[NSUserDefaults standardUserDefaults] setObject:nil forKey:@"BaseDirectory"];
                    if(!self.status)
                        [self startBrowser];
                    else
                        [self logWithFormat:@"Selected directory: %@" name:[theUrl.description stringByReplacingOccurrencesOfString:@"file:" withString:@""]]
                        ;
                   
                    
                }
                else
                   ;
                // Open  the document.
            }
            
            if (result == NSFileHandlingPanelCancelButton) {
                
                
                
                // Open  the document.
            }
            
            
            
        }];
}


@end

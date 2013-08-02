//
//  AppiumMacController.m
//  AppiumAppleScriptProxy
//
//  Created by Dan Cuellar on 7/28/13.
//  Copyright (c) 2013 Appium. All rights reserved.
//

#import "AppiumMacHandlers.h"
#import "AppiumMacHTTP303JSONResponse.h"
#import "NSData+Base64.h"
#import "Utility.h"

@implementation AppiumMacHandlers
- (id)init
{
    self = [super init];
    if (self) {
        [self setSessions:[NSMutableDictionary new]];
        [self setApplescript:[AppiumMacAppleScriptExecutor new]];
        [self setElementIndex:0];
        [self setElements:[NSMutableDictionary new]];
    }
    return self;
}

-(NSDictionary*) dictionaryFromPostData:(NSData*)postData
{
    if (!postData)
    {
        return [NSDictionary new];
    }
    
    NSError *error = nil;
    NSDictionary *postDict = [NSJSONSerialization JSONObjectWithData:postData options:NSJSONReadingMutableContainers error:&error];
    
    // TODO: error handling
    return postDict;
}

-(AppiumMacHTTPJSONResponse*) respondWithJson:(id)json status:(int)status session:(NSString*)session
{
    return [self respondWithJson:json status:status session:session statusCode:200];
}

-(AppiumMacHTTPJSONResponse*) respondWithJson:(id)json status:(int)status session:(NSString*)session statusCode:(NSInteger)statusCode
{
    NSMutableDictionary *responseJson = [NSMutableDictionary new];
    [responseJson setValue:[NSNumber numberWithInt:status] forKey:@"status"];
    if (session != nil)
    {
        [responseJson setValue:session forKey:@"sessionId"];
    }
    [responseJson setValue:json forKey:@"value"];

    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:responseJson
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&error];
    if (!jsonData)
    {
        NSLog(@"Got an error: %@", error);
        jsonData = [NSJSONSerialization dataWithJSONObject:
                    [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:-1], @"status", session, @"session", [NSString stringWithFormat:@"%@", error], @"value" , nil]
                                                   options:NSJSONWritingPrettyPrinted
                                                     error:&error];
    }
    switch (statusCode)
    {
        case 303:
            return [[AppiumMacHTTP303JSONResponse alloc] initWithData:jsonData];
        default:
            return [[AppiumMacHTTPJSONResponse alloc] initWithData:jsonData];
    }
}

// GET /status
-(AppiumMacHTTPJSONResponse*) getStatus:(NSString*)path
{
    NSDictionary *buildJson = [NSDictionary dictionaryWithObjectsAndKeys:[Utility bundleVersion], @"version", [Utility bundleRevision], @"revision", [NSString stringWithFormat:@"%d", [Utility unixTimestamp]], @"time", nil];
    NSDictionary *osJson = [NSDictionary dictionaryWithObjectsAndKeys:[Utility arch], @"arch", @"Mac OS X", @"name", [Utility version], @"version", nil];
    NSDictionary *json = [NSDictionary dictionaryWithObjectsAndKeys:buildJson, @"build", osJson, @"os", nil];
    return [self respondWithJson:json status:0 session:nil];
}

// POST /session
-(AppiumMacHTTPJSONResponse*) postSession:(NSString*)path data:(NSData*)postData
{
    // generate new session key
    NSString *newSession = [Utility randomStringOfLength:8];
    while ([self.sessions objectForKey:newSession] != nil)
    {
        newSession = [Utility randomStringOfLength:8];
    }
    
    // TODO: Add capabilities support
    // set empty capabilities for now
    [self.sessions setValue:@"" forKey:newSession];
    
    // respond with the session
    return [self respondWithJson:[self.sessions objectForKey:newSession] status:0 session: newSession];
}

// GET /sessions
-(AppiumMacHTTPJSONResponse*) getSessions:(NSString*)path
{
    // respond with the session
    NSMutableArray *json = [NSMutableArray new];
    for(id key in self.sessions)
    {
        [json addObject:[NSDictionary dictionaryWithObjectsAndKeys:key, @"id", [self.sessions objectForKey:key], @"capabilities", nil]];
    }
    
    return [self respondWithJson:json status:0 session: nil];
}

// GET /session/:sessionId
-(AppiumMacHTTPJSONResponse*) getSession:(NSString*)path
{
    NSString *sessionId = [Utility getSessionIDFromPath:path];
    // TODO: show error if session does not exist
    return [self respondWithJson:[self.sessions objectForKey:sessionId] status:0 session:sessionId];
}

// DELETE /session/:sessionId
-(AppiumMacHTTPJSONResponse*) deleteSession:(NSString*)path
{
    NSString *sessionId = [Utility getSessionIDFromPath:path];
    if ([self.sessions objectForKey:sessionId] != nil)
    {
        [self.sessions removeObjectForKey:sessionId];
    }
    return [self respondWithJson:nil status:0 session: sessionId];
}

// /session/:sessionId/timeouts
// /session/:sessionId/timeouts/async_script
// /session/:sessionId/timeouts/implicit_wait

// GET /session/:sessionId/window_handle
-(AppiumMacHTTPJSONResponse*) getWindowHandle:(NSString*)path
{
    NSString *sessionId = [Utility getSessionIDFromPath:path];
    // TODO: add error handling
    return [self respondWithJson:[self.applescript processForApplication:[self.applescript frontmostApplicationName]] status:0 session: sessionId];
}

// GET /session/:sessionId/window_handles
-(AppiumMacHTTPJSONResponse*) getWindowHandles:(NSString*)path
{
    NSString *sessionId = [Utility getSessionIDFromPath:path];
    // TODO: add error handling
    return [self respondWithJson:[self.applescript allProcesses] status:0 session: sessionId];
}

// GET /session/:sessionId/url
-(AppiumMacHTTPJSONResponse*) getUrl:(NSString*)path
{
    NSString *sessionId = [Utility getSessionIDFromPath:path];
    return [self respondWithJson:[self.applescript currentApplicationName] status:0 session: sessionId];
}

// POST /session/:sessionId/url
-(AppiumMacHTTPJSONResponse*) postUrl:(NSString*)path data:(NSData*)postData
{
    NSString *sessionId = [Utility getSessionIDFromPath:path];
    NSDictionary *postParams = [self dictionaryFromPostData:postData];
    
    // activate supplied application

    NSString *url = (NSString*)[postParams objectForKey:@"url"];
    [self.applescript activateApplication:url];
    [self.applescript setCurrentApplicationName:url];
    [self.applescript setCurrentProcessName:[self.applescript processForApplication:url]];
    // TODO: error handling
    return [self respondWithJson:nil status:0 session: sessionId];
}

// /session/:sessionId/forward
// /session/:sessionId/back
// /session/:sessionId/refresh
// /session/:sessionId/execute
// /session/:sessionId/execute_async

// GET /session/:sessionId/screenshot
-(HTTPDataResponse*) getScreenshot:(NSString*)path
{
    system([@"/usr/sbin/screencapture -c" UTF8String]);
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    NSArray *classArray = [NSArray arrayWithObject:[NSImage class]];
    NSDictionary *options = [NSDictionary dictionary];
    
    BOOL foundImage = [pasteboard canReadObjectForClasses:classArray options:options];
    if (foundImage)
    {
        NSArray *objectsToPaste = [pasteboard readObjectsForClasses:classArray options:options];
        NSImage *image = [objectsToPaste objectAtIndex:0];
        NSString *base64Image = [[image TIFFRepresentation] base64EncodedString];
        return [self respondWithJson:base64Image status:0 session:[Utility getSessionIDFromPath:path]];
    }
    else
    {
        return [self respondWithJson:nil status:0 session: [Utility getSessionIDFromPath:path]];
    }
}

// /session/:sessionId/ime/available_engines
// /session/:sessionId/ime/active_engine
// /session/:sessionId/ime/activated
// /session/:sessionId/ime/deactivate
// /session/:sessionId/ime/activate
// /session/:sessionId/frame

// POST /session/:sessionId/window
-(AppiumMacHTTPJSONResponse*) postWindow:(NSString*)path data:(NSData*)postData
{
    NSString *sessionId = [Utility getSessionIDFromPath:path];
    NSDictionary *postParams = [self dictionaryFromPostData:postData];

    // activate application for supplied process
    NSString *name = (NSString*)[postParams objectForKey:@"name"];
    NSString *applicationName = [self.applescript applicationForProcessName:name];
    [self.applescript activateApplication:applicationName];
    [self.applescript setCurrentApplicationName:applicationName];
    [self.applescript setCurrentProcessName:name];
    // TODO: error handling
    return [self respondWithJson:nil status:0 session: sessionId];
}

// DELETE /session/:sessionId/window
-(AppiumMacHTTPJSONResponse*) deleteWindow:(NSString*)path
{
    NSString *sessionId = [Utility getSessionIDFromPath:path];
    
    // kill supplied process
    int pid = [self.applescript pidForProcess:[self.applescript frontmostProcessName]];
    system([[NSString stringWithFormat:@"killall -9 %d", pid] UTF8String]);
    [self.applescript setCurrentApplicationName:nil];
    [self.applescript setCurrentProcessName:nil];
    
    // TODO: error handling
    return [self respondWithJson:nil status:0 session: sessionId];
}

// /session/:sessionId/window/:windowHandle/size
// /session/:sessionId/window/:windowHandle/position
// /session/:sessionId/window/:windowHandle/maximize
// /session/:sessionId/cookie
// /session/:sessionId/cookie/:name

// GET /session/:sessionId/source
-(AppiumMacHTTPJSONResponse*) getSource:(NSString*)path
{
    NSString *sessionId = [Utility getSessionIDFromPath:path];
    return [self respondWithJson:[self.applescript pageSource] status:0 session: sessionId];
}

// /session/:sessionId/title

// POST /session/:sessionId/element
-(AppiumMacHTTPJSONResponse*) postElement:(NSString*)path data:(NSData*)postData
{
    NSString *sessionId = [Utility getSessionIDFromPath:path];
    NSDictionary *postParams = [self dictionaryFromPostData:postData];
    
    NSString *using = (NSString*)[postParams objectForKey:@"using"];
    NSString *value = (NSString*)[postParams objectForKey:@"value"];
    
    if ([using isEqualToString:@"name"])
    {
        SystemEventsUIElement *element = [self.applescript elementByName:value baseElement:nil];
        if (element != nil)
        {
            self.elementIndex++;
            NSString *myKey = [NSString stringWithFormat:@"%d", self.elementIndex];
            [self.elements setValue:element forKey:myKey];
            return [self respondWithJson:[NSDictionary dictionaryWithObject:myKey forKey:@"ELEMENT"] status:0 session:sessionId];
        }
        // TODO: add error handling
        // TODO: elements are session based
    }
    
    return [self respondWithJson:nil status:-1 session: sessionId];
}

// /session/:sessionId/elements
// /session/:sessionId/element/active
// /session/:sessionId/element/:id
// /session/:sessionId/element/:id/element
// /session/:sessionId/element/:id/elements

// POST /session/:sessionId/element/:id/click
-(AppiumMacHTTPJSONResponse*) postElementClick:(NSString*)path
{
    NSString *sessionId = [Utility getSessionIDFromPath:path];
    NSString *elementId = [Utility getElementIDFromPath:path];
    SystemEventsUIElement *element = [self.elements objectForKey:elementId];
    if (element != nil)
    {
        [self.applescript clickElement:element];
    }
    // TODO: error handling
    return [self respondWithJson:nil status:0 session: sessionId];
}

// /session/:sessionId/element/:id/submit

// GET /session/:sessionId/element/:id/text
-(AppiumMacHTTPJSONResponse*) getElementText:(NSString*)path
{
    NSString *sessionId = [Utility getSessionIDFromPath:path];
    NSString *elementId = [Utility getElementIDFromPath:path];
    SystemEventsUIElement *element = [self.elements objectForKey:elementId];
    if (element != nil)
    {
        return [self respondWithJson:[NSString stringWithFormat:@"%@", [element value]] status:0 session: sessionId];
    }
    return [self respondWithJson:nil status:0 session: sessionId];
}

// POST /session/:sessionId/element/:id/value
-(AppiumMacHTTPJSONResponse*) postElementValue:(NSString*)path data:(NSData*)postData
{
    NSString *sessionId = [Utility getSessionIDFromPath:path];
    NSString *elementId = [Utility getElementIDFromPath:path];
    NSDictionary *postParams = [self dictionaryFromPostData:postData];
    
    NSArray *value = [postParams objectForKey:@"value"];
    [self.applescript sendKeys:[value componentsJoinedByString:@""] toElement:[self.elements objectForKey:elementId]];
    
    // TODO: add error handling
    // TODO: elements are session based
    
    return [self respondWithJson:nil status:0 session: sessionId];
}

// POST /session/:sessionId/keys
-(AppiumMacHTTPJSONResponse*) postKeys:(NSString*)path data:(NSData*)postData
{
    NSString *sessionId = [Utility getSessionIDFromPath:path];
    NSDictionary *postParams = [self dictionaryFromPostData:postData];
    
    NSArray *value = [postParams objectForKey:@"value"];
    [self.applescript sendKeys:[value componentsJoinedByString:@""] toElement:nil];

    // TODO: add error handling
    // TODO: elements are session based
    
    return [self respondWithJson:nil status:0 session: sessionId];
}

// GET /session/:sessionId/element/:id/name
-(AppiumMacHTTPJSONResponse*) getElementName:(NSString*)path
{
    NSString *sessionId = [Utility getSessionIDFromPath:path];
    NSString *elementId = [Utility getElementIDFromPath:path];
    SystemEventsUIElement *element = [self.elements objectForKey:elementId];
    if (element != nil)
    {
        return [self respondWithJson:element.name status:0 session: sessionId];
    }
    return [self respondWithJson:nil status:0 session: sessionId];
}

// POST /session/:sessionId/element/:id/clear
-(AppiumMacHTTPJSONResponse*) postElementClear:(NSString*)path
{
    NSString *sessionId = [Utility getSessionIDFromPath:path];
    NSString *elementId = [Utility getElementIDFromPath:path];
    SystemEventsUIElement *element = [self.elements objectForKey:elementId];
    id value = [element value];
    if (value != nil && [value isKindOfClass:[NSString class]])
    {
        [element setValue:@""];
    }
    
    // TODO: Add error handling
    return [self respondWithJson:nil status:0 session: sessionId];
}

// GET /session/:sessionId/element/:id/selected
-(AppiumMacHTTPJSONResponse*) getElementIsSelected:(NSString*)path
{
    NSString *sessionId = [Utility getSessionIDFromPath:path];
    NSString *elementId = [Utility getElementIDFromPath:path];
    SystemEventsUIElement *element = [self.elements objectForKey:elementId];
    if (element != nil)
    {
        return [self respondWithJson:[NSNumber numberWithBool:element.focused] status:0 session: sessionId];
    }
    return [self respondWithJson:nil status:0 session:sessionId];
}

// GET /session/:sessionId/element/:id/enabled
-(AppiumMacHTTPJSONResponse*) getElementIsEnabled:(NSString*)path
{
    NSString *sessionId = [Utility getSessionIDFromPath:path];
    NSString *elementId = [Utility getElementIDFromPath:path];
    SystemEventsUIElement *element = [self.elements objectForKey:elementId];
    if (element != nil)
    {
        return [self respondWithJson:[NSNumber numberWithBool:element.enabled] status:0 session: sessionId];
    }
    return [self respondWithJson:nil status:0 session:sessionId];
}

// GET /session/:sessionId/element/:id/attribute/:name
-(AppiumMacHTTPJSONResponse*) getElementAttribute:(NSString*)path
{
    NSString *sessionId = [Utility getSessionIDFromPath:path];
    NSString *elementId = [Utility getElementIDFromPath:path];
    NSString *attributeName = [Utility getItemFromPath:path withSeparator:@"/attribute/"];
    
    SystemEventsUIElement *element = [self.elements objectForKey:elementId];
    if (element != nil)
    {
        for (SBObject *attribute in element.attributes)
        {
            if ([attribute.key isEqualToString:attributeName])
            {
                return [self respondWithJson:attribute.value status:0 session: sessionId];
            }
        }
    }
    return [self respondWithJson:nil status:0 session:sessionId];
}

// GET /session/:sessionId/element/:id/equals/:other
-(AppiumMacHTTPJSONResponse*) getElementIsEqual:(NSString*)path
{
    NSString *sessionId = [Utility getSessionIDFromPath:path];
    NSString *elementId = [Utility getElementIDFromPath:path];
    NSString *otherElementId = [Utility getItemFromPath:path withSeparator:@"/equals/"];
    SystemEventsUIElement *element = [self.elements objectForKey:elementId];
    SystemEventsUIElement *otherElement = [self.elements objectForKey:otherElementId];
    return [self respondWithJson:[NSNumber numberWithBool:[element isEqualTo:otherElement]] status:0 session:sessionId];
}

// /session/:sessionId/element/:id/displayed

// GET /session/:sessionId/element/:id/location
-(AppiumMacHTTPJSONResponse*) getElementLocation:(NSString*)path
{
    NSString *sessionId = [Utility getSessionIDFromPath:path];
    NSString *elementId = [Utility getElementIDFromPath:path];
    SystemEventsUIElement *element = [self.elements objectForKey:elementId];
    if (element != nil)
    {
        return [self respondWithJson:element.position status:0 session: sessionId];
    }
    // TODO: Add error handling
    return [self respondWithJson:nil status:0 session:sessionId];
}

// /session/:sessionId/element/:id/location_in_view


// GET /session/:sessionId/element/:id/size
-(AppiumMacHTTPJSONResponse*) getElementSize:(NSString*)path
{
    NSString *sessionId = [Utility getSessionIDFromPath:path];
    NSString *elementId = [Utility getElementIDFromPath:path];
    SystemEventsUIElement *element = [self.elements objectForKey:elementId];
    if (element != nil)
    {
        return [self respondWithJson:element.size status:0 session: sessionId];
    }
    // TODO: Add error handling
    return [self respondWithJson:nil status:0 session:sessionId];
}

// /session/:sessionId/element/:id/css/:propertyName
// /session/:sessionId/orientation
// /session/:sessionId/alert_text
// /session/:sessionId/accept_alert
// /session/:sessionId/dismiss_alert
// /session/:sessionId/moveto
// /session/:sessionId/click
// /session/:sessionId/buttondown
// /session/:sessionId/buttonup
// /session/:sessionId/doubleclick
// /session/:sessionId/touch/click
// /session/:sessionId/touch/down
// /session/:sessionId/touch/up
// /session/:sessionId/touch/move
// /session/:sessionId/touch/scroll
// /session/:sessionId/touch/scroll
// /session/:sessionId/touch/doubleclick
// /session/:sessionId/touch/longclick
// /session/:sessionId/touch/flick
// /session/:sessionId/touch/flick
// /session/:sessionId/location
// /session/:sessionId/local_storage
// /session/:sessionId/local_storage/key/:key
// /session/:sessionId/local_storage/size
// /session/:sessionId/session_storage
// /session/:sessionId/session_storage/key/:key
// /session/:sessionId/session_storage/size
// /session/:sessionId/log
// /session/:sessionId/log/types
// /session/:sessionId/application_cache/status

@end
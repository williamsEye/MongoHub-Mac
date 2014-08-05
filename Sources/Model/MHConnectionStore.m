//
//  MHConnectionStore.m
//  MongoHub
//
//  Created by Syd on 10-4-24.
//  Copyright 2010 MusicPeace.ORG. All rights reserved.
//

#import "MHConnectionStore.h"
#import "MHKeychain.h"

#define MAX_QUERY_PER_COLLECTION 20
#define QUERY_HISTORY_KEY @"query_history"
#define SORTED_TITLE_KEY @"sorted_titles"
#define QUERY_KEY @"queries"

@implementation MHConnectionStore

@dynamic servers;
@dynamic repl_name;
@dynamic alias;
@dynamic adminuser;
@dynamic defaultdb;
@dynamic userepl;

@dynamic usessl;
@dynamic usessh;
@dynamic sshhost;
@dynamic sshport;
@dynamic sshuser;
@dynamic sshpassword;
@dynamic sshkeyfile;
@dynamic bindaddress;
@dynamic bindport;
@dynamic defaultReadMode;

+ (NSString *)hostnameFromServer:(NSString *)server WithPort:(NSInteger *)port
{
    NSArray *components;
    
    components = [server componentsSeparatedByString:@":"];
    if (port) {
        if (components.count > 1) {
            *port = [[components objectAtIndex:1] integerValue];
        } else {
            *port = 0;
        }
    }
    return [components objectAtIndex:0];
}

+ (NSString *)sortedServers:(NSString *)servers
{
    NSMutableArray *array = [NSMutableArray array];
    
    for (NSString *host in [servers componentsSeparatedByString:@","]) {
        [array addObject:[host stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet]];
    }
    [array sortedArrayUsingSelector:@selector(compare:)];
    return [array componentsJoinedByString:@","];
}

+ (NSString *)cleanupServers:(NSString *)servers
{
    NSMutableArray *array = [NSMutableArray array];
    
    for (NSString *host in [servers componentsSeparatedByString:@","]) {
        [array addObject:[host stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet]];
    }
    return [array componentsJoinedByString:@","];
}

+ (NSString *)passwordForServers:(NSString *)servers username:(NSString *)username
{
    NSString *keychainServers;
    
    NSParameterAssert(username.length > 0);
    keychainServers = [self sortedServers:servers];
    return [MHKeychain passwordWithLabel:[NSString stringWithFormat:@"%@ (%@)", keychainServers, username] account:username service:keychainServers description:nil];
}

- (NSArray *)queryHistoryWithDatabaseName:(NSString *)databaseName collectionName:(NSString *)collectionName
{
    NSString *absolute;
    NSMutableArray *result;
    NSDictionary *queries;
    
    absolute = [NSString stringWithFormat:@"%@.%@", databaseName, collectionName];
    result = [NSMutableArray array];
    @try {
        queries = [[[[NSUserDefaults standardUserDefaults] dictionaryForKey:QUERY_HISTORY_KEY] objectForKey:absolute] objectForKey:QUERY_KEY];
        for (NSString *title in [[[[NSUserDefaults standardUserDefaults] dictionaryForKey:QUERY_HISTORY_KEY] objectForKey:absolute] objectForKey:SORTED_TITLE_KEY]) {
            [result addObject:[queries objectForKey:title]];
        }
    }
    @catch (NSException *exception) {
    }
    return result;
}

- (void)addNewQuery:(NSDictionary *)query withDatabaseName:(NSString *)databaseName collectionName:(NSString *)collectionName
{
    NSString *absolute;
    NSMutableDictionary *allHistory;
    NSMutableDictionary *queriesAndTitles;
    NSMutableArray *sortedTitles;
    NSMutableDictionary *allQueries;
    
    absolute = [[NSString alloc] initWithFormat:@"%@.%@", databaseName, collectionName];
    allHistory = [[[NSUserDefaults standardUserDefaults] dictionaryForKey:QUERY_HISTORY_KEY] mutableCopy];
    if (allHistory == nil) {
        allHistory = [[NSMutableDictionary alloc] init];
    }
    queriesAndTitles = [[allHistory objectForKey:absolute] mutableCopy];
    if (queriesAndTitles == nil || ![queriesAndTitles isKindOfClass:[NSDictionary class]]) {
        [queriesAndTitles release];
        queriesAndTitles = [[NSMutableDictionary alloc] init];
    }
    sortedTitles = [[queriesAndTitles objectForKey:SORTED_TITLE_KEY] mutableCopy];
    allQueries = [[queriesAndTitles objectForKey:QUERY_KEY] mutableCopy];
    if (sortedTitles == nil || ![sortedTitles isKindOfClass:[NSArray class]] || allQueries == nil || ![allQueries isKindOfClass:[NSMutableDictionary class]]) {
        [sortedTitles release];
        [allQueries release];
        sortedTitles = [[NSMutableArray alloc] init];
        allQueries = [[NSMutableDictionary alloc] init];
    }
    
    while ([sortedTitles count] >= MAX_QUERY_PER_COLLECTION) {
        [allQueries removeObjectForKey:[sortedTitles lastObject]];
        [sortedTitles removeLastObject];
    }
    if ([allQueries objectForKey:[query objectForKey:@"title"]]) {
        [sortedTitles removeObject:[query objectForKey:@"title"]];
    }
    [sortedTitles insertObject:[query objectForKey:@"title"] atIndex:0];
    [allQueries setObject:query forKey:[query objectForKey:@"title"]];
    
    [queriesAndTitles setObject:sortedTitles forKey:SORTED_TITLE_KEY];
    [queriesAndTitles setObject:allQueries forKey:QUERY_KEY];
    [allHistory setObject:queriesAndTitles forKey:absolute];
    [[NSUserDefaults standardUserDefaults] setObject:allHistory forKey:QUERY_HISTORY_KEY];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [absolute release];
    [allHistory release];
    [queriesAndTitles release];
    [sortedTitles release];
    [allQueries release];
}

- (NSString *)sshpassword
{
    return [MHKeychain internetPasswordProtocol:kSecAttrProtocolSSH host:self.sshhost port:self.sshport.unsignedIntegerValue account:self.sshuser];
}

- (void)setSshpassword:(NSString *)sshpassword
{
    if (self.usessh) {
        [MHKeychain addOrUpdateInternetPasswordWithProtocol:kSecAttrProtocolSSH host:self.sshhost port:self.sshport.unsignedIntegerValue account:self.sshuser password:sshpassword];
    }
}

- (NSString *)adminpass
{
    if (self.adminuser.length > 0) {
        return [self.class passwordForServers:self.servers username:self.adminuser];
    } else {
        return nil;
    }
}

- (void)setAdminpass:(NSString *)adminpass
{
    if (self.adminuser.length > 0) {
        NSString *keychainServers;
        
        keychainServers = [self.class sortedServers:self.servers];
        [MHKeychain addOrUpdateItemWithLabel:[NSString stringWithFormat:@"%@ (%@)", keychainServers, self.adminuser] account:self.adminuser service:keychainServers description:nil password:adminpass];
    }
}

- (NSArray *)arrayServers
{
    return [[super valueForKey:@"servers"] componentsSeparatedByString:@","];
}

@end

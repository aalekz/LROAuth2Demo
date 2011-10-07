//
//  LROAuth2DemoViewController.m
//  LROAuth2Demo
//
//  Created by Luke Redpath on 01/06/2010.
//  Copyright LJR Software Limited 2010. All rights reserved.
//

#import "LROAuth2DemoViewController.h"	
#import "LROAuth2AccessToken.h"
#import "OAuthRequestController.h"
#import "ASIHTTPRequest.h"
#import "NSString+QueryString.h"
#import "NSObject+YAJL.h"

NSString * AccessTokenSavePath() {
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
  return [[paths objectAtIndex:0] stringByAppendingPathComponent:@"OAuthAccessToken.cache"];
}

@implementation LROAuth2DemoViewController

@synthesize accessToken;
@synthesize things;

- (void)viewDidLoad 
{
  [super viewDidLoad];
  
  /*
   * OAuthRequestController will post notifications when it has received/refreshed an access token,
   * we'll use those to keep track of the OAuth authentication process and update the UI 
   */  
  [[NSNotificationCenter defaultCenter] addObserver:self 
      selector:@selector(didReceiveAccessToken:) name:OAuthReceivedAccessTokenNotification object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self 
      selector:@selector(didRefreshAccessToken:) name:OAuthRefreshedAccessTokenNotification object:nil];
}

- (void)viewDidAppear:(BOOL)animated
{
  // try and load an existing access token from disk
  self.accessToken = [NSKeyedUnarchiver unarchiveObjectWithFile:AccessTokenSavePath()];

  // check if we have a valid access token before continuing otherwise obtain a token
  if (self.accessToken == nil) { 
    [self beginAuthorization];
  } else {
    [self loadThing];
  }
}

- (void)dealloc 
{
  [things release];
  [accessToken release];
  [super dealloc];
}

- (void)didReceiveAccessToken:(NSNotification *)note;
{
  self.accessToken = (LROAuth2AccessToken *)note.object;
  
  [self dismissModalViewControllerAnimated:YES];
  [self saveAccessTokenToDisk];
  [self loadThing];
}

- (void)didRefreshAccessToken:(NSNotification *)note;
{
  self.accessToken = (LROAuth2AccessToken *)note.object;
  
  [self saveAccessTokenToDisk];
  [self loadThing];
}

#pragma mark -

- (void)saveAccessTokenToDisk;
{
  [NSKeyedArchiver archiveRootObject:self.accessToken toFile:AccessTokenSavePath()];
}

- (void)beginAuthorization;
{
  OAuthRequestController *oauthController = [[OAuthRequestController alloc] init];
  [self presentModalViewController:oauthController animated:YES];
  [oauthController release];
}

- (void)loadThing;
{
  ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:@"https://api.flattr.com/rest/v2/users/alxx/things"]];
  [request addRequestHeader:@"Authorization" value:[NSString stringWithFormat:@"Bearer %@", self.accessToken.accessToken]];
  NSLog(@"Request: POST %@", [request requestHeaders]);
  [request setDelegate:self];
  [request startAsynchronous];
}

#pragma mark -
#pragma mark ASIHTTPRequestDelegate methods

- (void)requestFinished:(ASIHTTPRequest *)request
{
    NSError *jsonError = nil;
    NSArray *thingsData = [[request responseData] yajl_JSON];
    if (jsonError) {
        NSLog(@"JSON parse error: %@", jsonError);
    } else {
        NSLog(@"Data: %@", thingsData);
        self.things = thingsData;
        [self.tableView reloadData];
    }
}

- (void)requestFailed:(ASIHTTPRequest *)request
{
    NSLog(@"Error: %@", [request error]);
    //NSLog(@"Request failed: %@, %@", [request responseStatusCode], [request responseString]);
}

#pragma mark -
#pragma mark UITableView methods

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section
{
  if (self.things == nil) {
    return 0;
  }
  return self.things.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  static NSString *identifier = @"Cell";
  
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
  if (cell == nil) {
    cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier] autorelease];
  }
  NSDictionary *thing = [self.things objectAtIndex:indexPath.row];
  cell.textLabel.text = [thing valueForKey:@"title"];
  cell.detailTextLabel.text = [thing valueForKey:@"description"];
  return cell;
}

@end

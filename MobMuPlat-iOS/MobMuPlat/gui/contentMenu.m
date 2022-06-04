//
//  MeMenu.m
//  MobMuPlat
//
//  Created by Daniel Iglesia on 4/8/14.
//  Copyright (c) 2014 Daniel Iglesia. All rights reserved.
//

#import "contentMenu.h"
#import "MenuViewController.h"
#import "MenuNavigationController.h"





@implementation contentMenu {
  MenuViewController* mvc;
  NSMutableArray* _dataArray;
}
static NSString *CellIdentifier = @"MenuCell";


- (id)initWithTitle: (NSString *) title andAddress: (NSString*) address inFolder:(nullable NSString *)subfolder {
    _address = address;
    _titleString = title;
    if (subfolder)
        _subfolder = subfolder;
    return self;
}

-(void) showMenuWithContent: (NSMutableArray *) content  withDocsDir: (NSString*) dir fromViewController: (SceneViewController*) viewController{
    _dataArray = content;
    _docsDir = dir;
  
  mvc = [[MenuViewController alloc] init];
    
  mvc.tableView.dataSource = self;
  mvc.tableView.delegate = self;
  mvc.title = _titleString;
    if (@available(iOS 13.0, *))
        mvc.tableView.backgroundColor = [UIColor systemGray2Color];
    else mvc.tableView.backgroundColor = [UIColor grayColor];
    
    mvc.tableView.translatesAutoresizingMaskIntoConstraints = false;
    mvc.tableView.contentInset = UIEdgeInsetsMake(0, -15, 0, 0);
    mvc.tableView.contentInset = UIEdgeInsetsMake(0, 0, 0, -15);

    
  //once we stop supporting ios5:
    [mvc.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:CellIdentifier];
  //set orientation
  MenuNavigationController* navigationController = [[MenuNavigationController alloc] initWithRootViewController:mvc ];
  navigationController.orientation = [(SceneViewController*)viewController orientation];
  navigationController.navigationBar.barStyle = UIBarStyleBlack;

//  [viewController presentViewController:navigationController animated:YES completion:nil];
    [viewController presentModalViewController:navigationController animated:YES];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
  // Return the number of rows in the section.
  return [_dataArray count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
  
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
  
  if (cell == nil) {
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
  }
  // Configure the cell...
  [cell.textLabel setText:[_dataArray objectAtIndex:indexPath.row]];
  cell.textLabel.textAlignment = UITextAlignmentCenter;
    if (@available(iOS 13.0, *)) {
        cell.textLabel.textColor = [UIColor labelColor];
    }
    else cell.textLabel.textColor = [UIColor blackColor];
  UIView* bgView = [[UIView alloc] init];
    if (@available(iOS 13.0, *)) {
        bgView.backgroundColor = [UIColor systemGray5Color];
    }
    else bgView.backgroundColor = [UIColor whiteColor];
  cell.selectedBackgroundView = bgView;
  return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  //send
    NSString *file = (_subfolder == nil) ? [_dataArray objectAtIndex:indexPath.row] : [[_dataArray objectAtIndex:indexPath.row] lastPathComponent];
    NSString *path = [_docsDir stringByAppendingPathComponent:file];
 [PdBase sendList:[NSArray arrayWithObjects:@"/contentMenu", _address, path, nil] toReceiver:@"fromSystem"];
  //clear
  [mvc dismissModalViewControllerAnimated:YES];
}

-(void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (@available(iOS 13.0, *))
        cell.backgroundColor = [UIColor systemGray5Color];
    else cell.backgroundColor = [UIColor whiteColor];
}


@end

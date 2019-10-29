//
//  AppDelegate.m
//  Rigger_ARKit
//
//  Created by Edward on 2019/10/25.
//  Copyright © 2019 Edward. All rights reserved.
//

#import "AppDelegate.h"

#import <UIKit/UIKit.h>

#import "ViewController.h"



@interface AppDelegate ()

@end



@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    
    UIWindow *window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    ViewController *HomeVC = [[ViewController alloc] init];
    window.rootViewController = HomeVC;
    self.window = window;
    [self.window makeKeyAndVisible];
    
    return YES;
}

@end

//
//  main.m
//  Rigger_ARKit
//
//  Created by Edward on 2019/10/25.
//  Copyright © 2019 Edward. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AppDelegate.h"

int main(int argc, char * argv[]) {
    
    setenv("CFNETWORK_DIAGNOSTICS", "3", 1);
    
    NSString * appDelegateClassName;
    @autoreleasepool {
        // Setup code that might create autoreleased objects goes here.
        appDelegateClassName = NSStringFromClass([AppDelegate class]);
    }
    return UIApplicationMain(argc, argv, nil, appDelegateClassName);
}

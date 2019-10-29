//
//  ViewController.m
//  Rigger_ARKit
//
//  Created by Edward on 2019/10/25.
//  Copyright © 2019 Edward. All rights reserved.
//

#import "ViewController.h"

#import <ARKit/ARKit.h>

#import "MTKRender.h"



@interface ViewController () <ARSessionDelegate>

@property (nonatomic, strong) ARSession *session;

@property (nonatomic, strong) MTKRender *render;

@end


@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.session = [[ARSession alloc] init];
    self.session.delegate = self;
    
    
    self.render = [[MTKRender alloc] init];
    [self.view addSubview: self.render.view];
    self.render.view.frame = CGRectMake(0, 100, 300, 400);
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    ARFaceTrackingConfiguration *configuration = [[ARFaceTrackingConfiguration alloc] init];
    [self.session runWithConfiguration:configuration];
    
//    ARWorldTrackingConfiguration *configuration = [ARWorldTrackingConfiguration new];
//    [self.session runWithConfiguration:configuration];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [self.session pause];
}



#pragma mark - ARSessionDelegate

- (void)session:(ARSession *)session didUpdateFrame:(ARFrame *)frame {
    [self.render drawFrame:frame];
}

- (void)session:(ARSession *)session didAddAnchors:(nonnull NSArray<__kindof ARAnchor *> *)anchors {
    NSLog(@"didAddAnchors:%@", anchors);
}

- (void)session:(ARSession *)session didUpdateAnchors:(NSArray<__kindof ARAnchor *> *)anchors {
    for (ARAnchor *curAnchor in anchors) {
        if ([curAnchor isKindOfClass:[ARFaceAnchor class]]) {
            ARFaceAnchor *test = (ARFaceAnchor *)curAnchor;
            NSLog(@"didUpdateAnchors:%@", test);
        }
    }
}

- (void)session:(ARSession *)session didRemoveAnchors:(NSArray<__kindof ARAnchor *> *)anchors {
    NSLog(@"didRemoveAnchors:%@", anchors);
}

- (void)session:(ARSession *)session didFailWithError:(NSError *)error {
    // Present an error message to the user
    
}

- (void)sessionWasInterrupted:(ARSession *)session {
    // Inform the user that the session has been interrupted, for example, by presenting an overlay
    
}

- (void)sessionInterruptionEnded:(ARSession *)session {
    // Reset tracking and/or remove existing anchors if consistent tracking is required
    
}


@end

//
//  MTKRender.h
//  Rigger_ARKit
//
//  Created by Edward on 2019/10/28.
//  Copyright © 2019 Edward. All rights reserved.
//

#ifndef MTKRender_h
#define MTKRender_h

#import <MetalKit/MetalKit.h>
#import <ARKit/ARKit.h>

@interface MTKRender : NSObject

@property(nonatomic, strong)MTKView *view;

-(void)drawFrame:(ARFrame *)frame;

@end
#endif /* MTKRender_h */

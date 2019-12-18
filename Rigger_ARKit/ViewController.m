//
//  ViewController.m
//  Rigger_ARKit
//
//  Created by Edward on 2019/10/25.
//  Copyright © 2019 Edward. All rights reserved.
//

#import "ViewController.h"

#import <ARKit/ARKit.h>
#import <SceneKit/SceneKit.h>

#import <CocoaAsyncSocket/GCDAsyncSocket.h>

#import "MTKRender.h"
//#import "TCPClient.h"

@interface ViewController () <ARSessionDelegate, GCDAsyncSocketDelegate>

@property (nonatomic, strong) ARSession *session;

@property (nonatomic, strong) MTKRender *render;

@property (nonatomic, strong) GCDAsyncSocket *tcpClient;

@property (nonatomic, assign) float_t starTime;

@property (nonatomic, assign) int32_t frameCount;


@property (nonatomic, strong) SCNScene *scene;

@property (nonatomic, strong) SCNReferenceNode *contentNode;

@property (nonatomic, strong) SCNNode *head;

@property (nonatomic, strong) SCNNode *blendshapes;

@property (nonatomic, strong) SCNNode *cameraNode;

@property (nonatomic, strong) SCNView *faceView;




@end


@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.session = [[ARSession alloc] init];
    self.session.delegate = self;
    
    
    self.render = [[MTKRender alloc] init];
    [self.view addSubview: self.render.view];
    self.render.view.frame = CGRectMake(0, 0, 300, 400);

    
    self.tcpClient = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    NSError *error = nil;
    [self.tcpClient connectToHost:@"10.60.129.66" onPort:9000 error:&error];
//    [self.tcpClient connectToHost:@"10.60.107.200" onPort:9000 error:&error];
//    [self.tcpClient connectToHost:@"10.60.130.183" onPort:9000 error:&error];
    NSLog(@"%@", error.localizedDescription);
    

    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"Sloth" ofType:@"scn" inDirectory:@"Models.scnassets"];
    NSURL *referenceURL = [NSURL fileURLWithPath:filePath];
    self.contentNode = [[SCNReferenceNode alloc] initWithURL:referenceURL];
    [self.contentNode load];
    
    for (SCNNode *child in self.contentNode.childNodes) {
        NSLog(@"%@", child.name);
        if ([child.name isEqualToString:@"Head"]) {
            self.head = child;
        }
    }
    
//    for (SCNNode *child in self.head.childNodes) {
//        NSLog(@"%@", child.name);
//        if ([child.name isEqualToString:@"BlendShapes"]) {
//            self.blendshapes = child;
//        }
//    }
    self.head.morpher.unifiesNormals = YES;
    
    
    self.scene = [[SCNScene alloc] init];
    [self.scene.rootNode addChildNode:self.contentNode];
    
    self.faceView = [[SCNView alloc] init];
    self.faceView.autoenablesDefaultLighting = YES;
    self.faceView.scene = self.scene;
    self.faceView.allowsCameraControl = NO;
    self.faceView.backgroundColor = [UIColor clearColor];
    
    
    self.cameraNode =  [[SCNNode alloc] init];
    self.cameraNode.camera = [[SCNCamera alloc] init];
    self.cameraNode.position = SCNVector3Make(0, 0, 5);
    [self.scene.rootNode addChildNode:self.cameraNode];
    self.faceView.pointOfView = self.cameraNode;
    
    [self.view addSubview:self.faceView];
    self.faceView.frame = CGRectMake(0, 350, 300, 400);
    self.faceView.preferredFramesPerSecond = 10;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    ARFaceTrackingConfiguration *configuration = [[ARFaceTrackingConfiguration alloc] init];
    configuration.worldAlignment = ARWorldAlignmentGravity;
    configuration.lightEstimationEnabled = YES;
    [self.session runWithConfiguration:configuration];
    
//    ARWorldTrackingConfiguration *configuration = [ARWorldTrackingConfiguration new];
//    [self.session runWithConfiguration:configuration];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [self.session pause];
}

- (NSData *)dumpToData:(ARFaceAnchor *)faceAnchor {
    const int max_buff_len = 274;
    uint8_t buffer[max_buff_len];
    bzero(buffer, sizeof(buffer));
    buffer[0] = 42;
    
    
    NSArray *arrKeys = @[@"browDown_L",@"browDown_R",@"browInnerUp",@"browOuterUp_L",@"browOuterUp_R",@"cheekPuff",@"cheekSquint_L",@"cheekSquint_R",@"eyeBlink_L",@"eyeBlink_R",@"eyeLookDown_L",@"eyeLookDown_R",@"eyeLookIn_L",@"eyeLookIn_R",@"eyeLookOut_L",@"eyeLookOut_R",@"eyeLookUp_L",@"eyeLookUp_R",@"eyeSquint_L",@"eyeSquint_R",@"eyeWide_L",@"eyeWide_R",@"jawForward",@"jawLeft",@"jawOpen",@"jawRight",@"mouthClose",@"mouthDimple_L",@"mouthDimple_R",@"mouthFrown_L",@"mouthFrown_R",@"mouthFunnel",@"mouthLeft",@"mouthLowerDown_L",@"mouthLowerDown_R",@"mouthPress_L",@"mouthPress_R",@"mouthPucker",@"mouthRight",@"mouthRollLower",@"mouthRollUpper",@"mouthShrugLower",@"mouthShrugUpper",@"mouthSmile_L",@"mouthSmile_R",@"mouthStretch_L",@"mouthStretch_R",@"mouthUpperUp_L",@"mouthUpperUp_R",@"noseSneer_L",@"noseSneer_R",@"tongueOut"];
//    NSLog(@"%@", arrKeys);
    
    for (NSInteger nIndex=0; nIndex<arrKeys.count; nIndex++) {
        NSString *strKey = [arrKeys objectAtIndex:nIndex];
        NSNumber *numValue = [faceAnchor.blendShapes objectForKey:strKey];
        float *pFloat = (float *)&buffer[1+4*nIndex];
        *pFloat = [numValue floatValue];
    }
    

//    SCNNode *node = [[SCNNode alloc] init];
//    node.simdTransform = faceAnchor.transform;
//    NSLog(@"%f-%f-%f", node.simdPosition[0], node.simdPosition[1], node.simdPosition[2]);
//    NSLog(@"%f-%f-%f-%f", node.simdOrientation.vector[0], node.simdOrientation.vector[1], node.simdOrientation.vector[2], node.simdOrientation.vector[3]);
//    float *pFloat = (float *)&buffer[1+4*arrKeys.count];
//    for (NSInteger nIndex=0; nIndex<3; nIndex++) {
//        *pFloat = node.simdPosition[nIndex];
//        if (nIndex==2) {
//            *pFloat = 0-*pFloat;
//        }
//        pFloat++;
//    }
//    for (NSInteger nIndex=0; nIndex<4; nIndex++) {
//        *pFloat = node.simdOrientation.vector[nIndex];
//        if (nIndex==2 || nIndex==3) {
//            *pFloat = 0-*pFloat;
//        }
//        pFloat++;
//    }
    
    
    float *pFloat = (float *)&buffer[1+4*arrKeys.count];
    simd_float3 position;
    position[0] = faceAnchor.transform.columns[3][0];
    position[1] = faceAnchor.transform.columns[3][1];
    position[2] = -faceAnchor.transform.columns[3][2];
    for (NSInteger nIndex=0; nIndex<3; nIndex++) {
        *pFloat = position[nIndex];
        pFloat++;
    }

    simd_float4 orientation = QuaternionFromMatrix(faceAnchor.transform);
    orientation[2] = 0-orientation[2];
//    orientation[3] = 0-orientation[3];
    for (NSInteger nIndex=0; nIndex<4; nIndex++) {
        *pFloat = orientation[nIndex];
        pFloat++;
    }
    
    
    int32_t *pFrameIndex = (int32_t *)&buffer[265];
    *pFrameIndex = self.frameCount++;
    
    float_t *pTimeStamp = (float_t *)&buffer[269];
    *pTimeStamp = [[NSDate dateWithTimeIntervalSinceNow:0] timeIntervalSince1970]-self.starTime;
    
    if (faceAnchor.isTracked) {
        buffer[max_buff_len-1]=1;
    }
    else {
        buffer[max_buff_len-1]=0;
    }
    
    NSLog(@"SendOrientation%f-%f-%f-%f", orientation[0], orientation[1], orientation[2], orientation[3]);
    
    
    return [NSData dataWithBytes:buffer length:max_buff_len];
}

float signum(float fValue) {
    if (fValue>=0) {
        return 1.0;
    }
    else {
        return -1.0;
    }
}

static simd_float4 QuaternionFromMatrix(simd_float4x4 m) {
    simd_float4 rtn;
    rtn[3] = sqrt(MAX(0, 1+m.columns[0][0]+m.columns[1][1]+m.columns[2][2]))/2;
    rtn[0] = sqrt(MAX(0, 1+m.columns[0][0]-m.columns[1][1]-m.columns[2][2]))/2;
    rtn[1] = sqrt(MAX(0, 1-m.columns[0][0]+m.columns[1][1]-m.columns[2][2]))/2;
    rtn[2] = sqrt(MAX(0, 1-m.columns[0][0]-m.columns[1][1]+m.columns[2][2]))/2;
    
//    rtn[0] *= signum(rtn[0]*(m.columns[1][2]-m.columns[2][1]));
//    rtn[1] *= signum(rtn[1]*(m.columns[2][0]-m.columns[0][2]));
//    rtn[2] *= signum(rtn[2]*(m.columns[0][1]-m.columns[1][0]));
    rtn[0] *= signum(rtn[0]*(m.columns[2][1]-m.columns[1][2]));
    rtn[1] *= signum(rtn[1]*(m.columns[0][2]-m.columns[2][0]));
    rtn[2] *= signum(rtn[2]*(m.columns[1][0]-m.columns[0][1]));
    return rtn;
//     Quaternion q = new Quaternion();
//     q.w = Mathf.Sqrt( Mathf.Max( 0, 1 + m[0,0] + m[1,1] + m[2,2] ) ) / 2;
//     q.x = Mathf.Sqrt( Mathf.Max( 0, 1 + m[0,0] - m[1,1] - m[2,2] ) ) / 2;
//     q.y = Mathf.Sqrt( Mathf.Max( 0, 1 - m[0,0] + m[1,1] - m[2,2] ) ) / 2;
//     q.z = Mathf.Sqrt( Mathf.Max( 0, 1 - m[0,0] - m[1,1] + m[2,2] ) ) / 2;
//     q.x *= Mathf.Sign( q.x * ( m[2,1] - m[1,2] ) );
//     q.y *= Mathf.Sign( q.y * ( m[0,2] - m[2,0] ) );
//     q.z *= Mathf.Sign( q.z * ( m[1,0] - m[0,1] ) );
//     return q;
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port
{
    NSLog(@"TCP Connected!");
    
    self.starTime = [[NSDate dateWithTimeIntervalSinceNow:0] timeIntervalSince1970];
    self.frameCount = 0;
}


#pragma mark - ARSessionDelegate

- (void)session:(ARSession *)session didUpdateFrame:(ARFrame *)frame {
    [self.render drawFrame:frame];
}

- (void)session:(ARSession *)session didAddAnchors:(nonnull NSArray<__kindof ARAnchor *> *)anchors {
    NSLog(@"didAddAnchors:%@", anchors);
}

- (void)session:(ARSession *)session didUpdateAnchors:(NSArray<__kindof ARAnchor *> *)anchors {
    NSLog(@"UpdateAnchors!!!");
    
    for (ARAnchor *curAnchor in anchors) {
        if ([curAnchor isKindOfClass:[ARFaceAnchor class]]) {
            ARFaceAnchor *faceAnchor = (ARFaceAnchor *)curAnchor;
            NSData *sendData = [self dumpToData:faceAnchor];
            
            if (self.tcpClient.isConnected) {
                [self.tcpClient writeData:sendData withTimeout:-1 tag:0];
            }
            
            
            
            for (NSString *key in faceAnchor.blendShapes) {
                NSNumber *value = [faceAnchor.blendShapes objectForKey:key];
                NSString *targetName = [NSString stringWithFormat:@"%@Mesh", key];
                [self.head.morpher setWeight:[value floatValue] forTargetNamed:targetName];
            }
            
//            self.head.simdTransform = faceAnchor.transform;
            self.head.eulerAngles = [self calculateEulerAngles:faceAnchor withARSession:session];
        }
    }
}

- (SCNVector3)calculateEulerAngles:(ARFaceAnchor *)faceAnchor withARSession:(ARSession *)curSession {
    simd_float4x4 projectionMatrix = [curSession.currentFrame.camera projectionMatrixForOrientation:UIInterfaceOrientationPortrait viewportSize:self.faceView.bounds.size zNear:0.001 zFar:1000];
    simd_float4x4 viewMatrix = [curSession.currentFrame.camera viewMatrixForOrientation:UIInterfaceOrientationPortrait];
    projectionMatrix = simd_mul(projectionMatrix, viewMatrix);
    simd_float4x4 modelMatrix = faceAnchor.transform;
    simd_float4x4 mvpMatrix = simd_mul(projectionMatrix, modelMatrix);
    
    SCNMatrix4 newFaceMatrix = SCNMatrix4FromMat4(mvpMatrix);
    SCNNode *faceNode = [[SCNNode alloc] init];
    faceNode.transform = newFaceMatrix;
    
    simd_float3 rotation = vector3(faceNode.worldOrientation.x, faceNode.worldOrientation.y, faceNode.worldOrientation.z);
    return SCNVector3Make(rotation.x*3, rotation.y*3, rotation.z*1.5);
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

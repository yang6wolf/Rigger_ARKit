//
//  MTKRender.m
//  Rigger_ARKit
//
//  Created by Edward on 2019/10/28.
//  Copyright © 2019 Edward. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "MTKRender.h"



static const NSUInteger kMaxBuffersInFlight = 3;

// Attribute index values shared between shader and C code to ensure Metal shader vertex
//   attribute indices match the Metal API vertex descriptor attribute indices
typedef enum VertexAttributes {
    kVertexAttributePosition  = 0,
    kVertexAttributeTexcoord  = 1,
    kVertexAttributeNormal    = 2
} VertexAttributes;


// Buffer index values shared between shader and C code to ensure Metal shader buffer inputs match
//   Metal API buffer set calls
typedef enum BufferIndices {
    kBufferIndexMeshPositions    = 0,
    kBufferIndexMeshGenerics     = 1,
    kBufferIndexInstanceUniforms = 2,
    kBufferIndexSharedUniforms   = 3
} BufferIndices;

// Texture index values shared between shader and C code to ensure Metal shader texture indices
//   match indices of Metal API texture set calls
typedef enum TextureIndices {
    kTextureIndexColor    = 0,
    kTextureIndexY        = 1,
    kTextureIndexCbCr     = 2
} TextureIndices;

// Vertex data for an image plane
static const float kImagePlaneVertexData[16] = {
    -1.0, -1.0,  0.0, 1.0,
    1.0, -1.0,  1.0, 1.0,
    -1.0,  1.0,  0.0, 0.0,
    1.0,  1.0,  1.0, 0.0,
};


@implementation MTKRender {
    dispatch_semaphore_t _inFlightSemaphore;
    id <MTLCommandQueue> _commandQueue;
    id <MTLBuffer> _imagePlaneVertexBuffer;
    id <MTLRenderPipelineState> _capturedImagePipelineState;
    
    CVMetalTextureRef _capturedImageTextureYRef;
    CVMetalTextureRef _capturedImageTextureCbCrRef;
    
    // Captured image texture cache
    CVMetalTextureCacheRef _capturedImageTextureCache;
    
    // The current viewport size
    CGSize _viewportSize;
    
    // Flag for viewport size changes
    BOOL _viewportSizeDidChange;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _view = [[MTKView alloc] init];

        
        _view.backgroundColor = [UIColor clearColor];
        
        [self _loadMetal];
    }
    return self;
}

- (void)_loadMetal {
    _inFlightSemaphore = dispatch_semaphore_create(kMaxBuffersInFlight);
    _viewportSize = self.view.bounds.size;
    _viewportSizeDidChange = YES;

    _view.device = MTLCreateSystemDefaultDevice();
    _view.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
    _view.sampleCount = 1;
    if (!_view.device) {
        NSLog(@"Metal is not supported on this device");
    }
    
    // Create a vertex buffer with our image plane vertex data.
    _imagePlaneVertexBuffer = [_view.device newBufferWithBytes:&kImagePlaneVertexData length:sizeof(kImagePlaneVertexData) options:MTLResourceCPUCacheModeDefaultCache];
    _imagePlaneVertexBuffer.label = @"ImagePlaneVertexBuffer";
    
    // Load all the shader files with a metal file extension in the project
    id <MTLLibrary> defaultLibrary = [_view.device newDefaultLibrary];
    id <MTLFunction> capturedImageVertexFunction = [defaultLibrary newFunctionWithName:@"capturedImageVertexTransform"];
    id <MTLFunction> capturedImageFragmentFunction = [defaultLibrary newFunctionWithName:@"capturedImageFragmentShader"];
    
    // Create a vertex descriptor for our image plane vertex buffer
    MTLVertexDescriptor *imagePlaneVertexDescriptor = [[MTLVertexDescriptor alloc] init];
    
    // Positions.
    imagePlaneVertexDescriptor.attributes[kVertexAttributePosition].format = MTLVertexFormatFloat2;
    imagePlaneVertexDescriptor.attributes[kVertexAttributePosition].offset = 0;
    imagePlaneVertexDescriptor.attributes[kVertexAttributePosition].bufferIndex = kBufferIndexMeshPositions;
    
    // Texture coordinates.
    imagePlaneVertexDescriptor.attributes[kVertexAttributeTexcoord].format = MTLVertexFormatFloat2;
    imagePlaneVertexDescriptor.attributes[kVertexAttributeTexcoord].offset = 8;
    imagePlaneVertexDescriptor.attributes[kVertexAttributeTexcoord].bufferIndex = kBufferIndexMeshPositions;
    
    // Position Buffer Layout
    imagePlaneVertexDescriptor.layouts[kBufferIndexMeshPositions].stride = 16;
    imagePlaneVertexDescriptor.layouts[kBufferIndexMeshPositions].stepRate = 1;
    imagePlaneVertexDescriptor.layouts[kBufferIndexMeshPositions].stepFunction = MTLVertexStepFunctionPerVertex;
    
    
    
    MTLRenderPipelineDescriptor *capturedImagePipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    capturedImagePipelineStateDescriptor.label = @"MyCapturedImagePipeline";
    capturedImagePipelineStateDescriptor.sampleCount = _view.sampleCount;
    capturedImagePipelineStateDescriptor.vertexFunction = capturedImageVertexFunction;
    capturedImagePipelineStateDescriptor.fragmentFunction = capturedImageFragmentFunction;
    capturedImagePipelineStateDescriptor.vertexDescriptor = imagePlaneVertexDescriptor;
    capturedImagePipelineStateDescriptor.colorAttachments[0].pixelFormat = _view.colorPixelFormat;
//    capturedImagePipelineStateDescriptor.depthAttachmentPixelFormat     = MTLPixelFormatDepth32Float_Stencil8;
//    capturedImagePipelineStateDescriptor.stencilAttachmentPixelFormat   = MTLPixelFormatDepth32Float_Stencil8;
    
    NSError *error = nil;
    _capturedImagePipelineState = [_view.device newRenderPipelineStateWithDescriptor:capturedImagePipelineStateDescriptor error:&error];
    if (!_capturedImagePipelineState) {
        NSLog(@"Failed to created captured image pipeline state, error %@", error);
    }
    
    // Create captured image texture cache
    CVMetalTextureCacheCreate(NULL, NULL, _view.device, NULL, &_capturedImageTextureCache);
    
    _commandQueue = [_view.device newCommandQueue];
}

- (void)drawFrame:(ARFrame *)frame {
    if (self.view.currentDrawable == nil) {
        return;
    }
    
    dispatch_semaphore_wait(_inFlightSemaphore, DISPATCH_TIME_FOREVER);

    id <MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"MyCommand";
    
    CVBufferRef capturedImageTextureYRef    = CVBufferRetain(_capturedImageTextureYRef);
    CVBufferRef capturedImageTextureCbCrRef = CVBufferRetain(_capturedImageTextureCbCrRef);
    __block dispatch_semaphore_t block_sema = _inFlightSemaphore;
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
        dispatch_semaphore_signal(block_sema);
        CVBufferRelease(capturedImageTextureYRef);
        CVBufferRelease(capturedImageTextureCbCrRef);
    }];
    
    
    CVPixelBufferRef pixelBuffer = frame.capturedImage;
    if (CVPixelBufferGetPlaneCount(pixelBuffer)>=2) {
        CVBufferRelease(_capturedImageTextureYRef);
        CVBufferRelease(_capturedImageTextureCbCrRef);
        _capturedImageTextureYRef       = [self _createTextureFromPixelBuffer:pixelBuffer pixelFormat:MTLPixelFormatR8Unorm planeIndex:0];
        _capturedImageTextureCbCrRef    = [self _createTextureFromPixelBuffer:pixelBuffer pixelFormat:MTLPixelFormatRG8Unorm planeIndex:1];
        
        
        if (_viewportSizeDidChange) {
            _viewportSizeDidChange = NO;
            
            [self _updateImagePlaneWithFrame:frame];
        }
    }
    
    
    MTLRenderPassDescriptor *renderPassDescriptor = self.view.currentRenderPassDescriptor;
    // If we've gotten a renderPassDescriptor we can render to the drawable, otherwise we'll skip
    //   any rendering this frame because we have no drawable to draw to
    if (renderPassDescriptor != nil) {
        
        // Create a render command encoder so we can render into something
        id <MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        renderEncoder.label = @"MyRenderEncoder";
        
        [self _drawCapturedImageWithCommandEncoder:renderEncoder];
        
        // We're done encoding commands
        [renderEncoder endEncoding];
    }
    
    // Schedule a present once the framebuffer is complete using the current drawable
    [commandBuffer presentDrawable:self.view.currentDrawable];
    
    // Finalize rendering here & push the command buffer to the GPU
    [commandBuffer commit];
}


- (CVMetalTextureRef)_createTextureFromPixelBuffer:(CVPixelBufferRef)pixelBuffer pixelFormat:(MTLPixelFormat)pixelFormat planeIndex:(NSInteger)planeIndex {
    
    const size_t width = CVPixelBufferGetWidthOfPlane(pixelBuffer, planeIndex);
    const size_t height = CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex);
    
    CVMetalTextureRef mtlTextureRef = nil;
    CVReturn status = CVMetalTextureCacheCreateTextureFromImage(NULL, _capturedImageTextureCache, pixelBuffer, NULL, pixelFormat, width, height, planeIndex, &mtlTextureRef);
    if (status != kCVReturnSuccess) {
        CVBufferRelease(mtlTextureRef);
        mtlTextureRef = nil;
    }
    
    return mtlTextureRef;
}

- (void)_drawCapturedImageWithCommandEncoder:(id<MTLRenderCommandEncoder>)renderEncoder {
    if (_capturedImageTextureYRef == nil || _capturedImageTextureCbCrRef == nil) {
        return;
    }
    
    // Push a debug group allowing us to identify render commands in the GPU Frame Capture tool
    [renderEncoder pushDebugGroup:@"DrawCapturedImage"];
    
    // Set render command encoder state
    [renderEncoder setCullMode:MTLCullModeNone];
    [renderEncoder setRenderPipelineState:_capturedImagePipelineState];
//    [renderEncoder setDepthStencilState:_capturedImageDepthState];
    
    // Set mesh's vertex buffers
    [renderEncoder setVertexBuffer:_imagePlaneVertexBuffer offset:0 atIndex:kBufferIndexMeshPositions];
    
    // Set any textures read/sampled from our render pipeline
    [renderEncoder setFragmentTexture:CVMetalTextureGetTexture(_capturedImageTextureYRef) atIndex:kTextureIndexY];
    [renderEncoder setFragmentTexture:CVMetalTextureGetTexture(_capturedImageTextureCbCrRef) atIndex:kTextureIndexCbCr];
    
    // Draw each submesh of our mesh
    [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
    
    [renderEncoder popDebugGroup];
}

- (void)_updateImagePlaneWithFrame:(ARFrame *)frame {
    // Update the texture coordinates of our image plane to aspect fill the viewport
    CGAffineTransform displayToCameraTransform = CGAffineTransformInvert([frame displayTransformForOrientation:UIInterfaceOrientationPortrait viewportSize:_viewportSize]);

    float *vertexData = [_imagePlaneVertexBuffer contents];
    for (NSInteger index = 0; index < 4; index++) {
        NSInteger textureCoordIndex = 4 * index + 2;
        CGPoint textureCoord = CGPointMake(kImagePlaneVertexData[textureCoordIndex], kImagePlaneVertexData[textureCoordIndex + 1]);
        CGPoint transformedCoord = CGPointApplyAffineTransform(textureCoord, displayToCameraTransform);
        vertexData[textureCoordIndex] = transformedCoord.x;
        vertexData[textureCoordIndex + 1] = transformedCoord.y;
    }
}

@end

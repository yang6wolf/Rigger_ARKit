//
//  TCPClient.h
//  Rigger_ARKit
//
//  Created by Edward on 2019/10/29.
//  Copyright © 2019 Edward. All rights reserved.
//

#ifndef TCPClient_h
#define TCPClient_h

@interface TCPClient : NSObject

@property(nonatomic, readonly) BOOL isConnected;

- (BOOL)connectHost:(NSString *)hostText port:(int)port;

- (NSString *)sendAndRecv:(NSString *)message;

- (void)disConnection;

@end

#endif /* TCPClient_h */

//  FNElement.h — nyousefi/Fountain (MIT)
#import <Foundation/Foundation.h>

@interface FNElement : NSObject
@property (nonatomic, copy) NSString *elementType;
@property (nonatomic, copy) NSString *elementText;
@property (nonatomic, assign) BOOL isCentered;
@property (nonatomic, copy) NSString *sceneNumber;
@property (nonatomic, assign) BOOL isDualDialogue;
@property (nonatomic, assign) NSUInteger sectionDepth;
+ (FNElement *)elementOfType:(NSString *)elementType text:(NSString *)elementText;
@end

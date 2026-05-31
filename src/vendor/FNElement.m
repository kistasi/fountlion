//  FNElement.m — nyousefi/Fountain (MIT)
#import "FNElement.h"

@implementation FNElement

- (id)init {
    self = [super init];
    if (self) {
        _isDualDialogue = NO;
        _isCentered = NO;
        _sceneNumber = nil;
        _sectionDepth = 0;
    }
    return self;
}

+ (FNElement *)elementOfType:(NSString *)elementType text:(NSString *)elementText {
    FNElement *el = [[FNElement alloc] init];
    el.elementType = elementType;
    el.elementText = elementText;
    return el;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@: %@", self.elementType, self.elementText];
}

@end

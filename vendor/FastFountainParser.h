//  FastFountainParser.h — nyousefi/Fountain (MIT)
#import <Foundation/Foundation.h>

@interface FastFountainParser : NSObject
@property (strong, nonatomic) NSMutableArray *elements;
@property (strong, nonatomic) NSMutableArray *titlePage;
// Number of lines in the original text occupied by the title page + blank separator.
// Zero when there is no title page.
@property (nonatomic) NSUInteger titlePageLineCount;
- (id)initWithFile:(NSString *)filePath;
- (id)initWithString:(NSString *)string;
@end

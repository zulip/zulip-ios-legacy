//  NSString+Encode.m

@implementation NSString (encode)
- (NSString *)encodeString:(NSStringEncoding)encoding
{
    return [(NSString *) CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)self,
                                                                NULL, (CFStringRef)@";/?:@&=$+{}<>,",
                                                                CFStringConvertNSStringEncodingToEncoding(encoding))
            autorelease];
}
@end

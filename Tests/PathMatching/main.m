#import <Foundation/Foundation.h>
#import "pathleak.h"
static void check(NSString *path, NSString *base, NSString *expected) {
    NSString *got = pathleak_direct_child(path, base);
    if ((expected == nil && got != nil) || (expected != nil && ![expected isEqualToString:got])) {
        NSLog(@"FAIL %@ -> %@ (expected %@)", path, got, expected); exit(1);
    }
}
int main(void) { @autoreleasepool {
    NSString *base = @"/var/mobile/Containers/Data/Application";
    NSString *child = @"/var/mobile/Containers/Data/Application/ABC";
    check(@"/private/var/mobile/Containers/Data/Application/ABC", base, child);
    check(child, base, child);
    check(child, @"/private/var/mobile/Containers/Data/Application/", child);
    check(@"/private/var/mobile/Containers/Data/Application/ABC/Library", base, nil);
    check(@"/private/var/mobile/Containers/Data/ApplicationExtra/ABC", base, nil);
    check(base, base, nil);
    puts("PASS /private/var and /var direct-child matching");
    return 0;
} }

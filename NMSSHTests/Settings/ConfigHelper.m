#import "ConfigHelper.h"

@implementation ConfigHelper

+ (id)valueForKey:(NSString *)key {
    static NSDictionary *config;
    
    if (!config) {
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        NSString *bundlePath = [bundle bundlePath];
        
        // Simple approach: try common locations where the project might be
        NSArray *candidatePaths = @[
            // Current working directory (if running from project root)
            [[NSFileManager defaultManager] currentDirectoryPath],
            // Environment variables
            [[[NSProcessInfo processInfo] environment] objectForKey:@"SRCROOT"] ?: @"",
            // Navigate up from bundle path (DerivedData structure)
            [[bundlePath stringByAppendingPathComponent:@"../../../../.."] stringByStandardizingPath],
            [[bundlePath stringByAppendingPathComponent:@"../../../.."] stringByStandardizingPath],
            [[bundlePath stringByAppendingPathComponent:@"../../.."] stringByStandardizingPath],
            // Try some common project locations
            [@"~/sandbox/NMSSH" stringByExpandingTildeInPath],
            @"/Users/jlake/sandbox/NMSSH" // Last resort fallback for this specific setup
        ];
        
        NSString *projectRoot = nil;
        for (NSString *candidate in candidatePaths) {
            if ([candidate length] == 0) continue;
            
            // Check if this directory contains the expected files
            NSString *keyFile = [candidate stringByAppendingPathComponent:@"tests/ssh-keys/id_rsa_nopass.pub"];
            NSString *projectFile = [candidate stringByAppendingPathComponent:@"NMSSH.xcodeproj"];
            
            if ([[NSFileManager defaultManager] fileExistsAtPath:keyFile] && 
                [[NSFileManager defaultManager] fileExistsAtPath:projectFile]) {
                projectRoot = candidate;
                break;
            }
        }
        
        // Final fallback
        if (!projectRoot) {
            projectRoot = [[NSFileManager defaultManager] currentDirectoryPath];
        }
        
        NSString *validKeyPath = [projectRoot stringByAppendingPathComponent:@"tests/ssh-keys/id_rsa_nopass.pub"];
        NSString *invalidKeyPath = [projectRoot stringByAppendingPathComponent:@"tests/ssh-keys/github_rsa.pub"];
        NSString *passwordProtectedKeyPath = [projectRoot stringByAppendingPathComponent:@"tests/ssh-keys/id_rsa_pem.pub"];
        
        config = @{
            @"valid_password_protected_server": @{
                @"host": @"127.0.0.1:2222",
                @"user": @"user",
                @"password": @"password",
                @"execute_command": @"ls -1 /var/www/nmssh-tests/",
                @"execute_expected_response": @"invalid\nvalid\n",
                @"writable_dir": @"/var/www/nmssh-tests/valid/",
                @"non_writable_dir": @"/var/www/nmssh-tests/invalid/"
            },
            @"valid_public_key_protected_server": @{
                @"host": @"127.0.0.1:2222",
                @"user": @"user",
                @"valid_public_key": validKeyPath,
                @"invalid_public_key": invalidKeyPath,
                @"password_protected_key": passwordProtectedKeyPath,
                @"password": [NSNull null]
            },
            @"invalid_server": @{
                @"host": @"192.0.2.1:22",
                @"user": @"invaliduser",
                @"password": @"pass"
            }
        };
    }

    id data = config;
    NSArray *keyList = [key componentsSeparatedByString:@"."];
    for (NSString *keyPart in keyList) {
        data = [data objectForKey:keyPart];
    }

    return data;
}

@end

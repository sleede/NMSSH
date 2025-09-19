#import "ConfigHelper.h"

@implementation ConfigHelper

#ifdef TEST_SERVER_HOST_PORT
NSString *serverHostPort = @TEST_SERVER_HOST_PORT;
#else
NSString *serverHostPort = @"127.0.0.1:2222";
#endif

+ (id)valueForKey:(NSString *)key {
    static NSDictionary *config;
    
    if (!config) {
        NSString *thisFile = [NSString stringWithUTF8String:__FILE__];
        NSString *projectRoot = [[[[thisFile stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByStandardizingPath];
        
        NSString *validKeyPath = [projectRoot stringByAppendingPathComponent:@"tests/ssh-keys/id_rsa_nopass.pub"];
        NSString *invalidKeyPath = [projectRoot stringByAppendingPathComponent:@"tests/ssh-keys/github_rsa.pub"];
        NSString *passwordProtectedKeyPath = [projectRoot stringByAppendingPathComponent:@"tests/ssh-keys/id_rsa_pem.pub"];
        NSString *p256KeyPath = [projectRoot stringByAppendingPathComponent:@"tests/ssh-keys/id_ecdsa_p256"];
        NSString *p256KeyPemPath = [projectRoot stringByAppendingPathComponent:@"tests/ssh-keys/id_ecdsa_p256.pem"];
        NSString *p256PublicPath = [projectRoot stringByAppendingPathComponent:@"tests/ssh-keys/id_ecdsa_p256.pub"];
        NSString *ed25519KeyPath = [projectRoot stringByAppendingPathComponent:@"tests/ssh-keys/id_ed25519.pub"];
        
        if (![[NSFileManager defaultManager] fileExistsAtPath:validKeyPath]) {
            @throw @"Config failed";
        }

        config = @{
            @"valid_password_protected_server": @{
                @"host": serverHostPort,
                @"user": @"user",
                @"password": @"password",
                @"execute_command": @"ls -1 /var/www/nmssh-tests/",
                @"execute_expected_response": @"invalid\nvalid\n",
                @"writable_dir": @"/var/www/nmssh-tests/valid/",
                @"non_writable_dir": @"/var/www/nmssh-tests/invalid/"
            },
            @"valid_public_key_protected_server": @{
                @"host": serverHostPort,
                @"user": @"user",
                @"valid_public_key": validKeyPath,
                @"invalid_public_key": invalidKeyPath,
                @"password_protected_key": passwordProtectedKeyPath,
                @"p256_key": p256KeyPath,
                @"p256_key_pem": p256KeyPemPath,
                @"p256_public": p256PublicPath,
                @"ed25519_key": ed25519KeyPath,
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

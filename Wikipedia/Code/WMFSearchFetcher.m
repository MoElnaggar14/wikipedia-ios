#import "WMFSearchFetcher_Testing.h"
#import "WMFSearchResults_Internal.h"
@import WMF;

NS_ASSUME_NONNULL_BEGIN

NSUInteger const WMFMaxSearchResultLimit = 24;

#pragma mark - Fetcher Implementation

@implementation WMFSearchFetcher

- (void)fetchArticlesForSearchTerm:(NSString *)searchTerm
                           siteURL:(NSURL *)siteURL
                       resultLimit:(NSUInteger)resultLimit
                           failure:(WMFErrorHandler)failure
                           success:(WMFSearchResultsHandler)success {
    [self fetchArticlesForSearchTerm:searchTerm siteURL:siteURL resultLimit:resultLimit fullTextSearch:NO appendToPreviousResults:nil failure:failure success:success];
}

- (void)fetchArticlesForSearchTerm:(NSString *)searchTerm
                           siteURL:(NSURL *)siteURL
                       resultLimit:(NSUInteger)resultLimit
                    fullTextSearch:(BOOL)fullTextSearch
           appendToPreviousResults:(nullable WMFSearchResults *)previousResults
                           failure:(WMFErrorHandler)failure
                           success:(WMFSearchResultsHandler)success {
    if (!siteURL) {
        siteURL = [NSURL wmf_URLWithDefaultSiteAndCurrentLocale];
    }

    if (!siteURL) {
        failure([WMFFetcher invalidParametersError]);
        return;
    }

    if (resultLimit > WMFMaxSearchResultLimit) {
        DDLogError(@"Illegal attempt to request %lu articles, limiting to %lu.",
                   (unsigned long)resultLimit, (unsigned long)WMFMaxSearchResultLimit);
        resultLimit = WMFMaxSearchResultLimit;
    }

    [[MWNetworkActivityIndicatorManager sharedManager] push];

    NSNumber *numResults = @(resultLimit);

    NSDictionary *params = nil;
    if (!fullTextSearch) {
        params = @{
            @"action": @"query",
            @"generator": @"prefixsearch",
            @"gpssearch": searchTerm,
            @"gpsnamespace": @0,
            @"gpslimit": numResults,
            @"prop": @"description|pageprops|pageimages|revisions|coordinates",
            @"coprop": @"type|dim",
            @"piprop": @"thumbnail",
            //@"pilicense": @"any",
            @"ppprop": @"displaytitle|disambiguation",
            @"pithumbsize": [[UIScreen mainScreen] wmf_listThumbnailWidthForScale],
            @"pilimit": numResults,
            //@"rrvlimit": @(1),
            @"rvprop": @"ids",
            // -- Parameters causing prefix search to efficiently return suggestion.
            @"list": @"search",
            @"srsearch": searchTerm,
            @"srnamespace": @0,
            @"srwhat": @"text",
            @"srinfo": @"suggestion",
            @"srprop": @"",
            @"sroffset": @0,
            @"srlimit": @1,
            @"redirects": @1,
            // --
            @"continue": @"",
            @"format": @"json"
        };
    } else {
        params = @{
            @"action": @"query",
            @"prop": @"description|pageprops|pageimages|revisions|coordinates",
            @"coprop": @"type|dim",
            @"ppprop": @"displaytitle|disambiguation",
            @"generator": @"search",
            @"gsrsearch": searchTerm,
            @"gsrnamespace": @0,
            @"gsrwhat": @"text",
            @"gsrinfo": @"",
            @"gsrprop": @"redirecttitle",
            @"gsroffset": @0,
            @"gsrlimit": numResults,
            @"piprop": @"thumbnail",
            //@"pilicense": @"any",
            @"pithumbsize": [[UIScreen mainScreen] wmf_listThumbnailWidthForScale],
            @"pilimit": numResults,
            //@"rrvlimit": @(1),
            @"rvprop": @"ids",
            @"continue": @"",
            @"format": @"json",
            @"redirects": @1,
        };
    }
    [self performMediaWikiAPIGETForURL:siteURL
                   withQueryParameters:params
                     completionHandler:^(NSDictionary<NSString *, id> *_Nullable result, NSHTTPURLResponse *_Nullable response, NSError *_Nullable error) {
                         [[MWNetworkActivityIndicatorManager sharedManager] pop];
                         if (error) {
                             failure(error);
                             return;
                         }

                         NSDictionary *query = [result objectForKey:@"query"];
                         if (!query) {
                             success([[WMFSearchResults alloc] init]);
                             return;
                         }

                         NSError *mantleError = nil;
                         WMFSearchResults *searchResults = [MTLJSONAdapter modelOfClass:[WMFSearchResults class] fromJSONDictionary:query error:&mantleError];
                         if (mantleError) {
                             failure(mantleError);
                             return;
                         }
                         searchResults.searchTerm = searchTerm;

                         if (!previousResults) {
                             success(searchResults);
                             return;
                         }

                         [previousResults mergeValuesForKeysFromModel:searchResults];

                         success(previousResults);
                     }];
}

@end

NS_ASSUME_NONNULL_END

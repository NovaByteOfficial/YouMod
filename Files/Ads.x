#import "Headers.h"

// YouTube-X (https://github.com/PoomSmart/YouTube-X)

// ─── Class cache ──────────────────────────────────────────────────────────────
// %c() / objc_getClass() is a hash-table lookup on every call.
// Cache the Class pointers once at dylib load so filteredArray — which runs on
// every feed scroll — pays zero lookup cost.
static Class sShelfRendererClass;
static Class sItemSectionRendererClass;

__attribute__((constructor)) static void _initClasses(void) {
    sShelfRendererClass       = objc_getClass("YTIShelfRenderer");
    sItemSectionRendererClass = objc_getClass("YTIItemSectionRenderer");
}

// ─── Ad string table ─────────────────────────────────────────────────────────
// CFSTR() constants are baked into the binary at compile time — zero heap
// allocation, zero init cost, no autorelease pool involvement.
// CFStringFindWithOptions + kCFCompareLiteral skips Unicode normalisation and
// locale processing; safe for these pure-ASCII identifiers, and measurably
// faster than -[NSString containsString:] which dispatches through ObjC and
// performs full Unicode-aware comparison.
// Ordered by estimated encounter frequency so the average search terminates
// early; re-order if profiling data says otherwise.
static const CFStringRef kAdStrings[] = {
    CFSTR("feed_ad_metadata"),
    CFSTR("text_search_ad"),
    CFSTR("brand_promo"),
    CFSTR("video_display_full_layout"),
    CFSTR("video_display_full_buttoned_layout"),
    CFSTR("carousel_footered_layout"),
    CFSTR("carousel_headered_layout"),
    CFSTR("eml.expandable_metadata"),
    CFSTR("full_width_portrait_image_layout"),
    CFSTR("full_width_square_image_layout"),
    CFSTR("landscape_image_wide_button_layout"),
    CFSTR("post_shelf"),
    CFSTR("product_carousel"),
    CFSTR("product_engagement_panel"),
    CFSTR("product_item"),
    CFSTR("shopping_carousel"),
    CFSTR("shopping_item_card_list"),
    CFSTR("statement_banner"),
    CFSTR("square_image_layout"),
    CFSTR("text_image_button_layout"),
};
static const CFIndex kAdStringsCount =
    (CFIndex)(sizeof(kAdStrings) / sizeof(kAdStrings[0]));

// ─── isProductList ────────────────────────────────────────────────────────────
static BOOL isProductList(YTICommand *command) {
    if ([command respondsToSelector:@selector(yt_showEngagementPanelEndpoint)]) {
        YTIShowEngagementPanelEndpoint *endpoint =
            [command yt_showEngagementPanelEndpoint];
        return [endpoint.identifier.tag isEqualToString:@"PAproduct_list"];
    }
    return NO;
}

// ─── getAdString ─────────────────────────────────────────────────────────────
NSString *getAdString(NSString *description) {
    if (!description) return nil;
    CFStringRef cfDesc  = (__bridge CFStringRef)description;
    CFRange     cfRange = CFRangeMake(0, CFStringGetLength(cfDesc));
    for (CFIndex i = 0; i < kAdStringsCount; ++i) {
        if (CFStringFindWithOptions(cfDesc, kAdStrings[i],
                                    cfRange, kCFCompareLiteral, NULL))
            return (__bridge NSString *)kAdStrings[i];
    }
    return nil;
}

// ─── isAdRenderer ────────────────────────────────────────────────────────────
// Changes vs original:
// 1. Nil guard on elementRenderer — callers in filteredArray now guarantee
//    non-nil, but defensive cost is negligible.
// 2. `respondsToSelector:hasCompatibilityOptions` result cached after first
//    call — all instances share the same Class, the answer never changes.
// 3. Unused `kind` parameter removed — it was never read inside the function,
//    so every call was pushing a dead argument onto the stack for nothing.
// 4. Return collapsed to a single expression.
static BOOL isAdRenderer(YTIElementRenderer *elementRenderer) {
    if (!elementRenderer) return NO;

    static BOOL sCompatChecked = NO;
    static BOOL sCompatExists  = NO;
    if (!sCompatChecked) {
        sCompatExists  =
            [elementRenderer respondsToSelector:@selector(hasCompatibilityOptions)];
        sCompatChecked = YES;
    }

    if (sCompatExists
        && elementRenderer.hasCompatibilityOptions
        && elementRenderer.compatibilityOptions.hasAdLoggingData)
        return YES;

    return getAdString(elementRenderer.description) != nil;
}

// ─── filteredArray ────────────────────────────────────────────────────────────
// Changes vs original:
// 1. Empty-array fast path — skips the mutableCopy + block setup entirely.
// 2. Cached isKindOfClass: Class pointers (see _initClasses above).
// 3. Nil guard + count guard before inner removeObjectsAtIndexes: calls —
//    avoids a no-op ObjC message when nothing was flagged.
// 4. Shelf renderer content chain cached in a local variable rather than
//    traversed twice.
// 5. contentsArray.count cached in `count` — avoids a second message send.
// 6. Nil guard on elementRenderer before passing to isAdRenderer.
// 7. Outer removeObjectsAtIndexes: guarded by removeIndexes.count.
static NSMutableArray<YTIItemSectionRenderer *> *filteredArray(
    NSArray<YTIItemSectionRenderer *> *array)
{
    if (!array.count) return [NSMutableArray array]; // nothing to filter

    NSMutableArray<YTIItemSectionRenderer *> *newArray = [array mutableCopy];

    NSIndexSet *removeIndexes = [newArray indexesOfObjectsPassingTest:
        ^BOOL(YTIItemSectionRenderer *sectionRenderer, NSUInteger idx, BOOL *stop) {

        // ── Shelf path ───────────────────────────────────────────────────────
        if ([sectionRenderer isKindOfClass:sShelfRendererClass]) {
            NSMutableArray<YTIHorizontalListSupportedRenderers *> *items =
                ((YTIShelfRenderer *)sectionRenderer)
                    .content.horizontalListRenderer.itemsArray;
            if (items.count) {
                NSIndexSet *toRemove = [items indexesOfObjectsPassingTest:
                    ^BOOL(YTIHorizontalListSupportedRenderers *item,
                          NSUInteger i2, BOOL *s2) {
                        YTIElementRenderer *er = item.elementRenderer;
                        return er && isAdRenderer(er);
                    }];
                if (toRemove.count) [items removeObjectsAtIndexes:toRemove];
            }
        }

        // ── Section path ─────────────────────────────────────────────────────
        if (![sectionRenderer isKindOfClass:sItemSectionRendererClass])
            return NO;

        NSMutableArray<YTIItemSectionSupportedRenderers *> *contents =
            sectionRenderer.contentsArray;
        NSUInteger count = contents.count;

        if (count > 1) {
            NSIndexSet *toRemove = [contents indexesOfObjectsPassingTest:
                ^BOOL(YTIItemSectionSupportedRenderers *item,
                      NSUInteger i2, BOOL *s2) {
                    YTIElementRenderer *er = item.elementRenderer;
                    return er && isAdRenderer(er);
                }];
            if (toRemove.count) [contents removeObjectsAtIndexes:toRemove];
        }

        YTIElementRenderer *firstRenderer = contents.firstObject.elementRenderer;
        return firstRenderer && isAdRenderer(firstRenderer);
    }];

    if (removeIndexes.count) [newArray removeObjectsAtIndexes:removeIndexes];
    return newArray;
}

// ─────────────────────────────────────────────────────────────────────────────
// Hooks
// ─────────────────────────────────────────────────────────────────────────────

%hook YTPlayerResponse
%new(@@:)
- (NSMutableArray *)playerAdsArray { return [NSMutableArray array]; }
%new(@@:)
- (NSMutableArray *)adSlotsArray   { return [NSMutableArray array]; }
%end

%hook YTIClientMdxGlobalConfig
%new(B@:)
- (BOOL)enableSkippableAd { return YES; }
%end

%hook YTAdShieldUtils
+ (id)spamSignalsDictionary             { return @{}; }
+ (id)spamSignalsDictionaryWithoutIDFA  { return @{}; }
%end

%hook YTDataUtils
+ (id)spamSignalsDictionary             { return @{ @"ms": @"" }; }
+ (id)spamSignalsDictionaryWithoutIDFA  { return @{}; }
%end

%hook YTAdsInnerTubeContextDecorator
- (void)decorateContext:(id)context { %orig(nil); }
%end

%hook YTAccountScopedAdsInnerTubeContextDecorator
- (void)decorateContext:(id)context { %orig(nil); }
%end

%hook YTLocalPlaybackController
- (id)createAdsPlaybackCoordinator { return nil; }
%end

%hook MDXSession
- (void)adPlaying:(id)ad {}
%end

%hook MDXSessionImpl
- (void)adPlaying:(id)ad {}
%end

// ── Shorts ad filtering ───────────────────────────────────────────────────────
// respondsToSelector:videoType cached after first call in setReels: since it
// runs inside a block enumerated over every reel in the ordered set.

%hook YTReelDataSource
- (YTReelModel *)makeContentModelForEntry:(id)entry {
    YTReelModel *model = %orig;
    if (model
        && [model respondsToSelector:@selector(videoType)]
        && model.videoType == 3)
        return nil;
    return model;
}
%end

%hook YTReelInfinitePlaybackDataSource
- (YTReelModel *)makeContentModelForEntry:(id)entry {
    YTReelModel *model = %orig;
    if (model
        && [model respondsToSelector:@selector(videoType)]
        && model.videoType == 3)
        return nil;
    return model;
}
- (void)setReels:(NSMutableOrderedSet<YTReelModel *> *)reels {
    // Cache selector result — all YTReelModel instances share the same Class.
    static BOOL sVTChecked = NO;
    static BOOL sVTExists  = NO;
    [reels removeObjectsAtIndexes:[reels indexesOfObjectsPassingTest:
        ^BOOL(YTReelModel *obj, NSUInteger idx, BOOL *stop) {
            if (!sVTChecked) {
                sVTExists  = [obj respondsToSelector:@selector(videoType)];
                sVTChecked = YES;
            }
            return sVTExists ? obj.videoType == 3 : NO;
        }]];
    %orig;
}
%end

// ── Watch next / product list ─────────────────────────────────────────────────

%hook YTWatchNextResponseViewController
- (void)loadWithModel:(YTIWatchNextResponse *)model {
    YTICommand *onUiReady = model.onUiReady;
    if ([onUiReady respondsToSelector:@selector(yt_commandExecutorCommand)]) {
        NSMutableArray<YTICommand *> *cmds =
            [[onUiReady yt_commandExecutorCommand] commandsArray];
        NSIndexSet *toRemove = [cmds indexesOfObjectsPassingTest:
            ^BOOL(YTICommand *cmd, NSUInteger idx, BOOL *stop) {
                return isProductList(cmd);
            }];
        if (toRemove.count) [cmds removeObjectsAtIndexes:toRemove];
    }
    if (isProductList(onUiReady)) model.onUiReady = nil;
    %orig;
}
%end

%hook YTMainAppVideoPlayerOverlayViewController
- (void)playerOverlayProvider:(YTPlayerOverlayProvider *)provider
       didInsertPlayerOverlay:(YTPlayerOverlay *)overlay {
    if ([[overlay overlayIdentifier]
            isEqualToString:@"player_overlay_product_in_video"]) return;
    %orig;
}
%end

// ── Feed ad section filtering ─────────────────────────────────────────────────

%hook YTInnerTubeCollectionViewController
- (void)displaySectionsWithReloadingSectionControllerByRenderer:(id)renderer {
    NSMutableArray *sr = [self valueForKey:@"_sectionRenderers"];
    [self setValue:filteredArray(sr) forKey:@"_sectionRenderers"];
    %orig;
}
- (void)addSectionsFromArray:(NSArray<YTIItemSectionRenderer *> *)array {
    %orig(filteredArray(array));
}
%end

// ── View-level ad element hiding ──────────────────────────────────────────────
// didMoveToWindow fires for every _ASDisplayView entering/leaving the window
// hierarchy — potentially hundreds of calls per scroll.
// Changes vs original:
// 1. accessibilityIdentifier fetched once into a local — avoids two ObjC
//    property calls on the hot path.
// 2. Nil guard returns immediately for the vast majority of views that carry
//    no identifier at all.
// 3. else-if used: the two identifiers are mutually exclusive, so the second
//    comparison is skipped once the first matches.

%hook _ASDisplayView
- (void)didMoveToWindow {
    %orig;
    NSString *identifier = self.accessibilityIdentifier;
    if (!identifier) return;
    if ([identifier isEqualToString:@"eml.expandable_metadata.vpp"])
        [self removeFromSuperview];
    else if ([identifier isEqualToString:@"eml.ad_layout.full_width_square_image_layout"])
        self.hidden = YES;
}
%end

// ─────────────────────────────────────────────────────────────────────────────
// NoYTPremium — @PoomSmart https://github.com/PoomSmart/NoYTPremium
// ─────────────────────────────────────────────────────────────────────────────

// Alert
%hook YTCommerceEventGroupHandler
- (void)addEventHandlers {}
%end

// Full-screen
%hook YTInterstitialPromoEventGroupHandler
- (void)addEventHandlers {}
%end

%hook YTPromosheetEventGroupHandler
- (void)addEventHandlers {}
%end

%hook YTPromoThrottleController
- (BOOL)canShowThrottledPromo                              { return NO; }
- (BOOL)canShowThrottledPromoWithFrequencyCap:(id)arg1    { return NO; }
- (BOOL)canShowThrottledPromoWithFrequencyCaps:(id)arg1   { return NO; }
%end

%hook YTPromoThrottleControllerImpl
- (BOOL)canShowThrottledPromo                              { return NO; }
- (BOOL)canShowThrottledPromoWithFrequencyCap:(id)arg1    { return NO; }
- (BOOL)canShowThrottledPromoWithFrequencyCaps:(id)arg1   { return NO; }
%end

%hook YTIShowFullscreenInterstitialCommand
- (BOOL)shouldThrottleInterstitial {
    if (self.hasModalClientThrottlingRules)
        self.modalClientThrottlingRules.oncePerTimeWindow = YES;
    return %orig;
}
%end

// "Try new features" in settings
%hook YTSettingsSectionItemManager
- (void)updatePremiumEarlyAccessSectionWithEntry:(id)arg1 {}
%end

// Survey
%hook YTSurveyController
- (void)showSurveyWithRenderer:(id)arg1
          surveyParentResponder:(id)arg2 {}
%end

#import "Headers.h"

static NSString * const HBShortsVideoCellMarker = @"shorts_video_cell";
static NSString * const HBShortsShelfMarker = @"shorts_shelf.eml";

static BOOL HBDescriptionContains(NSString *text, NSString *needle) {
    return (text.length > 0 && needle.length > 0 && [text containsString:needle]);
}

static BOOL HBShelfRendererContainsShorts(YTIShelfRenderer *shelfRenderer) {
    YTIShelfSupportedRenderers *content = shelfRenderer.content;
    YTIHorizontalListRenderer *horizontalListRenderer = content.horizontalListRenderer;
    NSArray<YTIHorizontalListSupportedRenderers *> *itemsArray = horizontalListRenderer.itemsArray;

    if (![itemsArray isKindOfClass:[NSArray class]] || itemsArray.count == 0) {
        return NO;
    }

    for (YTIHorizontalListSupportedRenderers *item in itemsArray) {
        YTIElementRenderer *elementRenderer = item.elementRenderer;
        if (HBDescriptionContains([elementRenderer description], HBShortsVideoCellMarker)) {
            return YES;
        }
    }

    return NO;
}

static BOOL HBSectionRendererShouldRemove(YTIItemSectionRenderer *sectionRenderer) {
    if ([sectionRenderer isKindOfClass:%c(YTIShelfRenderer)]) {
        return HBShelfRendererContainsShorts((YTIShelfRenderer *)sectionRenderer);
    }

    if ([sectionRenderer isKindOfClass:%c(YTIItemSectionRenderer)]) {
        return HBDescriptionContains([sectionRenderer description], HBShortsShelfMarker);
    }

    return NO;
}

static NSMutableArray<YTIItemSectionRenderer *> *HBFilteredArray(NSArray<YTIItemSectionRenderer *> *array) {
    if (![array isKindOfClass:[NSArray class]] || array.count == 0) {
        return [array mutableCopy] ?: [NSMutableArray array];
    }

    NSMutableArray<YTIItemSectionRenderer *> *newArray = [array mutableCopy];
    NSIndexSet *removeIndexes = [newArray indexesOfObjectsPassingTest:^BOOL(YTIItemSectionRenderer *sectionRenderer, NSUInteger idx, BOOL *stop) {
        return HBSectionRendererShouldRemove(sectionRenderer);
    }];

    if (removeIndexes.count > 0) {
        [newArray removeObjectsAtIndexes:removeIndexes];
    }

    return newArray;
}

%group Shorts

%hook YTInnerTubeCollectionViewController

- (void)displaySectionsWithReloadingSectionControllerByRenderer:(id)renderer {
    NSMutableArray *sectionRenderers = [self valueForKey:@"_sectionRenderers"];
    if ([sectionRenderers isKindOfClass:[NSArray class]]) {
        [self setValue:HBFilteredArray(sectionRenderers) forKey:@"_sectionRenderers"];
    }
    %orig;
}

- (void)addSectionsFromArray:(NSArray<YTIItemSectionRenderer *> *)array {
    %orig(HBFilteredArray(array));
}

%end
%end

// Hide Subbar
%hook YTMySubsFilterHeaderView
- (void)setChipFilterView:(id)arg1 {
    if (!IS_ENABLED(HideSubbar)) {
        %orig;
    }
}
%end

%hook YTHeaderContentComboView
- (void)enableSubheaderBarWithView:(id)arg1 {
    if (!IS_ENABLED(HideSubbar)) {
        %orig;
    }
}

- (void)setFeedHeaderScrollMode:(int)arg1 {
    %orig(IS_ENABLED(HideSubbar) ? 0 : arg1);
}
%end

%hook YTChipCloudCell
- (void)layoutSubviews {
    %orig;

    if (IS_ENABLED(HideSubbar) && self.superview) {
        [self removeFromSuperview];
    }
}
%end

// Hide voice search button
%hook YTSearchViewController
- (void)viewDidLoad {
    %orig;

    if (IS_ENABLED(HideVoiceSearch)) {
        [self setValue:@(NO) forKey:@"_isVoiceSearchAllowed"];
    }
}

- (void)setSuggestions:(id)arg1 {
    if (!IS_ENABLED(HideSearchHis)) {
        %orig;
    }
}
%end

// Hide search history and suggestions
%hook YTPersonalizedSuggestionsCacheProvider
- (id)activeCache {
    return IS_ENABLED(HideSearchHis) ? nil : %orig;
}
%end

%ctor {
    %init;
    if (IS_ENABLED(HideShortsShelf)) {
        %init(Shorts);
    }
}

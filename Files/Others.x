#import "Headers.h"

Class YTILikeResponseClass, YTIDislikeResponseClass, YTIRemoveLikeResponseClass;

static inline BOOL HBIsSilentVoteResponse(id response) {
    return [response isKindOfClass:YTILikeResponseClass] ||
           [response isKindOfClass:YTIDislikeResponseClass] ||
           [response isKindOfClass:YTIRemoveLikeResponseClass];
}

// Background playback
%group BackgroundPlayback

%hook YTIBackgroundOfflineSettingCategoryEntryRenderer
%new(B@:)
- (BOOL)isBackgroundEnabled {
    return YES;
}
%end

%end

%hook MLVideo
- (BOOL)playableInBackground {
    return IS_ENABLED(BackgroundPlayback) ? YES : %orig;
}
%end

%hook YTIPlayabilityStatus
- (BOOL)isPlayableInBackground {
    return IS_ENABLED(BackgroundPlayback) ? YES : %orig;
}
%end

%hook YTPlaybackData
- (BOOL)isPlayableInBackground {
    return IS_ENABLED(BackgroundPlayback) ? YES : %orig;
}
%end

%hook YTIPlayerResponse
- (BOOL)isPlayableInBackground {
    return IS_ENABLED(BackgroundPlayback) ? YES : %orig;
}
%end

// Try to disable Shorts PiP
%hook YTColdConfig
- (BOOL)shortsPlayerGlobalConfigEnableReelsPictureInPicture {
    return IS_ENABLED(DisablesShortsPiP) ? NO : %orig;
}
- (BOOL)shortsPlayerGlobalConfigEnableReelsPictureInPictureIos {
    return IS_ENABLED(DisablesShortsPiP) ? NO : %orig;
}
%end

%hook YTHotConfig
- (BOOL)shortsPlayerGlobalConfigEnableReelsPictureInPictureAllowedFromPlayer {
    return IS_ENABLED(DisablesShortsPiP) ? NO : %orig;
}
%end

%hook YTReelModel
- (BOOL)isPiPSupported {
    return IS_ENABLED(DisablesShortsPiP) ? NO : %orig;
}
%end

%hook YTReelPlayerViewController
- (BOOL)isPictureInPictureAllowed {
    return IS_ENABLED(DisablesShortsPiP) ? NO : %orig;
}
%end

%hook YTReelWatchRootViewController
- (void)switchToPictureInPicture {
    if (!IS_ENABLED(DisablesShortsPiP)) {
        %orig;
    }
}
%end

// Block upgrade dialogs
%hook YTGlobalConfig
- (BOOL)shouldBlockUpgradeDialog {
    return IS_ENABLED(BlockUpgradeDialogs) ? YES : %orig;
}
- (BOOL)shouldShowUpgradeDialog {
    return IS_ENABLED(BlockUpgradeDialogs) ? NO : %orig;
}
- (BOOL)shouldShowUpgrade {
    return IS_ENABLED(BlockUpgradeDialogs) ? NO : %orig;
}
- (BOOL)shouldForceUpgrade {
    return IS_ENABLED(BlockUpgradeDialogs) ? NO : %orig;
}
%end

// Prevent YouTube from asking "Are you there?"
%hook YTColdConfig
- (BOOL)enableYouthereCommandsOnIos {
    return IS_ENABLED(BlockUpgradeDialogs) ? NO : %orig;
}
- (BOOL)enableIosFloatingMiniplayerDoubleTapToResize {
    return IS_ENABLED(FixesSlowMiniPlayer) ? NO : %orig;
}
- (BOOL)enableIosFloatingMiniplayer {
    return IS_ENABLED(DisablesNewMiniPlayer) ? NO : %orig;
}
- (BOOL)mainAppCoreClientIosEnableStartupAnimation {
    return IS_ENABLED(HideStartupAni) ? NO : %orig;
}
%end

%hook YTYouThereController
- (BOOL)shouldShowYouTherePrompt {
    return IS_ENABLED(HideAreYouThereDialog) ? NO : %orig;
}
- (void)showYouTherePrompt {
    if (!IS_ENABLED(HideAreYouThereDialog)) {
        %orig;
    }
}
%end

%hook YTYouThereControllerImpl
- (BOOL)shouldShowYouTherePrompt {
    return IS_ENABLED(HideAreYouThereDialog) ? NO : %orig;
}
- (void)showYouTherePrompt {
    if (!IS_ENABLED(HideAreYouThereDialog)) {
        %orig;
    }
}
%end

// Disables Snackbar
%hook GOOHUDManagerInternal
- (id)sharedInstance {
    return IS_ENABLED(DisablesSnackBar) ? nil : %orig;
}
- (void)showMessageMainThread:(id)arg {
    if (!IS_ENABLED(DisablesSnackBar)) {
        %orig;
    }
}
- (void)activateOverlay:(id)arg {
    if (!IS_ENABLED(DisablesSnackBar)) {
        %orig;
    }
}
- (void)displayHUDViewForMessage:(id)arg {
    if (!IS_ENABLED(DisablesSnackBar)) {
        %orig;
    }
}
%end

// Remove "Play next in queue" from the menu @PoomSmart
%hook YTMenuItemVisibilityHandler
- (BOOL)shouldShowServiceItemRenderer:(YTIMenuConditionalServiceItemRenderer *)renderer {
    if (IS_ENABLED(HidePlayInNextQueue) && renderer.icon.iconType == 251) {
        return NO;
    }
    return %orig;
}
%end

%hook YTMenuItemVisibilityHandlerImpl
- (BOOL)shouldShowServiceItemRenderer:(YTIMenuConditionalServiceItemRenderer *)renderer {
    if (IS_ENABLED(HidePlayInNextQueue) && renderer.icon.iconType == 251) {
        return NO;
    }
    return %orig;
}
%end

/* untested
// Remove Download button from the menu
%hook YTDefaultSheetController
- (void)addAction:(YTActionSheetAction *)action {
    NSString *identifier = [action valueForKey:@"_accessibilityIdentifier"];

    NSDictionary *actionsToRemove = @{
        @"7": @(ytlBool(@"removeDownloadMenu")),
        @"1": @(ytlBool(@"removeWatchLaterMenu")),
        @"3": @(ytlBool(@"removeSaveToPlaylistMenu")),
        @"5": @(ytlBool(@"removeShareMenu")),
        @"12": @(ytlBool(@"removeNotInterestedMenu")),
        @"31": @(ytlBool(@"removeDontRecommendMenu")),
        @"58": @(ytlBool(@"removeReportMenu"))
    };

    if (![actionsToRemove[identifier] boolValue]) {
        %orig;
    }
}
%end
*/

// YTSlientVote
%group SlientVote

%hook YTInnerTubeResponseWrapper
- (id)initWithResponse:(id)response
          cacheContext:(id)arg2
      requestStatistics:(id)arg3
       mutableSharedData:(id)arg4
{
    if (HBIsSilentVoteResponse(response)) {
        return nil;
    }
    return %orig;
}
%end

%end

%ctor {
    YTILikeResponseClass = %c(YTILikeResponse);
    YTIDislikeResponseClass = %c(YTIDislikeResponse);
    YTIRemoveLikeResponseClass = %c(YTIRemoveLikeResponse);

    %init;

    if (IS_ENABLED(HideLikeDislikeVotes)) {
        %init(SlientVote);
    }

    if (IS_ENABLED(BackgroundPlayback)) {
        %init(BackgroundPlayback);
    }
}

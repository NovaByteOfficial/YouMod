#import "Headers.h"

// YouTube Premium logo
%hook YTHeaderLogoController

- (void)setTopbarLogoRenderer:(YTITopbarLogoRenderer *)renderer {
    if (!IS_ENABLED(YTPremiumLogo)) {
        %orig;
        return;
    }

    YTIIcon *icon = renderer.iconImage;
    if (icon) {
        icon.iconType = 537;
    }

    %orig(renderer);
}

// For when spoofing before 18.34.5
- (void)setPremiumLogo:(BOOL)arg {
    IS_ENABLED(YTPremiumLogo) ? %orig(YES) : %orig;
}

- (BOOL)isPremiumLogo {
    return IS_ENABLED(YTPremiumLogo) ? YES : %orig;
}

%end

%hook YTHeaderLogoControllerImpl

- (void)setTopbarLogoRenderer:(YTITopbarLogoRenderer *)renderer {
    if (!IS_ENABLED(YTPremiumLogo)) {
        %orig;
        return;
    }

    YTIIcon *icon = renderer.iconImage;
    if (icon) {
        icon.iconType = 537;
    }

    %orig(renderer);
}

// For when spoofing before 18.34.5
- (void)setPremiumLogo:(BOOL)arg {
    IS_ENABLED(YTPremiumLogo) ? %orig(YES) : %orig;
}

- (BOOL)isPremiumLogo {
    return IS_ENABLED(YTPremiumLogo) ? YES : %orig;
}

%end

// Hide Navigation Bar Buttons
%hook YTRightNavigationButtons

- (void)layoutSubviews {
    %orig;

    BOOL hideNoti = IS_ENABLED(HideNoti);
    BOOL hideSearch = IS_ENABLED(HideSearch);
    BOOL hideVoiceSearch = IS_ENABLED(HideVoiceSearch);
    BOOL hideCast = IS_ENABLED(HideCastButtonNav);

    if (hideNoti) {
        self.notificationButton.hidden = YES;
    }

    if (hideSearch) {
        self.searchButton.hidden = YES;
    }

    for (UIView *subview in self.subviews) {
        if (hideVoiceSearch &&
            [subview.accessibilityLabel isEqualToString:NSLocalizedString(@"search.voice.access", nil)]) {
            subview.hidden = YES;
        }

        if (hideCast &&
            [subview.accessibilityIdentifier isEqualToString:@"id.mdx.playbackroute.button"]) {
            subview.hidden = YES;
        }
    }
}

%end

%hook YTHeaderLogoController

- (id)init {
    return IS_ENABLED(HideYTLogo) ? nil : %orig;
}

%end

%hook YTHeaderLogoControllerImpl

- (id)init {
    return IS_ENABLED(HideYTLogo) ? nil : %orig;
}

%end

%hook YTNavigationBarTitleView

- (void)layoutSubviews {
    %orig;

    if (!IS_ENABLED(HideYTLogo) || self.subviews.count <= 1) {
        return;
    }

    UIView *logoView = self.subviews[1];
    if ([logoView.accessibilityIdentifier isEqualToString:@"id.yoodle.logo"]) {
        logoView.hidden = YES;
    }
}

%end

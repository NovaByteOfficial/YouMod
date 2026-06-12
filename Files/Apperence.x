#import "Headers.h"

static inline BOOL HBIsDarkMode(UIView *view) {
    if (!view) return NO;

    if ([view respondsToSelector:@selector(_mapkit_isDarkModeEnabled)]) {
        return view._mapkit_isDarkModeEnabled;
    }

    return view.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
}

static inline UIColor *HBBlackColor(void) {
    return UIColor.blackColor;
}

static inline UIColor *HBClearColor(void) {
    return UIColor.clearColor;
}

static inline UIColor *HBBlack90Color(void) {
    static UIColor *color;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        color = [[UIColor blackColor] colorWithAlphaComponent:0.9];
    });
    return color;
}

static inline void HBSetBackgroundColorIfNeeded(UIView *view, UIColor *color) {
    if (view && view.backgroundColor != color) {
        view.backgroundColor = color;
    }
}

static inline void HBApplyOLEDBackground(UIView *view) {
    HBSetBackgroundColorIfNeeded(
        view,
        HBIsDarkMode(view) ? HBBlackColor() : HBClearColor()
    );
}

static Class HBEmojiSearchInputViewClass(void) {
    static Class cls;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cls = NSClassFromString(@"TUIEmojiSearchInputView");
    });
    return cls;
}

static Class HBAutoFillInputViewClass(void) {
    static Class cls;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cls = NSClassFromString(@"_SFAutoFillInputView");
    });
    return cls;
}

static inline BOOL HBIsSpecialInputView(UIView *view) {
    Class emojiClass = HBEmojiSearchInputViewClass();
    Class autofillClass = HBAutoFillInputViewClass();

    return (emojiClass && [view isKindOfClass:emojiClass]) ||
           (autofillClass && [view isKindOfClass:autofillClass]);
}

#pragma mark - OLED Theme

%group OLEDTheme

%hook YTColor

+ (UIColor *)black0 { return HBBlackColor(); }
+ (UIColor *)black1 { return HBBlackColor(); }
+ (UIColor *)black2 { return HBBlackColor(); }
+ (UIColor *)black3 { return HBBlackColor(); }
+ (UIColor *)black4 { return HBBlackColor(); }

%end

%hook YTCommonColorPalette

- (UIColor *)baseBackground {
    return self.pageStyle == 1 ? HBBlackColor() : %orig;
}

- (UIColor *)brandBackgroundSolid {
    return self.pageStyle == 1 ? HBBlackColor() : %orig;
}

- (UIColor *)brandBackgroundPrimary {
    return self.pageStyle == 1 ? HBBlackColor() : %orig;
}

- (UIColor *)brandBackgroundSecondary {
    return self.pageStyle == 1 ? HBBlack90Color() : %orig;
}

- (UIColor *)raisedBackground {
    return self.pageStyle == 1 ? HBBlackColor() : %orig;
}

- (UIColor *)staticBrandBlack {
    return self.pageStyle == 1 ? HBBlackColor() : %orig;
}

- (UIColor *)generalBackgroundA {
    return self.pageStyle == 1 ? HBBlackColor() : %orig;
}

%end

%hook YTInnerTubeCollectionViewController

- (UIColor *)backgroundColor:(NSInteger)pageStyle {
    return pageStyle == 1 ? HBBlackColor() : %orig;
}

%end

%end

#pragma mark - OLED Keyboard

%group OLEDKeyboard

%hook UIKeyboard

- (void)displayLayer:(id)arg1 {
    %orig;

    HBSetBackgroundColorIfNeeded(
        self,
        HBIsDarkMode(self) ? HBBlackColor() : HBClearColor()
    );
}

%end

%hook UIPredictionViewController

- (id)_currentTextSuggestions {
    UIKeyboard *keyboard = [%c(UIKeyboard) activeKeyboard];

    BOOL dark = HBIsDarkMode(keyboard);

    HBSetBackgroundColorIfNeeded(
        self.view,
        dark ? HBBlackColor() : HBClearColor()
    );

    if (keyboard) {
        HBSetBackgroundColorIfNeeded(
            keyboard,
            dark ? HBBlackColor() : HBClearColor()
        );
    }

    return %orig;
}

%end

%hook UIKeyboardDockView

- (void)layoutSubviews {
    %orig;
    HBApplyOLEDBackground(self);
}

%end

%hook UIInputView

- (void)layoutSubviews {
    %orig;

    if (HBIsSpecialInputView(self)) {
        HBApplyOLEDBackground(self);
    }
}

%end

%hook UIKBVisualEffectView

- (void)layoutSubviews {
    %orig;

    if (HBIsDarkMode(self)) {
        if (self.backgroundEffects != nil) {
            self.backgroundEffects = nil;
        }

        HBSetBackgroundColorIfNeeded(
            self,
            HBBlackColor()
        );
    }
}

%end

%end

#pragma mark - Constructor

%ctor {
    if (IS_ENABLED(OLEDTheme)) {
        %init(OLEDTheme);
    }

    if (IS_ENABLED(OLEDKeyboard)) {
        %init(OLEDKeyboard);
    }
}

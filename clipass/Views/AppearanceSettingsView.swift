import SwiftUI

// MARK: - MiniOverlayMockup

/// Renders a miniature overlay that matches the real overlay layout using a given theme.
/// Uses solid rectangles for the background (no actual vibrancy) so it renders correctly
/// in the settings panel and at reduced scale.
struct MiniOverlayMockup: View {

    let theme: Theme

    // Fake clipboard items for the mockup
    private let fakeItems: [(title: String, subtitle: String)] = [
        ("Meeting notes from standup", "Notes - 2m ago"),
        ("https://github.com/project/pull/42", "Safari - 5m ago"),
        ("ssh-rsa AAAB3...truncated", "Terminal - 1h ago")
    ]

    @ViewBuilder private var mockupDivider: some View {
        switch theme.dividerStyle {
        case .standard:
            Rectangle()
                .fill(theme.dividerColor)
                .frame(height: 1)
        case .thick:
            Rectangle()
                .fill(theme.dividerColor)
                .frame(height: 2)
        case .none:
            EmptyView()
        }
    }

    var body: some View {
        ZStack {
            // Solid background rectangle (vibrancy not used in miniature)
            Rectangle()
                .fill(theme.overlayBackground)

            VStack(spacing: 0) {
                // Search field area
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: theme.bodyFontSize * 0.85))
                        .foregroundColor(theme.searchFieldPlaceholder)
                    Text("Search clipboard...")
                        .font(.system(size: theme.bodyFontSize, weight: .regular))
                        .foregroundColor(theme.searchFieldPlaceholder)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: theme.itemCornerRadius)
                        .fill(theme.searchFieldBackground)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                )

                mockupDivider

                // Clipboard item rows
                VStack(spacing: 0) {
                    ForEach(Array(fakeItems.enumerated()), id: \.offset) { index, item in
                        let isSelected = index == 0
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .lineLimit(1)
                                .font(.system(size: theme.bodyFontSize, weight: theme.titleFontWeight))
                                .foregroundColor(isSelected ? .white : theme.primaryText)
                            Text(item.subtitle)
                                .lineLimit(1)
                                .font(.system(size: theme.bodyFontSize * 0.75, weight: .regular))
                                .foregroundColor(isSelected ? Color.white.opacity(0.75) : theme.secondaryText)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, theme.itemVerticalPadding)
                        .background(
                            RoundedRectangle(cornerRadius: theme.itemCornerRadius)
                                .fill(isSelected ? theme.itemBackground : Color.clear)
                                .padding(.horizontal, 4)
                        )
                    }
                }
                .padding(.vertical, 4)

                mockupDivider

                // Bottom bar
                HStack {
                    Spacer()
                    Text("3 items")
                        .font(.system(size: theme.bodyFontSize * 0.75, weight: .regular))
                        .foregroundColor(theme.secondaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
    }
}

// MARK: - ThemePreviewCard

/// A selectable card showing a mini overlay mockup for a given theme.
/// Selected state is indicated by a checkmark badge and accent-colored border.
struct ThemePreviewCard: View {

    let theme: Theme
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Mini mockup rendered at full resolution then scaled down.
            // scaleEffect does NOT affect layout, so we must collapse the layout frame manually
            // after scaling: render at 480x300, scale by 0.5, collapse to 240x150.
            ZStack(alignment: .topTrailing) {
                MiniOverlayMockup(theme: theme)
                    .frame(width: 480, height: 300)
                    .scaleEffect(0.5, anchor: .topLeading)
                    .frame(width: 240, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(theme.accentColor)
                        .background(Circle().fill(Color.white).padding(2))
                        .padding(6)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isSelected ? theme.accentColor : Color.primary.opacity(0.15),
                        lineWidth: isSelected ? 2 : 1
                    )
            )

            // Theme name label
            Text(theme.name)
                .font(.headline)
                .foregroundColor(.primary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.04))
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    isSelected ? theme.accentColor.opacity(0.5) : Color.clear,
                    lineWidth: 1
                )
        )
        .onTapGesture {
            onSelect()
        }
    }
}

// MARK: - AppearanceSettingsView

/// Settings tab for browsing and selecting themes.
/// Shows one ThemePreviewCard per theme in a vertically scrollable list.
/// Selecting a card instantly applies the theme — no restart or Apply button required.
struct AppearanceSettingsView: View {

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(ThemeID.allCases, id: \.self) { id in
                    if let theme = Theme.themes[id] {
                        ThemePreviewCard(
                            theme: theme,
                            isSelected: themeManager.selectedID == id
                        ) {
                            themeManager.select(id)
                        }
                    }
                }
            }
            .padding(16)
        }
    }
}

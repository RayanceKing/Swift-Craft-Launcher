import SwiftUI

struct ExploreView: View {
    @EnvironmentObject var filterState: ResourceFilterState
    @State private var selectedResourceType: ResourceType = .mod

    private let resourceTypes = ResourceType.allCases

    var body: some View {
        VStack(spacing: 0) {
            filterChips
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            Divider()

            CategoryContentView(
                project: selectedResourceType.rawValue,
                type: "resource",
                selectedCategories: filterState.selectedCategoriesBinding,
                selectedFeatures: filterState.selectedFeaturesBinding,
                selectedResolutions: filterState.selectedResolutionsBinding,
                selectedPerformanceImpacts: filterState.selectedPerformanceImpactBinding,
                selectedVersions: filterState.selectedVersionsBinding,
                selectedLoaders: filterState.selectedLoadersBinding,
                gameVersion: nil,
                gameLoader: nil,
                dataSource: filterState.dataSource
            )
            .id(selectedResourceType)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(resourceTypes, id: \.self) { type in
                    Button {
                        guard selectedResourceType != type else { return }
                        selectedResourceType = type
                        filterState.clearFiltersAndPagination()
                        filterState.selectedTab = 0
                    } label: {
                        Label(type.localizedName, systemImage: type.systemImage)
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                selectedResourceType == type
                                    ? Color.accentColor
                                    : Color.secondary.opacity(0.12)
                            )
                            .foregroundColor(
                                selectedResourceType == type ? .white : .primary
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

import SwiftUI

struct AccountSyncSection: View {
    let coordinator: AccountSyncCoordinator

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Label(coordinator.statusText, systemImage: coordinator.statusSymbol)
                    .font(AppTypography.headline)
                if let confirmed = coordinator.lastConfirmedAt {
                    Text("Last confirmed: \(confirmed.formatted(date: .abbreviated, time: .shortened))")
                        .font(AppTypography.caption).foregroundStyle(Color.textSecondary)
                }
                if !coordinator.local.migrationComplete {
                    Text("Initial upload is not yet confirmed. Keep this device’s local data until sync completes.")
                        .font(AppTypography.body)
                }
                Button("Sync now", action: coordinator.syncNow)
                    .buttonStyle(.appSecondary).accessibilityIdentifier("account.syncNow")
                if !coordinator.local.conflicts.isEmpty {
                    NavigationLink {
                        SyncConflictsView(coordinator: coordinator)
                    } label: {
                        Label("Review conflicting edits", systemImage: "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90")
                    }
                    .font(AppTypography.body)
                    .accessibilityIdentifier("sync.conflicts")
                }
                Text("Reminder preferences sync. Notification permission stays on each device; more than one device may notify you.")
                    .font(AppTypography.caption).foregroundStyle(Color.textSecondary)
            }
        }
    }
}

private struct SyncConflictsView: View {
    let coordinator: AccountSyncCoordinator

    var body: some View {
        List {
            Section {
                Text("Another device saved a different version first. The cloud version is shown in your library. Your conflicting edits are kept here until you choose.")
                Text("Restoring retries your saved edit against the latest downloaded version. A deleted item is only recreated when you explicitly restore it.")
            }
            ForEach(coordinator.local.conflicts) { conflict in
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text(coordinator.conflictTitle(conflict)).font(AppTypography.headline)
                    Text(conflict.detectedAt, format: .dateTime.day().month().hour().minute())
                        .font(AppTypography.caption).foregroundStyle(Color.textSecondary)
                    if conflict.rejected.payload == nil {
                        Text("Your edit deleted this item.")
                    } else if let summary = coordinator.conflictSummary(conflict) {
                        Text(summary).font(AppTypography.body)
                    }
                    if conflict.winner.isDeleted {
                        Text("The cloud version is deleted.")
                    }
                    Button("Restore my saved edit") { coordinator.restoreConflict(id: conflict.id) }
                        .buttonStyle(.appSecondary)
                        .accessibilityIdentifier("sync.restoreConflict")
                    Button("Keep cloud version", role: .destructive) { coordinator.keepCloudVersion(id: conflict.id) }
                        .frame(minHeight: AppLayout.minimumTapTarget)
                        .accessibilityIdentifier("sync.keepCloud")
                }
                .padding(.vertical, AppSpacing.sm)
            }
        }
        .navigationTitle("Conflicting edits")
    }
}

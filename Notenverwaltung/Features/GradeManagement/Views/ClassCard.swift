import SwiftUI

struct ClassCard: View {
    let schoolClass: SchoolClass
    let studentCount: Int

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(schoolClass.name)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.primary)

                    Text(schoolClass.subject)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "book.closed.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.blue.gradient)
            }
            .padding(24)
            .background(Color.secondarySystemGroupedBackground)

            Divider()

            HStack(spacing: 24) {
                StatItem(icon: "person.2.fill", value: "\(studentCount)", label: "Schüler")

                Divider()
                    .frame(height: 30)

                StatItem(icon: "calendar", value: schoolClass.schoolYear, label: "Schuljahr")

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color.secondarySystemGroupedBackground.opacity(0.5))
        }
        .background(Color.secondarySystemGroupedBackground)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        .contentShape(Rectangle())
    }
}

struct StatItem: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .font(.system(size: 14))

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 15, weight: .semibold))
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

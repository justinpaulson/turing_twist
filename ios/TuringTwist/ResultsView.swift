import SwiftUI

struct ResultsView: View {
    let game: GameDetail
    @State private var expandedPlayerID: Int?

    private var entries: [LeaderboardEntry] { game.leaderboard ?? [] }
    private var humans: [LeaderboardEntry] { entries.filter { !$0.isAI } }
    private var ais: [LeaderboardEntry] { entries.filter(\.isAI) }

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 7) {
                Text("GAME OVER!").font(Newsprint.headline(38)).tracking(2)
                Rectangle().frame(height: 5)
                Text("THE MACHINES HAVE BEEN REVEALED")
                    .font(Newsprint.mono(11, weight: .bold))
                    .tracking(1.5)
            }
            .newsprintCard(padding: 20)

            VStack(alignment: .leading, spacing: 0) {
                Text("★ FINAL LEADERBOARD ★")
                    .font(Newsprint.mono(18, weight: .black))
                    .tracking(2)
                    .frame(maxWidth: .infinity)
                    .padding(18)
                    .foregroundStyle(Newsprint.paper)
                    .background(Newsprint.ink)

                VStack(spacing: 10) {
                    ForEach(Array(humans.enumerated()), id: \.element.id) { index, entry in
                        leaderboardRow(entry, rank: index + 1)
                    }

                    Text("AI REVEAL")
                        .font(Newsprint.mono(13, weight: .black))
                        .tracking(2)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 18)
                    Rectangle().frame(height: 3)

                    ForEach(ais) { entry in
                        leaderboardRow(entry, rank: nil)
                    }
                }
                .padding(14)
                .background(Newsprint.ink)

                VStack(alignment: .leading, spacing: 7) {
                    Text("► SCORING BREAKDOWN").font(Newsprint.mono(12, weight: .black))
                    Text("• Correct AI vote: +\(game.pointsPerCorrectGuess) points")
                    Text("• Vote received as a human: +1 point")
                }
                .font(Newsprint.mono(11))
                .padding(16)
                .foregroundStyle(Newsprint.paper)
                .background(Newsprint.ink)
            }
            .overlay(Rectangle().stroke(Newsprint.ink, lineWidth: 4))
        }
    }

    private func leaderboardRow(_ entry: LeaderboardEntry, rank: Int?) -> some View {
        let isWinner = rank == 1
        let isExpanded = expandedPlayerID == entry.id

        return VStack(spacing: 0) {
            Button {
                withAnimation(.snappy) {
                    expandedPlayerID = isExpanded ? nil : entry.id
                }
            } label: {
                ViewThatFits(in: .horizontal) {
                    wideRow(entry, rank: rank, isWinner: isWinner)
                    compactRow(entry, rank: rank, isWinner: isWinner)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        Text("► \(entry.characterName.uppercased())'S ANSWERS")
                            .font(Newsprint.mono(11, weight: .black))
                        Spacer()
                        Text("▲").font(Newsprint.mono(11, weight: .black))
                    }
                    Rectangle().frame(height: 2)
                    ForEach(entry.answers) { answer in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Q\(answer.roundNumber): \(answer.question)")
                                .font(Newsprint.mono(9, weight: .bold)).opacity(0.65)
                            Text(answer.content).font(Newsprint.mono(12))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .overlay(Rectangle().stroke(Newsprint.ink, lineWidth: 2))
                    }
                }
                .padding(12)
                .background(Newsprint.gray)
            }
        }
        .foregroundStyle(Newsprint.ink)
        .background(isWinner ? Newsprint.paper : (entry.isAI ? Newsprint.midGray : Newsprint.paper))
        .overlay(Rectangle().stroke(isWinner ? Newsprint.paper : Newsprint.midGray, lineWidth: 4))
    }

    private func wideRow(_ entry: LeaderboardEntry, rank: Int?, isWinner: Bool) -> some View {
        HStack(spacing: 14) {
            Text(rank.map(String.init) ?? "—")
                .font(Newsprint.mono(25, weight: .black))
                .frame(width: 38)
            CharacterAvatar(name: entry.characterAvatar, size: 58)
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.characterName.uppercased()).font(Newsprint.mono(15, weight: .black))
                Text(entry.isCurrentPlayer ? "■ YOU" : "■ \(entry.displayName.uppercased())")
                    .font(Newsprint.mono(9))
            }
            Spacer()
            stat("AIS", entry.isAI ? "—" : "\(entry.correctVotes)/2")
            stat("VOTES", "\(entry.votesReceived)")
            VStack(spacing: 2) {
                Text(entry.isAI ? "—" : "\(entry.score)")
                    .font(Newsprint.mono(25, weight: .black))
                Text("POINTS").font(Newsprint.mono(8, weight: .bold))
            }
            .foregroundStyle(Newsprint.paper)
            .frame(width: 76, height: 58)
            .background(Newsprint.ink)
            Text("▼").font(Newsprint.mono(11, weight: .bold))
        }
        .padding(12)
    }

    private func compactRow(_ entry: LeaderboardEntry, rank: Int?, isWinner: Bool) -> some View {
        HStack(spacing: 8) {
            Text(rank.map(String.init) ?? "—")
                .font(Newsprint.mono(18, weight: .black))
                .frame(width: 24)
            CharacterAvatar(name: entry.characterAvatar, size: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.characterName.uppercased())
                    .font(Newsprint.mono(10, weight: .black))
                    .lineLimit(2)
                Text(entry.isAI ? "AI PLAYER" : (entry.isCurrentPlayer ? "YOU" : entry.displayName.uppercased()))
                    .font(Newsprint.mono(7))
            }
            Spacer(minLength: 2)
            Text(entry.isAI ? "—" : "\(entry.correctVotes)/2")
                .font(Newsprint.mono(11, weight: .bold))
            Text("\(entry.votesReceived)")
                .font(Newsprint.mono(11, weight: .bold))
            Text(entry.isAI ? "—" : "\(entry.score)")
                .font(Newsprint.mono(16, weight: .black))
                .foregroundStyle(Newsprint.paper)
                .frame(width: 40, height: 38)
                .background(Newsprint.ink)
        }
        .padding(9)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(Newsprint.mono(18, weight: .black))
            Text(label).font(Newsprint.mono(8, weight: .bold))
        }
        .frame(width: 58)
    }
}

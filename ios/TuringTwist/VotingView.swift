import SwiftUI

struct VotingView: View {
    let game: GameDetail
    let voting: VotingSnapshot
    let isWorking: Bool
    let vote: (Int) async -> Bool
    let finishVoting: () async -> Bool

    @State private var selectedCandidate: VotingCandidate?
    @State private var showingFinishConfirmation = false

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 8) {
                Text("FINAL PHASE").font(Newsprint.mono(12, weight: .bold)).tracking(2)
                Text("WHO ARE THE AIS?").font(Newsprint.headline(29))
                Text("Review all five answers from each player. Choose exactly two suspects.")
                    .font(Newsprint.mono(13))
                    .multilineTextAlignment(.center)
            }
            .newsprintCard(padding: 20)

            voteStatus

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 310), spacing: 16)], spacing: 16) {
                ForEach(voting.candidates) { candidate in
                    candidateCard(candidate)
                }
            }

            totalProgress

            if game.isHost && canFinishEarly {
                Button("HOST: FINISH VOTING NOW") { showingFinishConfirmation = true }
                    .buttonStyle(PixelButtonStyle())
            }
        }
        .alert(item: $selectedCandidate) { candidate in
            Alert(
                title: Text("CONFIRM YOUR VOTE"),
                message: Text("Vote for \(candidate.characterName.uppercased()) as an AI? Votes cannot be changed."),
                primaryButton: .destructive(Text("YES, VOTE")) {
                    Task { _ = await vote(candidate.playerId) }
                },
                secondaryButton: .cancel()
            )
        }
        .alert("Finish voting now?", isPresented: $showingFinishConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Finish", role: .destructive) { Task { _ = await finishVoting() } }
        } message: {
            Text("Any remaining votes will be skipped and final scores will be calculated.")
        }
    }

    private var voteStatus: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("YOUR BALLOT").font(Newsprint.mono(11, weight: .bold))
                Text(voting.votesRemaining == 0 ? "COMPLETE" : "\(voting.votesRemaining) VOTE\(voting.votesRemaining == 1 ? "" : "S") LEFT")
                    .font(Newsprint.mono(18, weight: .black))
            }
            Spacer()
            Text(voting.votesRemaining == 0 ? "✓" : "\(2 - voting.votesRemaining)/2")
                .font(Newsprint.mono(30, weight: .black))
                .foregroundStyle(voting.votesRemaining == 0 ? Newsprint.paper : Newsprint.ink)
                .frame(width: 64, height: 64)
                .background(voting.votesRemaining == 0 ? Newsprint.ink : Newsprint.paper)
                .overlay(Rectangle().stroke(Newsprint.ink, lineWidth: 4))
        }
        .newsprintCard()
    }

    private func candidateCard(_ candidate: VotingCandidate) -> some View {
        let selected = candidate.hasVote
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                CharacterAvatar(name: candidate.characterAvatar, size: 58, inverted: !selected)
                VStack(alignment: .leading, spacing: 3) {
                    Text(candidate.characterName.uppercased())
                        .font(Newsprint.mono(15, weight: .black))
                    Text("\(candidate.answers.count) ANSWERS")
                        .font(Newsprint.mono(10))
                    if selected { Text("✓ VOTED").font(Newsprint.mono(11, weight: .black)) }
                    if candidate.isCurrentPlayer { Text("► YOU").font(Newsprint.mono(10, weight: .bold)) }
                }
                Spacer()
            }
            .padding(14)

            Rectangle().frame(height: selected ? 2 : 4)
                .foregroundStyle(selected ? Newsprint.paper : Newsprint.ink)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(candidate.answers) { answer in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Q\(answer.roundNumber): \(answer.question)")
                            .font(Newsprint.mono(9, weight: .bold))
                            .opacity(0.7)
                        Text(answer.content).font(Newsprint.mono(12))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .overlay(Rectangle().stroke(selected ? Newsprint.paper : Newsprint.ink, lineWidth: 2))
                }

                if !candidate.isCurrentPlayer && !candidate.hasVote && voting.votesRemaining > 0 {
                    Button("► VOTE AI") { selectedCandidate = candidate }
                        .buttonStyle(PixelButtonStyle(filled: !selected, compact: true))
                        .disabled(isWorking)
                }
            }
            .padding(14)
        }
        .foregroundStyle(selected ? Newsprint.paper : Newsprint.ink)
        .background(selected ? Newsprint.ink : Newsprint.paper)
        .overlay(Rectangle().stroke(Newsprint.ink, lineWidth: selected ? 6 : 4))
    }

    private var totalProgress: some View {
        VStack(spacing: 8) {
            Text("\(voting.votesCast) / \(voting.votesExpected) TOTAL VOTES CAST")
                .font(Newsprint.mono(15, weight: .black))
            Text("\(voting.playersFinished) / \(voting.humanPlayers) PLAYERS FINISHED")
                .font(Newsprint.mono(11))
        }
        .frame(maxWidth: .infinity)
        .newsprintCard(padding: 18)
    }

    private var canFinishEarly: Bool {
        guard let startedAt = voting.startedAt else { return false }
        return Date().timeIntervalSince(startedAt) >= 120 && voting.votesCast < voting.votesExpected
    }
}

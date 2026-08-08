import SwiftUI

struct RoundView: View {
    let game: GameDetail
    let round: RoundSnapshot
    let isWorking: Bool
    let submit: (String) async -> Bool
    let advance: () async -> Bool
    let skip: () async -> Bool

    @State private var answer = ""
    @State private var showingSkipConfirmation = false

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 8) {
                Text("ROUND \(round.number) OF \(game.totalRounds)")
                    .font(Newsprint.mono(12, weight: .bold))
                    .tracking(2)
                Text(round.status == .answering ? "ANSWER PHASE" : "REVIEW PHASE")
                    .font(Newsprint.headline(27))
            }
            .frame(maxWidth: .infinity)
            .newsprintCard()

            VStack(alignment: .leading, spacing: 12) {
                Text("TODAY'S QUESTION")
                    .font(Newsprint.mono(11, weight: .bold))
                    .tracking(2)
                Text(round.question)
                    .font(Newsprint.headline(25))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .newsprintCard(padding: 22)

            if round.status == .answering {
                answeringView
            } else {
                reviewingView
            }
        }
        .alert("Skip to reviewing?", isPresented: $showingSkipConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Skip Round", role: .destructive) { Task { _ = await skip() } }
        } message: {
            Text("Players who have not responded will receive a blank answer.")
        }
    }

    @ViewBuilder
    private var answeringView: some View {
        if let myAnswer = round.myAnswer {
            VStack(spacing: 15) {
                Text("✓ ANSWER SUBMITTED")
                    .font(Newsprint.mono(17, weight: .black))
                Text("“\(myAnswer)”")
                    .font(Newsprint.mono(15))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .overlay(Rectangle().stroke(Newsprint.ink, lineWidth: 2))
                answerProgress
                Text("WAITING FOR OTHER PLAYERS…")
                    .font(Newsprint.mono(12, weight: .bold))
            }
            .newsprintCard(padding: 22)
        } else {
            VStack(alignment: .leading, spacing: 13) {
                Text("YOUR ANSWER")
                    .font(Newsprint.mono(13, weight: .bold))
                TextEditor(text: $answer)
                    .font(Newsprint.mono(16))
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .frame(minHeight: 130)
                    .background(Newsprint.paper)
                    .overlay(Rectangle().stroke(Newsprint.ink, lineWidth: 4))
                    .accessibilityLabel("Your answer")
                Text("KEEP IT SHORT. BE SPECIFIC. SOUND HUMAN.")
                    .font(Newsprint.mono(10))
                Button(isWorking ? "SUBMITTING…" : "SUBMIT ANSWER") {
                    Task {
                        if await submit(answer.trimmingCharacters(in: .whitespacesAndNewlines)) {
                            answer = ""
                        }
                    }
                }
                .buttonStyle(PixelButtonStyle(filled: true))
                .disabled(answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isWorking)
                .opacity(answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isWorking ? 0.45 : 1)
            }
            .newsprintCard(padding: 18)
        }

        if game.isHost && round.answerCount < round.totalPlayers {
            VStack(spacing: 10) {
                Button("SKIP TO REVIEWING") { showingSkipConfirmation = true }
                    .buttonStyle(PixelButtonStyle())
                Text("HOST ONLY • FILLS MISSING RESPONSES WITH “NO RESPONSE”")
                    .font(Newsprint.mono(9))
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var answerProgress: some View {
        VStack(spacing: 6) {
            HStack {
                Text("RESPONSES")
                Spacer()
                Text("\(round.answerCount) / \(round.totalPlayers)")
            }
            .font(Newsprint.mono(12, weight: .bold))
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Newsprint.gray)
                    Rectangle()
                        .fill(Newsprint.ink)
                        .frame(width: proxy.size.width * progress)
                }
                .overlay(Rectangle().stroke(Newsprint.ink, lineWidth: 2))
            }
            .frame(height: 16)
        }
    }

    private var progress: CGFloat {
        guard round.totalPlayers > 0 else { return 0 }
        return CGFloat(round.answerCount) / CGFloat(round.totalPlayers)
    }

    private var reviewingView: some View {
        VStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 0) {
                BoxHeader(title: "► All Answers")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 270), spacing: 14)], spacing: 14) {
                    ForEach(round.answers) { answer in
                        answerCard(answer)
                    }
                }
                .padding(16)
            }
            .newsprintCard(padding: 0)

            Button(isWorking ? "CONTINUING…" : continueTitle) {
                Task { _ = await advance() }
            }
            .buttonStyle(PixelButtonStyle(filled: round.number == game.totalRounds))
            .disabled(isWorking)
        }
    }

    private var continueTitle: String {
        round.number == game.totalRounds ? "CONTINUE TO VOTING ►" : "CONTINUE TO NEXT QUESTION ►"
    }

    private func answerCard(_ answer: GameAnswer) -> some View {
        let player = game.players.first(where: { $0.id == answer.playerId })
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                CharacterAvatar(name: player?.characterAvatar, size: 44)
                Text((player?.characterName ?? "PLAYER").uppercased())
                    .font(Newsprint.mono(13, weight: .black))
                if player?.isCurrentPlayer == true {
                    Text("YOU").font(Newsprint.mono(9, weight: .bold)).padding(4).overlay(Rectangle().stroke(lineWidth: 1))
                }
            }
            Rectangle().frame(height: 2)
            Text(answer.content)
                .font(Newsprint.mono(14))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .newsprintCard(padding: 13, lineWidth: 3, background: player?.isCurrentPlayer == true ? Newsprint.gray : Newsprint.paper)
    }
}

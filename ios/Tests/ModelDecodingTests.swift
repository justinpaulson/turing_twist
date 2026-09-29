import Foundation

@main
struct ModelDecodingTests {
    static func main() throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let playerJSON = #"{"id":1,"character_name":"Wizard","is_current_player":false,"is_host":false,"is_ai":true}"#
        let player = try decoder.decode(Player.self, from: Data(playerJSON.utf8))
        precondition(player.isAI == true, "The reveal must identify AI players")
        let hidden = try decoder.decode(Player.self, from: Data(playerJSON.replacingOccurrences(of: "true", with: "null").utf8))
        precondition(hidden.isAI == nil, "Unrevealed identities must remain hidden")
        let entryJSON = #"{"player_id":1,"character_name":"Wizard","display_name":"AI PLAYER","is_current_player":false,"is_ai":true,"score":0,"correct_votes":0,"votes_received":2,"points_from_guesses":0,"points_from_deception":0,"answers":[]}"#
        let entry = try decoder.decode(LeaderboardEntry.self, from: Data(entryJSON.utf8))
        precondition(entry.isAI, "Final results must decode the server's is_ai field")
        let human = try decoder.decode(LeaderboardEntry.self, from: Data(entryJSON.replacingOccurrences(of: "true", with: "false").utf8))
        precondition(!human.isAI, "Human results must remain distinct from AI results")
        print("4 native model decoding checks passed")
    }
}

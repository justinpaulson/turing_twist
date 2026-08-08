class Api::V1::RoundsController < Api::V1::BaseController
  before_action :set_game_and_round
  before_action :set_current_player

  def answer
    unless @round.answering? && @current_player && !@current_player.is_eliminated?
      render_error("Cannot submit answer now.", :unprocessable_entity)
      return
    end

    answer = @current_player.answers.create!(
      round: @round,
      content: params.require(:content),
      submitted_at: Time.current
    )
    @round.update!(status: :reviewing) if @round.all_players_answered?

    render_game(@game.reload, status: :created, message: "Answer submitted.")
  end

  def advance
    unless @round.reviewing?
      render_error("Not ready to continue.", :unprocessable_entity)
      return
    end

    @round.update!(status: :completed, ended_at: Time.current)
    if @round.round_number >= Game::TOTAL_ROUNDS
      @game.update!(voting_started_at: Time.current) unless @game.voting_started_at
      message = "All questions answered! Time to vote!"
    else
      GameManager.new(@game).create_next_round!
      message = "Next question ready."
    end

    render_game(@game.reload, message: message)
  end

  def skip_to_reviewing
    unless @current_player&.is_host?
      render_error("Only the host can skip to reviewing.", :forbidden)
      return
    end
    unless @round.answering?
      render_error("Cannot skip this round.", :unprocessable_entity)
      return
    end

    answered_ids = @round.answers.pluck(:player_id)
    @game.active_human_players.where.not(id: answered_ids).find_each do |player|
      @round.answers.create!(player: player, content: "(no response)", submitted_at: Time.current)
    end
    @round.update!(status: :reviewing)

    render_game(@game.reload, message: "Skipped to reviewing phase.")
  end

  private

  def set_game_and_round
    @game = Game.find(params[:game_id])
    @round = @game.rounds.find_by!(round_number: params[:round_number])
  end

  def set_current_player
    @current_player = @game.players.find_by(user: current_user)
    render_error("You are not a player in this game.", :forbidden) unless @current_player
  end
end

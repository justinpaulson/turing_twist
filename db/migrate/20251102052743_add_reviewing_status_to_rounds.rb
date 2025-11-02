class AddReviewingStatusToRounds < ActiveRecord::Migration[8.0]
  def up
    # Update existing voting rounds to the new voting value (2)
    # and completed rounds to the new completed value (3)
    execute "UPDATE rounds SET status = 3 WHERE status = 2"
    execute "UPDATE rounds SET status = 2 WHERE status = 1"
    # status 1 is now 'reviewing', which doesn't exist yet, so no need to update
  end

  def down
    # Reverse the changes
    execute "UPDATE rounds SET status = 1 WHERE status = 2"
    execute "UPDATE rounds SET status = 2 WHERE status = 3"
  end
end

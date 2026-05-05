class BackfillAssignmentNotificationFields < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      UPDATE assignments
      SET assigned_to_id = memberships.user_id
      FROM memberships
      WHERE assignments.membership_id = memberships.id
        AND assignments.assigned_to_id IS NULL;
    SQL

    execute <<~SQL
      UPDATE assignments
      SET assigned_at = created_at
      WHERE assigned_at IS NULL;
    SQL
  end

  def down
    # no-op: keep backfilled values
  end
end

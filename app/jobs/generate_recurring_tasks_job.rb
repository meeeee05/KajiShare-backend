class GenerateRecurringTasksJob < ApplicationJob
  queue_as :default

  # target_dateを指定すると過去日/将来日の再生成確認にも使える
  def perform(target_date = nil)
    date = (target_date.present? ? Date.parse(target_date.to_s) : Time.zone.today)

    RecurringTask.where(active: true).find_each do |recurring_task|
      next unless due_on_date?(recurring_task, date)

      begin
        Task.create!(
          group_id: recurring_task.group_id,
          name: recurring_task.name,
          description: recurring_task.description,
          point: recurring_task.point,
          source_recurring_task_id: recurring_task.id,
          scheduled_for: date,
          auto_generated: true
        )
      rescue ActiveRecord::RecordNotUnique
        # 二重生成防止ユニーク制約に引っかかった場合はスキップ
        next
      end
    end
  end

  private

  def due_on_date?(recurring_task, date)
    return false if date < recurring_task.starts_on

    case recurring_task.schedule_type
    when "weekly"
      recurring_task.day_of_week == date.wday
    when "every_n_days"
      interval = recurring_task.interval_days.to_i
      return false if interval <= 0

      ((date - recurring_task.starts_on).to_i % interval).zero?
    else
      false
    end
  end
end

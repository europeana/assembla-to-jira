# frozen_string_literal: true

load './lib/common.rb'

SPACE_NAME = ENV['JIRA_API_PROJECT_NAME']

@jira_sprints = []

space = get_space(SPACE_NAME)
dirname = get_output_dirname(space, 'assembla')
assembla_milestones_csv = "#{dirname}/milestones.csv"
@milestones_assembla = csv_to_array(assembla_milestones_csv)

MILESTONE_PLANNER_TYPES = %w(none backlog current)

@milestones_assembla.each do |milestone|
  puts "#{milestone['id']} #{milestone['title']} (#{MILESTONE_PLANNER_TYPES[milestone['planner_type'].to_i]}) => #{milestone['is_completed'] ? '' : 'not'} completed"
end


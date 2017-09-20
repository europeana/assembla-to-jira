# frozen_string_literal: true

load './lib/common.rb'

@jira_statuses = jira_get_statuses

puts "\nJira statuses: #{@jira_statuses.length}"
@jira_statuses.each do |status|
  puts "* #{status['name']}"
end

JIRA_API_STATUSES = ENV['JIRA_API_STATUSES']

@assembla_statuses = []
JIRA_API_STATUSES.split(',').each do |status|
  from, to = status.split(':')
  to ||= from
  @assembla_statuses << to unless @assembla_statuses.include?(to)
end

puts "\nAssembla statuses: #{@assembla_statuses.length}"
@assembla_statuses.each do |status|
  puts "* #{status} => #{@jira_statuses.detect { |s| s['name'] == status} ? 'OK' : 'Missing'}"
end
puts

@assembla_statuses.each do |status|
  puts "Create status='#{status}'" unless @jira_statuses.detect { |s| s['name'] == status}
end


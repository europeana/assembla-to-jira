# frozen_string_literal: true

load './lib/common.rb'

SPACE_NAME = ENV['JIRA_API_PROJECT_NAME']
JIRA_PROJECT_NAME = SPACE_NAME + (@debug ? ' TEST' : '')

space = get_space(SPACE_NAME)
dirname_assembla = get_output_dirname(space, 'assembla')

# Jira tickets
tickets_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-tickets-all.csv"
@tickets_jira = csv_to_array(tickets_jira_csv)

# Convert assembla_ticket_id to jira_ticket
@assembla_id_to_jira = {}
@tickets_jira.each do |ticket|
  jira_id = ticket['jira_ticket_id']
  assembla_id = ticket['assembla_ticket_id']
  @assembla_id_to_jira[assembla_id] = jira_id
end

# Assembla tickets
associations_csv = "#{dirname_assembla}/ticket-associations.csv"
@associations_assembla = csv_to_array(associations_csv)

# --- Filter by date if TICKET_CREATED_ON is defined --- #
tickets_created_on = get_tickets_created_on

if tickets_created_on
  puts "Filter newer than: #{tickets_created_on}"
  @associations_assembla.select! { |association| @assembla_id_to_jira[association['ticket_id']]}
end
puts "Total Assembla associations: #{@associations_assembla.length}"

# Collect ticket statuses
@relationship_names = {}
@relationship_tickets = []
@associations_assembla.each do |association|
  ticket_id = association['ticket_id'].to_i
  name = association['relationship_name']
  if @relationship_names[name].nil?
    @relationship_names[name] = 0
  else
    @relationship_names[name] += 1
  end
  @relationship_tickets[ticket_id] = [] unless @relationship_tickets.include?(ticket_id)
  @relationship_tickets[ticket_id] << association
end

puts "Total relationships: #{@relationship_names.keys.length}"
@relationship_names.each do |name|
  puts "* #{name}: #{@relationship_names[name]}"
end

puts "Total tickets: #{@relationship_tickets.length}"

@jira_associations_tickets = []

@relationship_tickets.each_with_index do |ticket, index|
  puts "#{ticket['ticket_id']} => '#{ticket}'"
  # assembla_ticket_id = ticket['id']
  # assembla_ticket_status = ticket['status']
  # jira_ticket_id = @assembla_id_to_jira[ticket['id']]
  # result = jira_update_association(jira_ticket_id, assembla_ticket_status, index + 1)
  # @jira_associations_tickets << {
  #   result: result.nil? ? 'NOK' : 'OK',
  #   assembla_ticket_id: assembla_ticket_id,
  #   assembla_ticket_status: assembla_ticket_status,
  #   jira_ticket_id: jira_ticket_id,
  #   jira_transition_from_id: result.nil? ? 0 : result[:transition][:from][:id],
  #   jira_transition_from_name: result.nil? ? 0 : result[:transition][:from][:name],
  #   jira_transition_to_id: result.nil? ? 0 : result[:transition][:to][:id],
  #   jira_transition_to_name: result.nil? ? 0 : result[:transition][:to][:name]
  # }
end

puts "\nTotal updates: #{@jira_associations_tickets.length}"
associations_tickets_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-tickets-associations.csv"
write_csv_file(associations_tickets_jira_csv, @jira_associations_tickets)

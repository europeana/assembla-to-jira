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
@relationship_tickets = {}
@associations_assembla.each do |association|
  ticket_id = association['ticket_id'].to_i
  ticket1_id = association['ticket1_id'].to_i
  ticket2_id = association['ticket2_id'].to_i
  if ticket1_id != ticket_id && ticket2_id != ticket_id
    goodbye("ticket1_id (#{ticket1_id}) != ticket_id (#{ticket_id}) && ticket2_id (#{ticket2_id}) != ticket_id (#{ticket_id})")
  end
  name = association['relationship_name']
  if @relationship_names[name].nil?
    @relationship_names[name] = 0
  else
    @relationship_names[name] += 1
  end
  @relationship_tickets[ticket_id] = { associations: {} } if @relationship_tickets[ticket_id].nil?
  @relationship_tickets[ticket_id][:associations][name] = [] if @relationship_tickets[ticket_id][:associations][name].nil?
  @relationship_tickets[ticket_id][:associations][name] << {
    ticket: ticket1_id == ticket_id ? 2 : 1,
    ticket_id: ticket1_id == ticket_id ? ticket2_id : ticket1_id
  }
end

puts "Total relationship names: #{@relationship_names.keys.length}"
@relationship_names.each do |item|
  puts "* #{item[0]}: #{item[1]}"
end

puts "\nTotal tickets: #{@relationship_tickets.keys.length}"
@relationship_tickets.keys.sort.each do |ticket_id|
  names = []
  @relationship_tickets[ticket_id][:associations].keys.each do |name|
    items = []
    list = @relationship_tickets[ticket_id][:associations][name]
    list.each do |item|
      items << "#{item[:ticket]}:#{item[:ticket_id]}"
    end
    names << "#{name}:[#{items.join(',')}]"
  end
  puts "#{ticket_id}: #{names.join(',')}"
end

# 0 - Parent (ticket2 is parent of ticket1 and ticket1 is child of ticket2)
# 1 - Child  (ticket2 is child of ticket1 and ticket2 is parent of ticket1)
# 2 - Related (ticket2 is related to ticket1)
# 3 - Duplicate (ticket2 is duplication of ticket1)
# 4 - Sibling (ticket2 is sibling of ticket1)
# 5 - Story (ticket2 is story and ticket1 is subtask of the story)
# 6 - Subtask (ticket2 is subtask of a story and ticket1 is the story)
# 7 - Dependent (ticket2 depends on ticket1)
# 8 - Block (ticket2 blocks ticket1)
# 9 - Unknown

# @jira_associations_tickets = []
#
# @relationship_tickets.each_with_index do |ticket, index|
#   puts "#{ticket['ticket_id']} => '#{ticket}'"
#   assembla_ticket_id = ticket['id']
#   assembla_ticket_status = ticket['status']
#   jira_ticket_id = @assembla_id_to_jira[ticket['id']]
#   result = jira_update_association(jira_ticket_id, assembla_ticket_status, index + 1)
#   @jira_associations_tickets << {
#     result: result.nil? ? 'NOK' : 'OK',
#     assembla_ticket_id: assembla_ticket_id,
#     assembla_ticket_status: assembla_ticket_status,
#     jira_ticket_id: jira_ticket_id,
#     jira_transition_from_id: result.nil? ? 0 : result[:transition][:from][:id],
#     jira_transition_from_name: result.nil? ? 0 : result[:transition][:from][:name],
#     jira_transition_to_id: result.nil? ? 0 : result[:transition][:to][:id],
#     jira_transition_to_name: result.nil? ? 0 : result[:transition][:to][:name]
#   }
# end
#
# puts "\nTotal updates: #{@jira_associations_tickets.length}"
# associations_tickets_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-tickets-associations.csv"
# write_csv_file(associations_tickets_jira_csv, @jira_associations_tickets)

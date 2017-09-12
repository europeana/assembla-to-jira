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
  @associations_assembla.select! { |association| @assembla_id_to_jira[association['ticket_id']] }
end

@total_assembla_associations = @associations_assembla.length
puts "Total Assembla associations: #{@total_assembla_associations}"

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

def jira_update_association(name, ticket1_id, ticket2_id, counter)
  result = nil
  url = "#{URL_JIRA_ISSUES}/#{ticket1_id}/#{ticket2_id}/dummy"

  payload = {
    update: {
      issuelinks: [
        {
          add: {
            type: {
              name: name
            },
            inwardIssue: {
              id: ticket1_id
            },
            outwardIssue: {
              id: ticket2_id
            }
          }
        }
      ]
    }
  }.to_json
  begin
    percentage = ((counter * 100) / @total_assembla_associations).round.to_s.rjust(3)
    # RestClient::Request.execute(method: :post, url: url, payload: payload, headers: JIRA_HEADERS)
    puts "#{percentage}% [#{counter}|#{@total_assembla_tickets} PUT #{url} '#{name}' => OK"
    result = true
  rescue RestClient::ExceptionWithResponse => e
    rest_client_exception(e, 'PUT', url, payload)
  rescue => e
    puts "#{percentage}% [#{counter}|#{@total_assembla_tickets} PUT #{url} #{payload.inspect} => NOK (#{e.message})"
  end
  result
end

@jira_associations_tickets = []

@associations_assembla.each_with_index do |association, index|
  name = association['relationship_name']
  skip = name.match('unknown')
  assembla_ticket1_id = association['ticket1_id']
  assembla_ticket2_id = association['ticket2_id']
  jira_ticket1_id = @assembla_id_to_jira[assembla_ticket1_id]
  jira_ticket2_id = @assembla_id_to_jira[assembla_ticket2_id]
  unless skip
    results = jira_update_association(name, jira_ticket1_id, jira_ticket2_id, index + 1)
  end
  result = if skip
             'SKIP'
           elsif results
             'OK'
           else
             'NOK'
           end
  @jira_associations_tickets << {
    result: result,
    assembla_ticket1_id: assembla_ticket1_id,
    jira_ticket1_id: jira_ticket1_id,
    assembla_ticket2_id: assembla_ticket2_id,
    jira_ticket2_id: jira_ticket2_id,
    relationship_name: name
  }
end

puts "\nTotal updates: #{@jira_associations_tickets.length}"
associations_tickets_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-tickets-associations.csv"
write_csv_file(associations_tickets_jira_csv, @jira_associations_tickets)

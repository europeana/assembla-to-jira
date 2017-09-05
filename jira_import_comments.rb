# frozen_string_literal: true

load './lib/common.rb'

# TODO: For the time being this is hard-coded
SPACE_NAME = 'Europeana Collections'
JIRA_PROJECT_NAME = 'Europeana Collections' + (@debug ? ' TEST' : '')

space = get_space(SPACE_NAME)
dirname_assembla = get_output_dirname(space, 'assembla')

comments_assembla_csv = "#{dirname_assembla}/ticket-comments.csv"
comments_ok_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-comments-ok.csv"
comments_nok_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-comments-nok.csv"

tags_assembla_csv = "#{dirname_assembla}/ticket-tags.csv"
tags_ok_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-tags-ok.csv"
tags_nok_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-tags-nok.csv"

attachments_assembla_csv = "#{dirname_assembla}/ticket-attachments.csv"
attachments_ok_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-attachments-ok.csv"
attachments_nok_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-attachments-nok.csv"

@comments_assembla = csv_to_array(comments_assembla_csv)
@tags_assembla = csv_to_array(tags_assembla_csv)
@attachments_assembla = csv_to_array(attachments_assembla_csv)

tickets_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-tickets-all.csv"
@tickets_jira = csv_to_array(tickets_jira_csv)

@tickets = []

@tickets_jira.each do |ticket|
  @tickets << {
    jira: {
      id: ticket['jira_ticket_id'],
      key: ticket['jira_ticket_key']
    },
    assembla: {
      id: ticket['assembla_ticket_id'],
      number: ticket['assembla_ticket_number']
    },
    issue_type: {
      id: ticket['issue_type_id'],
      name: ticket['issue_type_name']
    }
  }
end

@assembla_to_jira = {}
@tickets.each_with_index do |ticket, index|
  jira = ticket[:jira]
  assembla = ticket[:assembla]
  issue_type = ticket[:issue_type]
  puts "#{index}: #{jira[:id]} (#{jira[:key]}), #{assembla[:id]} (#{assembla[:number]}), #{issue_type[:id]} (#{issue_type[:name]})"
  @assembla_to_jira[assembla[:id]] = jira[:id]
end

@comments_nok = []

@comments_assembla.each do |comment|
  assembla_ticket = comment['ticket_id']
  unless assembla_ticket.nil? || assembla_ticket.match(/^\d+$/)
    goodbye("Could not find valid assembla_ticket='#{assembla_ticket}' for comment=#{comment.inspect}")
  end
  jira_ticket = @assembla_to_jira[assembla_ticket]
  if jira_ticket.nil? || !jira_ticket.match(/^\d+$/)
    @comments_nok << comment
  else
    puts "#{assembla_ticket} => #{jira_ticket}"
  end
end

puts "Valid comments: #{@comments_assembla.length}"
puts "Invalid comments: #{@comments_assembla.length - @comments_nok.length}"

if @comments_nok.length.positive?
  write_csv_file(comments_nok_jira_csv, @comments_nok)
end

@tags_nok = []

@tags_assembla.each do |comment|
  assembla_ticket = comment['ticket_id']
  unless assembla_ticket.nil? || assembla_ticket.match(/^\d+$/)
    goodbye("Could not find valid assembla_ticket='#{assembla_ticket}' for comment=#{comment.inspect}")
  end
  jira_ticket = @assembla_to_jira[assembla_ticket]
  if jira_ticket.nil? || !jira_ticket.match(/^\d+$/)
    @tags_nok << comment
  else
    puts "#{assembla_ticket} => #{jira_ticket}"
  end
end

puts "Valid tags: #{@tags_assembla.length}"
puts "Invalid tags: #{@tags_assembla.length - @tags_nok.length}"

if @tags_nok.length.positive?
  write_csv_file(tags_nok_jira_csv, @tags_nok)
end

@attachments_nok = []

@attachments_assembla.each do |comment|
  assembla_ticket = comment['ticket_id']
  unless assembla_ticket.nil? || assembla_ticket.match(/^\d+$/)
    goodbye("Could not find valid assembla_ticket='#{assembla_ticket}' for comment=#{comment.inspect}")
  end
  jira_ticket = @assembla_to_jira[assembla_ticket]
  if jira_ticket.nil? || !jira_ticket.match(/^\d+$/)
    @attachments_nok << comment
  else
    puts "#{assembla_ticket} => #{jira_ticket}"
  end
end

puts "Valid attachments: #{@attachments_assembla.length}"
puts "Invalid attachments: #{@attachments_assembla.length - @attachments_nok.length}"

if @attachments_nok.length.positive?
  write_csv_file(attachments_nok_jira_csv, @attachments_nok)
end

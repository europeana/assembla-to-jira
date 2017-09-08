# frozen_string_literal: true

load './lib/common.rb'

# TODO: For the time being this is hard-coded
SPACE_NAME = 'Europeana Collections'
JIRA_PROJECT_NAME = 'Europeana Collections' + (@debug ? ' TEST' : '')

space = get_space(SPACE_NAME)
dirname_assembla = get_output_dirname(space, 'assembla')

# Assembla users
users_csv = "#{dirname_assembla}/report-users.csv"
users = csv_to_array(users_csv)
@user_id_to_login = {}
users.each do |user|
  @user_id_to_login[user['id']] = user['login']
end

# Assembla attachments
attachments_assembla_csv = "#{dirname_assembla}/ticket-attachments.csv"
@attachments_assembla = csv_to_array(attachments_assembla_csv)
total_attachments = @attachments_assembla.length

puts "Total attachments: #{total_attachments}"

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

# --- Filter by date if TICKET_CREATED_ON is defined --- #
tickets_created_on = get_tickets_created_on

if tickets_created_on
  puts "Filter newer than: #{tickets_created_on}"
  attachments_initial = @attachments_assembla.length
  # Only want attachments which belong to remaining tickets
  @attachments_assembla.select! { |item| @assembla_id_to_jira[item['ticket_id']] }
  puts "Attachments: #{attachments_initial} => #{@attachments_assembla.length} ∆#{attachments_initial - @attachments_assembla.length}"
end
puts "Tickets: #{@tickets_jira.length}"

@attachments_total = @attachments_assembla.length

# IMPORTANT: Make sure that the attachments are ordered chronologically from first (oldest) to last (newest)
@attachments_assembla.sort! { |x, y| x['created_at'] <=> y['created_at'] }

attachments_dirname = "#{OUTPUT_DIR_JIRA}/attachments"
FileUtils.mkdir_p(attachments_dirname) unless File.directory?(attachments_dirname)

@authorization = "Basic #{Base64.encode64(JIRA_API_ADMIN_USER + ':' + ENV['JIRA_API_ADMIN_PASSWORD'])}"

@attachments_assembla.each_with_index do |attachment, index|
  url = attachment['url']
  created_at = attachment['created_at']
  assembla_id = attachment['ticket_id']
  jira_id = @assembla_id_to_jira[assembla_id]
  filename = attachment['filename'].tr(' ', '_')
  content_type = attachment['content_type']
  counter = index + 1
  # # "http://api.assembla.com/v1/spaces/europeana-npc/documents/:id/download" should be:
  # # "http://api.assembla.com/spaces/europeana-npc/documents/:id/download/:id
  url.sub!(%r{v1/}, '')
  m = %r{documents/(.*)/download}.match(url)
  url += "/#{m[1]}"
  # url.sub!(/^http:\/\//,"http://#{ENV['ASSEMBLA_API_KEY']}:#{ENV['ASSEMBLA_API_SECRET']}@")
  percentage = ((counter * 100) / @attachments_total).round.to_s.rjust(3)
  puts "#{percentage}% [#{counter}|#{@attachments_total}] #{created_at} #{jira_id} #{assembla_id} '#{filename}' (#{content_type})"
  # headers = { 'Authorization': @authorization, 'Content-Type': content_type}
  begin
    content = RestClient::Request.execute(method: :get, url: url)
    filename = "#{attachments_dirname}/#{counter.to_s.rjust(4, '0')}-#{jira_id}-#{assembla_id}-#{filename}"
    IO.binwrite(filename, content)
  rescue RestClient::ExceptionWithResponse => e
    rest_client_exception(e, 'GET', url)
  end
end

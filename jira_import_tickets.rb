# frozen_string_literal: true

load './lib/common.rb'

SPACE_NAME = 'Europeana Collections'
JIRA_PROJECT_NAME = 'Europeana Collections' + (@debug ? ' | TEST' : '')

@jira_tickets = []
@fields_jira = []

CUSTOM_FIELD_NAMES = %w(Assembla-Id Assembla-Milestone Assembla-Theme Assembla-Status Assembla-Reporter Assembla-Assignee Epic\ Name Rank Story\ Points)
ISSUE_TYPE_NAMES = %w(unknown sub-task story epic task spike bug)

CONVERT_NAMES = [
  { name: 'kgish', convert: 'kiffin.gish' }
].freeze

UNKNOWN_USER = ENV['JIRA_API_UNKNOWN_USER']

MAX_RETRY = 3

# Assembla ticket fields:
# ----------------------
# id
# * number
# * summary
# * description
# * priority (1 - Highest, 2 - High, 3 - Medium, 4 - Low, 5 - Lowest)
# completed_date
# component_id
# * created_on
# permission_type
# * importance (Sorting criteria for Assembla Planner) => 10104 Rank
# is_story (true or false, if true hierarchy_type = 2)
# milestone_id => 10103 Sprint
# notification_list
# * space_id
# state (0 - closed, 1 - open)
# status (new, blocked, testable, in acceptance testing, in progress, ready for deploy)
# * story_importance (1 - small, 4 - medium, 7 - large) => 10105 Story Points
# updated_at
# working_hours
# estimate
# total_estimate
# total_invested_hours
# total_working_hours
# * assigned_to_id
# * reporter_id
# custom_fields
# hierarchy_type (0 - No plan level, 1 - Subtask, 2 - Story, 3 - Epic)
# # due_date

# Jira issue fields:
# -----------------
# * issuetype
# timespent
# * project
# fixVersions
# aggregatetimespent
# resolution
# resolutiondate
# workratio
# lastViewed
# watches
# thumbnail
# * created
# * priority
# * labels
# timeestimate
# aggregatetimeoriginalestimate
# versions
# issuelinks
# * assignee
# * updated
# status
# components
# issuekey
# timeoriginalestimate
# * description
# timetracking
# security
# attachment
# aggregatetimeestimate
# * summary
# * creator
# subtasks
# * reporter
# aggregateprogress
# environment
# duedate
# progress
# comment
# votes
# worklog

# Jira custom fields:
# ------------------
# 10000 Development
# 10001 Team
# 10002 Organizations
# 10003 Epic Name
# 10004 Epic Status
# 10005 Epic Color
# 10006 Epic Link
# 10007 Parent Link
# 10100 [CHART] Date of First Response
# 10101 [CHART] Time in Status
# 10102 Approvals
# * 10103 Sprint
# * 10104 Rank
# * 10105 Story Points
# 10108 Test sessions
# 10109 Raised during
# 10200 Testing status
# 10300 Capture for JIRA user agent
# 10301 Capture for JIRA browser
# 10302 Capture for JIRA operating system
# 10303 Capture for JIRA URL
# 10304 Capture for JIRA screen resolution
# 10305 Capture for JIRA jQuery version
# 10400 Assembla

# Names (reporter and/or assignee) that need to be converted
def convert_name(name)
  found = CONVERT_NAMES.find{ |n| n[:name] == name}
  return found ? found[:convert] : name
end

def jira_get_field_by_name(name)
  @fields_jira.find{ |field| field['name'] == name }
end

def get_labels(ticket)
  labels = ['assembla']
  @tags_assembla.each do |tag|
    if tag['ticket_id'] == ticket['number']
      labels << tag['name'].tr(' ', '-')
    end
  end
  labels
end

def get_milestone(ticket)
  id = ticket['milestone_id']
  if id && id.length > 0
    name = @milestone_id_to_name[id] || id
  else
    name = 'unknown milestone'
  end
  { id: id, name: name }
end

def get_issue_type(ticket)
  case ticket['hierarchy_type'].to_i
  when 1
    id = @issue_type_name_to_id['sub-task']
    name = 'sub-task'
  when 2
    id = @issue_type_name_to_id['story']
    name = 'story'
  when 3
    id = @issue_type_name_to_id['epic']
    name = 'epic'
  else
    id = @issue_type_name_to_id['task']
    name = 'task'
  end

  # Ticket type is overruled if summary begins with the type (EPIC, SPIKE, STORY or BUG)
  %w(epic spike story bug).each do |s|
    if ticket['summary'] =~ /^#{s}/i
      id = @issue_type_name_to_id[s]
      name = s
      break
    end
  end
  { id: id, name: name }
end


def create_ticket_jira(ticket, counter, total, grand_counter, grand_total)

  project_id = @project['id']
  ticket_id = ticket['number']

  # Prepend the description text with a link to the original assembla ticket on the first line.
  description = "[Assembla ticket ##{ticket_id}|#{ENV['ASSEMBLA_URL_TICKETS']}/#{ticket_id}]\r\n\r\n#{ticket['description']}"

  story_rank = ticket['importance']
  story_points = ticket['story_importance']

  summary = ticket['summary']
  reporter_name = convert_name(@user_id_to_login[ticket['reporter_id']])
  assignee_name = convert_name(@user_id_to_login[ticket['assigned_to_id']])
  priority_name = @priority_id_to_name[ticket['priority']]

  status_name = ticket['status']

  labels = get_labels(ticket)

  custom_fields = JSON.parse(ticket['custom_fields'].gsub('=>',':'))
  theme_name = custom_fields['Theme']

  milestone = get_milestone(ticket)

  issue_type = get_issue_type(ticket)

  payload = {
    'create': {},
    'fields': {
      'project': { 'id': project_id },
      'summary': summary,
      'issuetype': { 'id': issue_type[:id] },
      'assignee': { 'name': assignee_name },
      'reporter': { 'name': reporter_name },
      'priority': { 'name': priority_name },
      'labels': labels,
      'description': description,

      # IMPORTANT: The following custom fields MUST be on the create issue screen for this project
      #  Admin > Issues > Screens > Configure screen > 'ECT: Scrum Default Issue Screen'
      # Assembla

      "#{@customfield_name_to_id['Assembla-Id']}": ticket_id,
      "#{@customfield_name_to_id['Assembla-Theme']}": theme_name,
      "#{@customfield_name_to_id['Assembla-Status']}": status_name,
      "#{@customfield_name_to_id['Assembla-Milestone']}": milestone[:name],
      "#{@customfield_name_to_id['Rank']}": story_rank,

      # TODO: "customfield_10105"=>"Field 'customfield_10105' cannot be set. It is not on the appropriate screen, or unknown."
      #"#{@customfield_name_to_id['Story Points']}": story_points
    }
  }

  if issue_type[:name] == 'epic'
    epic_name = (summary =~ /^epic: /i ? summary[6..-1] : summary)
    payload[:fields]["#{@customfield_name_to_id['Epic Name']}".to_sym] = epic_name
  end

  jira_ticket_id = nil
  jira_ticket_key = nil
  message = nil
  ok = false
  retries = 0
  begin
    response = RestClient::Request.execute(method: :post, url: URL_JIRA_ISSUES, payload: payload.to_json, headers: JIRA_HEADERS)
    body = JSON.parse(response.body)
    jira_ticket_id = body['id']
    jira_ticket_key = body['key']
    message = "id='#{jira_ticket_id}' key='#{jira_ticket_key}'"
    ok = true
  rescue RestClient::ExceptionWithResponse => e
    error = JSON.parse(e.response)
    message = error['errors'].map { |k,v| "#{k}: #{v}"}.join(' | ')
    retries += 1
    recover = false
    if retries < MAX_RETRY
      error['errors'].each do |err|
        key = err[0]
        reason = err[1]
        case key
        when 'assignee'
          case reason
          when /cannot be assigned issues/i
            payload[:fields]["#{@customfield_name_to_id['Assembla-Assignee']}".to_sym] = payload[:fields][:assignee][:name]
            payload[:fields][:assignee][:name] = ''
            recover = true
          end
        when 'reporter'
          case reason
          when /is not a user/i
            payload[:fields]["#{@customfield_name_to_id['Assembla-Reporter']}".to_sym] = payload[:fields][:reporter][:name]
            payload[:fields][:reporter][:name] = UNKNOWN_USER
            recover = true
          when /reporter is required/i
            payload[:fields][:reporter][:name] = UNKNOWN_USER
            recover = true
          end
        end
      end
    end
    retry if retries < MAX_RETRY && recover
  rescue => e
    message = e.message
  end

  dump_payload = ok ? '' : ' ' + payload.inspect.sub(/:description=>"[^"]+",/,':description=>"...",')
  puts "[#{counter}|#{total}|#{grand_counter}|#{grand_total} #{issue_type[:name].upcase}] POST #{URL_JIRA_ISSUES} #{ticket_id}#{dump_payload} => #{ok ? '' : 'N'}OK (#{message}) retries = #{retries}"[:name]

  @jira_tickets << {
      result: (ok ? 'OK' : 'NOK'),
      retries: retries,
      message: message.gsub(' | ', "\r\n\r\n"),
      jira_ticket_id: jira_ticket_id,
      jira_ticket_key: jira_ticket_key,
      project_id: project_id,
      summary: summary,
      issue_type_id: issue_type[:id],
      issue_type_name: issue_type[:name],
      assignee_name: assignee_name,
      reporter_name: reporter_name,
      priority_name: priority_name,
      status_name: status_name,
      labels: labels.join('|'),
      description: description,
      assembla_ticket_id: ticket_id,
      theme_name: theme_name,
      milestone_name: milestone[:name],
      story_rank: story_rank,
      story_points: story_points
  }
end

# Ensure that the project exists, otherwise ask the user to create it first.
@project = get_project_by_name(JIRA_PROJECT_NAME)

if @project
  puts "Found project '#{JIRA_PROJECT_NAME}' id='#{@project['id']}' key='#{@project['key']}'"
else
  goodbye("You must first create a Jira project called '#{JIRA_PROJECT_NAME}' in order to continue")
end

space = get_space(SPACE_NAME)
dirname_assembla = get_output_dirname(space, 'assembla')

tickets_assembla_csv = "#{dirname_assembla}/tickets.csv"
users_assembla_csv = "#{dirname_assembla}/users.csv"
milestones_assembla_csv = "#{dirname_assembla}/milestones.csv"
comments_assembla_csv = "#{dirname_assembla}/ticket-comments.csv"
tags_assembla_csv = "#{dirname_assembla}/ticket-tags.csv"
tickets_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-tickets.csv"
issue_types_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-issue-types.csv"

@tickets_assembla = csv_to_array(tickets_assembla_csv)
@users_assembla = csv_to_array(users_assembla_csv)
@milestones_assembla = csv_to_array(milestones_assembla_csv)
@comments_assembla = csv_to_array(comments_assembla_csv)
@tags_assembla = csv_to_array(tags_assembla_csv)
@issue_types_jira = csv_to_array(issue_types_jira_csv)

# --- USERS --- #

puts "\nUsers:"

@user_id_to_login = {}
@users_assembla.each do |user|
  @user_id_to_login[user['id']] = user['login'].sub(/@.*$/,'')
end

@user_id_to_login.each do |k,v|
  puts "#{k} #{v}"
end

# Make sure that the unknown user exists and is active
puts "\nUnknown user:"
if UNKNOWN_USER && UNKNOWN_USER.length
  user = jira_get_user(UNKNOWN_USER)
  if user
    goodbye("Please activate Jira unknown user '#{UNKNOWN_USER}'") unless user['active']
  else
    goodbye("Cannot find Jira unknown user '#{UNKNOWN_USER}', make sure that has been created and enabled")
  end
else
  goodbye("Please define 'JIRA_API_UNKNOWN_USER' in the .env file")
end

# --- MILESTONES --- #

puts "\nMilestones:"

@milestone_id_to_name = {}
@milestones_assembla.each do |milestone|
  @milestone_id_to_name[milestone['id']] = milestone['title']
end

@milestone_id_to_name.each do |k,v|
  puts "#{k} #{v}"
end

# --- ISSUE TYPES --- #

puts "\nIssue types:"

@issue_type_name_to_id = {}
@issue_types_jira.each do |type|
  @issue_type_name_to_id[type['name'].downcase] = type['id']
end

@issue_type_name_to_id.each do |k,v|
  puts "#{v} #{k}"
end

# --- PRIORITIES --- #

puts "\nPriorities:"

@priority_id_to_name = {}
@priorities_jira = jira_get_priorities
if @priorities_jira
  @priorities_jira.each do |priority|
    @priority_id_to_name[priority['id']] = priority['name']
  end
else
  goodbye("Cannot get priorities!")
end

@priority_id_to_name.each do |k,v|
  puts "#{k} #{v}"
end

# --- JIRA fields --- #

puts "\nJira fields:"

@fields_jira = jira_get_fields
if @fields_jira
  @fields_jira.sort_by{|k| k['id']}.each do |field|
    puts "#{field['id']} '#{field['name']}' #{field['custom']}"
  end
else
  goodbye('Cannot get fields!')
end

# --- JIRA custome fields --- #

puts "\nJira custom fields:"

@customfield_name_to_id = {}

CUSTOM_FIELD_NAMES.each do |name|
  field = jira_get_field_by_name(name)
  if field
    id = field['id']
    @customfield_name_to_id[name] = id
    puts "'#{name}'='#{id}'"
  else
    goodbye("Custom field '#{name}' is missing, please define in Jira")
  end
end

grand_total = @tickets_assembla.length
puts "Total tickets: #{grand_total}"
[true, false].each do |sanity_check|
  duplicate_tickets = []
  imported_tickets = []
  grand_counter = 0
  %w(epic story task sub-task).each do |issue_type|
    @tickets = @tickets_assembla.select{|ticket| get_issue_type(ticket)[:name] == issue_type}
    total = @tickets.length
    puts "Total #{issue_type}: #{total}" unless sanity_check
    @tickets.each_with_index do |ticket, index|
      ticket_id = ticket['number']
      if imported_tickets.include?(ticket_id)
        if sanity_check
          duplicate_tickets << ticket_id
        else
          puts "SKIP create_ticket_jira(#{ticket_id}, #{index+1}, #{total}, #{grand_counter}, #{grand_total})"
        end
      else
        imported_tickets << ticket_id
        grand_counter += 1
        unless sanity_check
          puts "create_ticket_jira(#{ticket_id}, #{index+1}, #{total}, #{grand_counter}, #{grand_total})"
          # create_ticket_jira(ticket, index+1, total, grand_counter, grand_total)
        end
      end
    end
  end
  if sanity_check
    if duplicate_tickets.length.positive?
    goodbye("Duplicated ticket_ids=[#{duplicate_tickets.join(',')}]")
    else
      puts 'Sanity check => OK'
    end
  end
end

exit

write_csv_file(tickets_jira_csv, @jira_tickets)